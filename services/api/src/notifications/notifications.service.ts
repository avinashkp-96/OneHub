import { Injectable, Logger, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

// docx section 6, Notification Matrix. Each row is one method below, called by
// the service where that event happens. They look up who to tell and the
// names to put in the message themselves, so the callers only pass ids.
//
// Records are stored with channel IN_APP and shown in the apps' notification
// list. Push and SMS delivery are not integrated yet (see CLAUDE.md,
// Integrations). The matrix's "subscription expiring/renewed" row has no
// event to hang off until a renewal job exists.
//
// Sending is best-effort: a failure is logged and never fails the action that
// triggered it (a bid must not be lost because its notification was not).
export const NotificationEvent = {
  NEW_REQUEST: 'NEW_REQUEST',
  REQUEST_ACCEPTED: 'REQUEST_ACCEPTED',
  BID_RECEIVED: 'BID_RECEIVED',
  CONTACT_UNLOCKED: 'CONTACT_UNLOCKED',
  BID_UPDATED: 'BID_UPDATED',
  SELECTED: 'SELECTED',
  NOT_SELECTED: 'NOT_SELECTED',
  JOB_COMPLETED: 'JOB_COMPLETED',
  NEW_RATING: 'NEW_RATING',
  CERTIFIED: 'CERTIFIED',
} as const;
export type NotificationEventName = (typeof NotificationEvent)[keyof typeof NotificationEvent];

type Note = { userId: string; event: NotificationEventName; message: string };

@Injectable()
export class NotificationsService {
  private readonly logger = new Logger(NotificationsService.name);

  constructor(private readonly prisma: PrismaService) {}

  notify(userId: string, event: string, message: string, channel: 'PUSH' | 'IN_APP' | 'SMS') {
    return this.prisma.notification.create({ data: { userId, event, message, channel } });
  }

  listForUser(userId: string) {
    return this.prisma.notification.findMany({ where: { userId }, orderBy: { createdAt: 'desc' } });
  }

  // Scoped to the owner: someone else's notification id behaves as not found.
  async markRead(id: string, userId: string) {
    const result = await this.prisma.notification.updateMany({
      where: { id, userId },
      data: { readAt: new Date() },
    });
    if (result.count === 0) throw new NotFoundException('notification not found');
    return { id, read: true };
  }

  async markAllRead(userId: string) {
    const result = await this.prisma.notification.updateMany({
      where: { userId, readAt: null },
      data: { readAt: new Date() },
    });
    return { read: result.count };
  }

  // --- Matrix events --------------------------------------------------------

  // New requirement matches provider -> each provider it was sent to.
  requestSent(requirementId: string) {
    return this.send(`requestSent ${requirementId}`, async () => {
      const r = await this.prisma.requirement.findUniqueOrThrow({
        where: { id: requirementId },
        select: {
          subService: { select: { name: true } },
          targetedProviders: { select: { providerId: true } },
        },
      });
      const users = await this.providerUsers(r.targetedProviders.map((t) => t.providerId));
      return users.map((u) => ({
        userId: u.userId,
        event: NotificationEvent.NEW_REQUEST,
        message: `New job request: ${r.subService.name}`,
      }));
    });
  }

  // Provider accepts a request -> the customer. Rejections are not sent (docx
  // 5.3: the customer only sees the overall status).
  requestAccepted(requirementId: string, providerId: string) {
    return this.send(`requestAccepted ${requirementId}`, async () => {
      const [r, p] = await Promise.all([
        this.prisma.requirement.findUniqueOrThrow({ where: { id: requirementId }, select: { customerId: true } }),
        this.provider(providerId),
      ]);
      return [{ userId: r.customerId, event: NotificationEvent.REQUEST_ACCEPTED, message: `${p.name} accepted your request` }];
    });
  }

  // Bid submitted -> the customer.
  bidSubmitted(bidId: string) {
    return this.send(`bidSubmitted ${bidId}`, async () => {
      const b = await this.bid(bidId);
      return [
        {
          userId: b.customerId,
          event: NotificationEvent.BID_RECEIVED,
          message: `New bid received from ${b.providerName}: ${rupees(b.initialMinPrice)}–${rupees(b.initialMaxPrice)}`,
        },
      ];
    });
  }

  // Contact-unlock payment success -> the provider who paid.
  contactUnlocked(bidId: string) {
    return this.send(`contactUnlocked ${bidId}`, async () => {
      const b = await this.bid(bidId);
      return [
        {
          userId: b.providerUserId,
          event: NotificationEvent.CONTACT_UNLOCKED,
          message: 'Payment successful. You can now contact the customer.',
        },
      ];
    });
  }

  // Provider updates a refined bid -> the customer.
  bidRefined(bidId: string) {
    return this.send(`bidRefined ${bidId}`, async () => {
      const b = await this.bid(bidId);
      return [
        { userId: b.customerId, event: NotificationEvent.BID_UPDATED, message: `${b.providerName} updated their price range` },
      ];
    });
  }

  // Customer confirms a provider -> that provider, and every other provider
  // who bid on the same request.
  providerConfirmed(bidId: string) {
    return this.send(`providerConfirmed ${bidId}`, async () => {
      const bid = await this.prisma.bid.findUniqueOrThrow({
        where: { id: bidId },
        select: { requirementId: true, providerId: true },
      });
      const others = await this.prisma.bid.findMany({
        where: { requirementId: bid.requirementId, providerId: { not: bid.providerId } },
        select: { providerId: true },
      });
      const users = await this.providerUsers([bid.providerId, ...others.map((o) => o.providerId)]);
      return users.map((u) =>
        u.providerId === bid.providerId
          ? { userId: u.userId, event: NotificationEvent.SELECTED, message: "You've been selected for the job! Tap to view details." }
          : { userId: u.userId, event: NotificationEvent.NOT_SELECTED, message: 'This job has been assigned to another provider' },
      );
    });
  }

  // Job marked complete -> the customer, prompting the rating.
  jobCompleted(requirementId: string) {
    return this.send(`jobCompleted ${requirementId}`, async () => {
      const r = await this.prisma.requirement.findUniqueOrThrow({ where: { id: requirementId }, select: { customerId: true } });
      return [
        { userId: r.customerId, event: NotificationEvent.JOB_COMPLETED, message: 'Job completed. Rate your service provider.' },
      ];
    });
  }

  // New rating received -> the provider; and certified badge earned, when this
  // rating is the one that tipped them over.
  ratingReceived(providerId: string, stars: number, becameCertified: boolean) {
    return this.send(`ratingReceived ${providerId}`, async () => {
      const p = await this.provider(providerId);
      const notes: Note[] = [
        { userId: p.userId, event: NotificationEvent.NEW_RATING, message: `You received a new ${stars}★ rating` },
      ];
      if (becameCertified) {
        notes.push({
          userId: p.userId,
          event: NotificationEvent.CERTIFIED,
          message: "Congratulations! You're now a Certified Provider",
        });
      }
      return notes;
    });
  }

  // --- Helpers ----------------------------------------------------------------

  private async send(what: string, build: () => Promise<Note[]>) {
    try {
      const notes = await build();
      if (notes.length === 0) return;
      await this.prisma.notification.createMany({ data: notes.map((n) => ({ ...n, channel: 'IN_APP' })) });
    } catch (e) {
      this.logger.warn(`notification ${what} not sent: ${(e as Error).message}`);
    }
  }

  private async provider(providerId: string) {
    const p = await this.prisma.provider.findUniqueOrThrow({
      where: { id: providerId },
      select: { userId: true, businessName: true, user: { select: { fullName: true } } },
    });
    return { userId: p.userId, name: p.businessName ?? p.user.fullName };
  }

  private async providerUsers(providerIds: string[]) {
    if (providerIds.length === 0) return [];
    const rows = await this.prisma.provider.findMany({
      where: { id: { in: providerIds } },
      select: { id: true, userId: true },
    });
    return rows.map((r) => ({ providerId: r.id, userId: r.userId }));
  }

  private async bid(bidId: string) {
    const b = await this.prisma.bid.findUniqueOrThrow({
      where: { id: bidId },
      select: {
        initialMinPrice: true,
        initialMaxPrice: true,
        requirement: { select: { customerId: true } },
        provider: { select: { userId: true, businessName: true, user: { select: { fullName: true } } } },
      },
    });
    return {
      customerId: b.requirement.customerId,
      providerUserId: b.provider.userId,
      providerName: b.provider.businessName ?? b.provider.user.fullName,
      initialMinPrice: b.initialMinPrice,
      initialMaxPrice: b.initialMaxPrice,
    };
  }
}

function rupees(amount: number) {
  return `₹${amount.toLocaleString('en-IN', { maximumFractionDigits: 0 })}`;
}
