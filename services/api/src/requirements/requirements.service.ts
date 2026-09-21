import { BadRequestException, Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { PostRequirementDto } from './dto/post-requirement.dto';

@Injectable()
export class RequirementsService {
  constructor(private readonly prisma: PrismaService) {}

  // docx 4.3 — "Send Request" CTA
  postRequirement(customerId: string, dto: PostRequirementDto) {
    return this.prisma.requirement.create({
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
  }

  // docx 4.4 "My Requests — Status View"
  listForCustomer(customerId: string) {
    return this.prisma.requirement.findMany({
      where: { customerId },
      include: { targetedProviders: true, bids: true },
      orderBy: { createdAt: 'desc' },
    });
  }

  // docx 5.3 "Incoming Requests"
  listForProvider(providerId: string) {
    return this.prisma.requirement.findMany({
      where: { targetedProviders: { some: { providerId } } },
      include: { subService: true },
      orderBy: { createdAt: 'desc' },
    });
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
    }
    return { requirementId, providerId, status: accept ? 'ACCEPTED' : 'REJECTED' };
  }

  // docx 5.6 "Mark as Completed" — triggers the customer's rating prompt (docx 4.6).
  markCompleted(requirementId: string) {
    return this.prisma.requirement.update({ where: { id: requirementId }, data: { status: 'COMPLETED' } });
  }
}
