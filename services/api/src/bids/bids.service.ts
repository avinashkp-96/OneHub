import { BadRequestException, ForbiddenException, Injectable } from '@nestjs/common';
import { NotificationsService } from '../notifications/notifications.service';
import { PrismaService } from '../prisma/prisma.service';
import { PriceRangeDto } from './dto/submit-bid.dto';

const CONTACT_UNLOCK_PRICE_INR = Number(process.env.CONTACT_UNLOCK_PRICE_INR ?? 50);

// What a customer may see of a provider next to a bid. Never the whole row:
// it also holds the ID proof URL and bank/UPI details.
export const PUBLIC_PROVIDER_FIELDS = {
  id: true,
  businessName: true,
  yearsExperience: true,
  averageRating: true,
  ratingCount: true,
  certified: true,
} as const;

export interface BidViewer {
  userId: string;
  role: 'CUSTOMER' | 'PROVIDER' | 'ADMIN';
  providerId?: string;
}

@Injectable()
export class BidsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly notifications: NotificationsService,
  ) {}

  // docx 5.4 "Submit Bid" — only a provider the request was sent to may bid.
  async submitInitialBid(requirementId: string, providerId: string, range: PriceRangeDto) {
    const link = await this.prisma.requirementProvider.findUnique({
      where: { requirementId_providerId: { requirementId, providerId } },
    });
    if (!link) throw new ForbiddenException('this request was not sent to you');

    const bid = await this.prisma.bid.create({
      data: {
        requirementId,
        providerId,
        initialMinPrice: range.minPrice,
        initialMaxPrice: range.maxPrice,
      },
    });
    await this.prisma.requirement.update({ where: { id: requirementId }, data: { status: 'BID_RECEIVED' } });
    await this.notifications.bidSubmitted(bid.id);
    return bid;
  }

  // docx 5.4 "Pay ₹50 to Contact Customer" — payment gateway integration is a follow-up; this
  // records the unlock once payment succeeds upstream. Only the bid's own provider may unlock.
  async unlockContact(bidId: string, providerId: string) {
    const bid = await this.ownedBid(bidId, providerId);
    await this.prisma.payment.create({
      data: {
        providerId: bid.providerId,
        bidId,
        amount: CONTACT_UNLOCK_PRICE_INR,
        purpose: 'CONTACT_UNLOCK',
        status: 'SUCCESS',
      },
    });
    const unlocked = await this.prisma.bid.update({ where: { id: bidId }, data: { contactUnlocked: true } });
    await this.notifications.contactUnlocked(bidId);
    return unlocked;
  }

  // docx 5.4 "Update Bid" (refined range)
  async updateRefinedBid(bidId: string, providerId: string, range: PriceRangeDto) {
    const bid = await this.ownedBid(bidId, providerId);
    if (!bid.contactUnlocked) {
      throw new BadRequestException('unlock contact with the customer before refining the bid');
    }
    const refined = await this.prisma.bid.update({
      where: { id: bidId },
      data: { refinedMinPrice: range.minPrice, refinedMaxPrice: range.maxPrice },
    });
    await this.notifications.bidRefined(bidId);
    return refined;
  }

  // docx 4.4 "Confirm Provider" — closes bidding for the requirement. Only the
  // customer who posted the request may confirm one of its bids, and only once.
  async confirmBid(bidId: string, customerId: string) {
    const bid = await this.prisma.bid.findUniqueOrThrow({
      where: { id: bidId },
      include: { requirement: { select: { customerId: true, status: true } } },
    });
    if (bid.requirement.customerId !== customerId) {
      throw new ForbiddenException('this is not your request');
    }
    if (bid.requirement.status === 'CONFIRMED' || bid.requirement.status === 'COMPLETED') {
      throw new BadRequestException('a provider has already been confirmed for this request');
    }
    await this.prisma.$transaction([
      this.prisma.bid.update({ where: { id: bidId }, data: { confirmed: true } }),
      this.prisma.requirement.update({
        where: { id: bid.requirementId },
        data: { status: 'CONFIRMED', confirmedBidId: bidId },
      }),
    ]);
    await this.notifications.providerConfirmed(bidId);
    return { confirmed: true, bidId };
  }

  // The customer who owns the request sees every bid; a provider the request
  // was sent to sees only their own.
  async listForRequirement(requirementId: string, viewer: BidViewer) {
    if (viewer.role === 'CUSTOMER') {
      const requirement = await this.prisma.requirement.findUnique({
        where: { id: requirementId },
        select: { customerId: true },
      });
      if (!requirement || requirement.customerId !== viewer.userId) {
        throw new ForbiddenException('this is not your request');
      }
      return this.prisma.bid.findMany({
        where: { requirementId },
        include: { provider: { select: PUBLIC_PROVIDER_FIELDS } },
      });
    }

    if (!viewer.providerId) throw new ForbiddenException('no provider profile');
    const link = await this.prisma.requirementProvider.findUnique({
      where: { requirementId_providerId: { requirementId, providerId: viewer.providerId } },
    });
    if (!link) throw new ForbiddenException('this request was not sent to you');
    return this.prisma.bid.findMany({
      where: { requirementId, providerId: viewer.providerId },
      include: { provider: { select: PUBLIC_PROVIDER_FIELDS } },
    });
  }

  private async ownedBid(bidId: string, providerId: string) {
    const bid = await this.prisma.bid.findUniqueOrThrow({ where: { id: bidId } });
    if (bid.providerId !== providerId) throw new ForbiddenException('this is not your bid');
    return bid;
  }
}
