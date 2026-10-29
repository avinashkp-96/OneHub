import { BadRequestException, ConflictException, ForbiddenException, Injectable } from '@nestjs/common';
import { NotificationsService } from '../notifications/notifications.service';
import { PrismaService } from '../prisma/prisma.service';
import { SubmitRatingDto } from './dto/submit-rating.dto';

// docx 5.8 thresholds are marked "to be finalized" in the requirements doc (section 9,
// Open Items). These are placeholders — replace once the business settles on real numbers.
const CERTIFICATION_MIN_SERVICES = 10;
const CERTIFICATION_MIN_RATING = 4.5;

@Injectable()
export class RatingsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly notifications: NotificationsService,
  ) {}

  // docx 4.6 "Submit Rating" -> updates the provider's average (docx 5.9) and
  // re-checks certification (docx 5.8).
  async submitRating(customerId: string, dto: SubmitRatingDto) {
    // Only the customer who posted a finished job may rate the provider who
    // did it, and only once.
    const requirement = await this.prisma.requirement.findUnique({
      where: { id: dto.requirementId },
      select: { customerId: true, status: true, confirmedBidId: true },
    });
    if (!requirement || requirement.customerId !== customerId) {
      throw new ForbiddenException('this is not your request');
    }
    if (requirement.status !== 'COMPLETED' || !requirement.confirmedBidId) {
      throw new BadRequestException('only a completed job can be rated');
    }
    const bid = await this.prisma.bid.findUniqueOrThrow({ where: { id: requirement.confirmedBidId } });
    if (bid.providerId !== dto.providerId) {
      throw new BadRequestException('that provider did not do this job');
    }
    if (await this.prisma.ratingFeedback.findUnique({ where: { requirementId: dto.requirementId } })) {
      throw new ConflictException('this job has already been rated');
    }

    const rating = await this.prisma.ratingFeedback.create({
      data: {
        customerId,
        providerId: dto.providerId,
        requirementId: dto.requirementId,
        stars: dto.stars,
        feedback: dto.feedback,
      },
    });

    const provider = await this.prisma.provider.findUniqueOrThrow({ where: { id: dto.providerId } });
    const newCount = provider.ratingCount + 1;
    const newAverage = (provider.averageRating * provider.ratingCount + dto.stars) / newCount;
    const completedCount = await this.prisma.requirement.count({
      where: { confirmedBidId: { not: null }, status: 'COMPLETED', subService: { providers: { some: { providerId: dto.providerId } } } },
    });

    const certified = completedCount >= CERTIFICATION_MIN_SERVICES && newAverage >= CERTIFICATION_MIN_RATING;
    await this.prisma.provider.update({
      where: { id: dto.providerId },
      data: { averageRating: newAverage, ratingCount: newCount, certified },
    });
    await this.notifications.ratingReceived(dto.providerId, dto.stars, certified && !provider.certified);

    return rating;
  }

  // docx 5.9 "Ratings Received", for the signed-in provider: average, count,
  // the 5★-1★ distribution and each review. Worked out from the ratings
  // themselves so the three always agree. Reviewers appear by first name and
  // last initial only.
  async mine(userId: string) {
    const provider = await this.prisma.provider.findUniqueOrThrow({ where: { userId }, select: { id: true } });
    const rows = await this.prisma.ratingFeedback.findMany({
      where: { providerId: provider.id },
      orderBy: { createdAt: 'desc' },
      select: { id: true, stars: true, feedback: true, createdAt: true, customer: { select: { fullName: true } } },
    });

    const distribution: Record<1 | 2 | 3 | 4 | 5, number> = { 5: 0, 4: 0, 3: 0, 2: 0, 1: 0 };
    let total = 0;
    for (const r of rows) {
      distribution[r.stars as 1 | 2 | 3 | 4 | 5] += 1;
      total += r.stars;
    }

    return {
      averageRating: rows.length ? Math.round((total / rows.length) * 10) / 10 : 0,
      ratingCount: rows.length,
      distribution,
      reviews: rows.map((r) => ({
        id: r.id,
        stars: r.stars,
        feedback: r.feedback,
        createdAt: r.createdAt,
        customerName: shortName(r.customer.fullName),
      })),
    };
  }

  overview(providerId: string) {
    return this.prisma.ratingFeedback.findMany({ where: { providerId }, orderBy: { createdAt: 'desc' } });
  }

  // Lets the client check before showing a rating prompt, since `requirementId`
  // is unique on RatingFeedback — a second submit for the same job would
  // otherwise fail with a raw database constraint error.
  forRequirement(requirementId: string) {
    return this.prisma.ratingFeedback.findUnique({ where: { requirementId } });
  }
}

// "Meera Nair" -> "Meera N.", "Meera" -> "Meera".
export function shortName(fullName: string) {
  const [first, ...rest] = fullName.trim().split(/\s+/);
  const last = rest.at(-1);
  return last ? `${first} ${last[0].toUpperCase()}.` : first;
}
