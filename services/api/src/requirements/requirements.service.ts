import { BadRequestException, ForbiddenException, Injectable } from '@nestjs/common';
import { NotificationsService } from '../notifications/notifications.service';
import { PrismaService } from '../prisma/prisma.service';
import { PostRequirementDto } from './dto/post-requirement.dto';

@Injectable()
export class RequirementsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly notifications: NotificationsService,
  ) {}

  // docx 4.3 — "Send Request" CTA
  async postRequirement(customerId: string, dto: PostRequirementDto) {
    const requirement = await this.prisma.requirement.create({
      data: {
        customerId,
        subServiceId: dto.subServiceId,
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
  // contact details are never sent.
  async listForProvider(providerId: string) {
    const [requirements, provider] = await Promise.all([
      this.prisma.requirement.findMany({
        where: { targetedProviders: { some: { providerId } } },
        include: {
          subService: true,
          bids: { where: { providerId } },
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

    return requirements.map(({ customer, ...r }) => ({
      ...r,
      customerName: customer.fullName,
      customerPlace: customer.city,
      distanceKm: from ? distanceKm(from, customer) : null,
    }));
  }

  // docx 5.3 Accept / Reject
  async respond(requirementId: string, providerId: string, accept: boolean) {
    const link = await this.prisma.requirementProvider.findUnique({
      where: { requirementId_providerId: { requirementId, providerId } },
    });
    if (!link) throw new BadRequestException('this request was not sent to this provider');

    await this.prisma.requirementProvider.update({
      where: { requirementId_providerId: { requirementId, providerId } },
      data: { status: accept ? 'ACCEPTED' : 'REJECTED' },
    });

    if (accept) {
      await this.prisma.requirement.update({ where: { id: requirementId }, data: { status: 'ACCEPTED' } });
      await this.notifications.requestAccepted(requirementId, providerId);
    }
    return { requirementId, providerId, status: accept ? 'ACCEPTED' : 'REJECTED' };
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

interface Coordinates {
  latitude: number | null;
  longitude: number | null;
}

// Straight-line (haversine) distance in km, to one decimal; null when either
// point is missing a coordinate.
export function distanceKm(a: Coordinates, b: Coordinates): number | null {
  if (a.latitude == null || a.longitude == null || b.latitude == null || b.longitude == null) {
    return null;
  }
  const rad = (deg: number) => (deg * Math.PI) / 180;
  const dLat = rad(b.latitude - a.latitude);
  const dLon = rad(b.longitude - a.longitude);
  const h =
    Math.sin(dLat / 2) ** 2 + Math.cos(rad(a.latitude)) * Math.cos(rad(b.latitude)) * Math.sin(dLon / 2) ** 2;
  const km = 2 * 6371 * Math.asin(Math.sqrt(h));
  return Math.round(km * 10) / 10;
}
