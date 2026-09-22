import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { SubmitRatingDto } from './dto/submit-rating.dto';

// docx 5.8 thresholds are marked "to be finalized" in the requirements doc (section 9,
// Open Items). These are placeholders — replace once the business settles on real numbers.
const CERTIFICATION_MIN_SERVICES = 10;
const CERTIFICATION_MIN_RATING = 4.5;

@Injectable()
export class RatingsService {
  constructor(private readonly prisma: PrismaService) {}

  // docx 4.6 "Submit Rating" -> updates the provider's average (docx 5.9) and
  // re-checks certification (docx 5.8).
  async submitRating(customerId: string, dto: SubmitRatingDto) {
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

    await this.prisma.provider.update({
      where: { id: dto.providerId },
      data: {
        averageRating: newAverage,
        ratingCount: newCount,
        certified: completedCount >= CERTIFICATION_MIN_SERVICES && newAverage >= CERTIFICATION_MIN_RATING,
      },
    });

    return rating;
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
