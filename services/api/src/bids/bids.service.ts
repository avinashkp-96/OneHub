import { BadRequestException, Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { PriceRangeDto } from './dto/submit-bid.dto';

const CONTACT_UNLOCK_PRICE_INR = Number(process.env.CONTACT_UNLOCK_PRICE_INR ?? 50);

@Injectable()
export class BidsService {
  constructor(private readonly prisma: PrismaService) {}

  // docx 5.4 "Submit Bid"
  async submitInitialBid(requirementId: string, providerId: string, range: PriceRangeDto) {
    const bid = await this.prisma.bid.create({
      data: {
        requirementId,
        providerId,
        initialMinPrice: range.minPrice,
        initialMaxPrice: range.maxPrice,
      },
    });
    await this.prisma.requirement.update({ where: { id: requirementId }, data: { status: 'BID_RECEIVED' } });
    return bid;
  }

  // docx 5.4 "Pay ₹50 to Contact Customer" — payment gateway integration is a follow-up; this
  // records the unlock once payment succeeds upstream.
  async unlockContact(bidId: string) {
    const bid = await this.prisma.bid.findUniqueOrThrow({ where: { id: bidId } });
    await this.prisma.payment.create({
      data: {
        providerId: bid.providerId,
        bidId,
        amount: CONTACT_UNLOCK_PRICE_INR,
        purpose: 'CONTACT_UNLOCK',
        status: 'SUCCESS',
      },
    });
    return this.prisma.bid.update({ where: { id: bidId }, data: { contactUnlocked: true } });
  }

  // docx 5.4 "Update Bid" (refined range)
  async updateRefinedBid(bidId: string, range: PriceRangeDto) {
    const bid = await this.prisma.bid.findUniqueOrThrow({ where: { id: bidId } });
    if (!bid.contactUnlocked) {
      throw new BadRequestException('unlock contact with the customer before refining the bid');
    }
    return this.prisma.bid.update({
      where: { id: bidId },
      data: { refinedMinPrice: range.minPrice, refinedMaxPrice: range.maxPrice },
    });
  }

  // docx 4.4 "Confirm Provider" — closes bidding for the requirement.
  async confirmBid(bidId: string) {
    const bid = await this.prisma.bid.findUniqueOrThrow({ where: { id: bidId } });
    await this.prisma.$transaction([
      this.prisma.bid.update({ where: { id: bidId }, data: { confirmed: true } }),
      this.prisma.requirement.update({
        where: { id: bid.requirementId },
        data: { status: 'CONFIRMED', confirmedBidId: bidId },
      }),
    ]);
    return { confirmed: true, bidId };
  }

  listForRequirement(requirementId: string) {
    return this.prisma.bid.findMany({ where: { requirementId }, include: { provider: true } });
  }
}
