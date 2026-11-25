import { BadRequestException, ForbiddenException, Injectable } from '@nestjs/common';
import { distanceKm } from '../locations/geo';
import { NotificationsService } from '../notifications/notifications.service';
import { PrismaService } from '../prisma/prisma.service';
import { PostRequirementDto } from './dto/post-requirement.dto';
import { expireStale } from './expiry';
import { ADDRESS_FIELDS_SELECT, AddressFields } from '../users/addresses';

@Injectable()
export class RequirementsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly notifications: NotificationsService,
  ) {}

  // docx 4.3 — "Send Request" CTA. The request keeps a copy of the chosen
  // saved address, which must be the customer's own.
  async postRequirement(customerId: string, dto: PostRequirementDto) {
    const address = await this.prisma.address.findFirst({
      where: { id: dto.addressId, userId: customerId },
      select: ADDRESS_FIELDS_SELECT,
    });
    if (!address) throw new BadRequestException('choose one of your saved addresses');
    const requirement = await this.prisma.requirement.create({
      data: {
        customerId,
        address,
        subServiceId: dto.subServiceId,
        title: dto.title.trim(),
        description: dto.description,
        voiceTranscript: dto.voiceTranscript,
        photoUrls: dto.photoUrls ?? [],
        preferredAt: dto.preferredAt ? new Date(dto.preferredAt) : undefined,
        status: 'SENT',
        targetedProviders: {
          create: dto.providerIds.map((providerId) => ({ providerId })),
        },
      },
      include: { targetedProviders: true },
    });
    await this.notifications.requestSent(requirement.id);
    return requirement;
  }

  // docx 4.4 "My Requests — Status View"
  // Each targeted provider also carries `providerName` (business name, else
  // the person's name) so the customer can see who has accepted, rejected or
  // not answered yet (docx 4.4 per-provider status). RequirementProvider has
  // no relation to Provider in the schema, so the names come from one extra
  // lookup for all providers on all the customer's requests.
  async listForCustomer(customerId: string) {
    await expireStale(this.prisma, { customerId });
    const requirements = await this.prisma.requirement.findMany({
      where: { customerId },
      include: { targetedProviders: true, bids: true },
      orderBy: { createdAt: 'desc' },
    });

    const providerIds = [...new Set(requirements.flatMap((r) => r.targetedProviders.map((t) => t.providerId)))];
    const providers = providerIds.length
      ? await this.prisma.provider.findMany({
          where: { id: { in: providerIds } },
          select: { id: true, businessName: true, user: { select: { fullName: true } } },
        })
      : [];
    const names = new Map(providers.map((p) => [p.id, p.businessName ?? p.user.fullName]));

    return requirements.map((r) => ({
      ...r,
      targetedProviders: r.targetedProviders.map((t) => ({
        ...t,
        providerName: names.get(t.providerId) ?? 'Provider',
      })),
    }));
  }

  // docx 5.3 "Incoming Requests" and 5.6 "Awaiting Selection / Selected /
  // Not Selected" — `bids` is filtered to this provider's own bid (if any)
  // so the client can tell "my bid was confirmed" apart from "a different
  // provider on this multi-provider request was confirmed" without the
  // requirement's single global `status` field being ambiguous between them.
  //
  // Each request also carries what the provider needs to decide on it:
  // `customerName`, `customerPlace` (the customer's city; requests have no
  // address of their own) and `distanceKm` from the provider's saved location,
  // null when either side has no coordinates. The customer's coordinates and
  // contact details are never sent. The job address (a copy of the
  // customer's saved one) sets the place and distance when there is one, and
  // is sent in full only to the provider the customer confirmed.
  // `myResponse` is this provider's own
  // answer (SENT until they accept or reject), since the requirement's
  // `status` can reflect another provider on a multi-provider request.
  async listForProvider(providerId: string) {
    await expireStale(this.prisma, { targetedProviders: { some: { providerId } } });
    const [requirements, provider] = await Promise.all([
      this.prisma.requirement.findMany({
        where: { targetedProviders: { some: { providerId } } },
        include: {
          subService: true,
          bids: { where: { providerId } },
          targetedProviders: { where: { providerId }, select: { status: true } },
          customer: { select: { fullName: true, city: true, latitude: true, longitude: true } },
        },
        orderBy: { createdAt: 'desc' },
      }),
      this.prisma.provider.findUnique({
        where: { id: providerId },
        select: { user: { select: { latitude: true, longitude: true } } },
      }),
    ]);
    const from = provider?.user;

    return requirements.map(({ customer, targetedProviders, address, ...r }) => {
      const job = jobAddress(address);
      const chosen = !!r.confirmedBidId && r.bids.some((b) => b.confirmed && b.id === r.confirmedBidId);
      return {
        ...r,
        myResponse: targetedProviders[0]?.status ?? 'SENT',
        customerName: customer.fullName,
        customerPlace: job?.city ?? customer.city,
        distanceKm: from ? distanceKm(from, job ?? customer) : null,
        address: chosen ? job : null,
      };
    });
  }

  // docx 5.3 Reject. There is no separate accept: a provider accepts by
  // sending a price (BidsService.submitInitialBid). Rejecting only records
  // this provider's answer; the request stays open for the others.
  async reject(requirementId: string, providerId: string) {
    const link = await this.prisma.requirementProvider.findUnique({
      where: { requirementId_providerId: { requirementId, providerId } },
    });
    if (!link) throw new BadRequestException('this request was not sent to this provider');

    await this.prisma.requirementProvider.update({
      where: { requirementId_providerId: { requirementId, providerId } },
      data: { status: 'REJECTED' },
    });
    return { requirementId, providerId, status: 'REJECTED' };
  }

  // docx 5.6 "Mark as Completed" — triggers the customer's rating prompt (docx 4.6).
  // Only the provider whose bid was confirmed may complete it, and only once.
  async markCompleted(requirementId: string, providerId: string) {
    const requirement = await this.prisma.requirement.findUniqueOrThrow({
      where: { id: requirementId },
      select: { status: true, confirmedBidId: true },
    });
    if (!requirement.confirmedBidId) {
      throw new BadRequestException('no provider has been confirmed for this request');
    }
    const bid = await this.prisma.bid.findUniqueOrThrow({ where: { id: requirement.confirmedBidId } });
    if (bid.providerId !== providerId) {
      throw new ForbiddenException('this job was not given to you');
    }
    if (requirement.status !== 'CONFIRMED') {
      throw new BadRequestException('this job is not awaiting completion');
    }
    const completed = await this.prisma.requirement.update({
      where: { id: requirementId },
      data: { status: 'COMPLETED' },
    });
    await this.notifications.jobCompleted(requirementId);
    return completed;
  }
}

// The stored job address, when the request has one with a map position.
function jobAddress(value: unknown): AddressFields | null {
  if (!value || typeof value !== 'object') return null;
  const a = value as AddressFields;
  return typeof a.latitude === 'number' && typeof a.longitude === 'number' ? a : null;
}
