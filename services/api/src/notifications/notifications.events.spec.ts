import { Logger } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { NotificationsController } from './notifications.controller';
import { NotificationEvent, NotificationsService } from './notifications.service';

// The Notification Matrix (docx section 6): who is told about what.
function build() {
  const prisma = {
    notification: {
      createMany: jest.fn().mockResolvedValue({ count: 1 }),
      updateMany: jest.fn().mockResolvedValue({ count: 3 }),
    },
    requirement: {
      findUniqueOrThrow: jest.fn().mockResolvedValue({
        customerId: 'cust-1',
        title: 'Kitchen switchboard sparking',
        targetedProviders: [{ providerId: 'p1' }, { providerId: 'p2' }],
      }),
    },
    provider: {
      findUniqueOrThrow: jest.fn().mockResolvedValue({
        userId: 'u-p1',
        businessName: 'Rajesh Electricals',
        user: { fullName: 'Rajesh K' },
      }),
      findMany: jest.fn(async ({ where }) =>
        (where.id.in as string[]).map((id) => ({ id, userId: `u-${id}` })),
      ),
    },
    bid: {
      findUniqueOrThrow: jest.fn().mockResolvedValue({
        requirementId: 'r1',
        providerId: 'p1',
        initialMinPrice: 300,
        initialMaxPrice: 1450,
        requirement: { customerId: 'cust-1' },
        provider: { userId: 'u-p1', businessName: 'Rajesh Electricals', user: { fullName: 'Rajesh K' } },
      }),
      findMany: jest.fn().mockResolvedValue([{ providerId: 'p2' }, { providerId: 'p3' }]),
    },
  };
  const service = new NotificationsService(prisma as unknown as PrismaService);
  const sent = () => prisma.notification.createMany.mock.calls.flatMap((c) => c[0].data);
  return { service, prisma, sent };
}

describe('Notification Matrix events', () => {
  it('new request: each targeted provider, by sub-service name', async () => {
    const { service, sent } = build();
    await service.requestSent('r1');
    expect(sent()).toEqual([
      { userId: 'u-p1', event: NotificationEvent.NEW_REQUEST, message: 'New job request: Kitchen switchboard sparking', requirementId: 'r1', channel: 'IN_APP' },
      { userId: 'u-p2', event: NotificationEvent.NEW_REQUEST, message: 'New job request: Kitchen switchboard sparking', requirementId: 'r1', channel: 'IN_APP' },
    ]);
  });

  it('new request with no providers sends nothing', async () => {
    const { service, prisma } = build();
    prisma.requirement.findUniqueOrThrow.mockResolvedValue({ title: 'X', targetedProviders: [] });
    await service.requestSent('r1');
    expect(prisma.notification.createMany).not.toHaveBeenCalled();
  });


  it('bid submitted: the customer, with the range in rupees', async () => {
    const { service, sent } = build();
    await service.bidSubmitted('b1');
    expect(sent()).toEqual([
      expect.objectContaining({
        userId: 'cust-1',
        event: NotificationEvent.BID_RECEIVED,
        message: 'New bid received from Rajesh Electricals: ₹300–₹1,450',
      }),
    ]);
  });

  it("bid submitted: falls back to the person's name without a business name", async () => {
    const { service, prisma, sent } = build();
    prisma.bid.findUniqueOrThrow.mockResolvedValue({
      initialMinPrice: 300,
      initialMaxPrice: 1450,
      requirement: { customerId: 'cust-1' },
      provider: { userId: 'u-p1', businessName: null, user: { fullName: 'Rajesh K' } },
    });
    await service.bidSubmitted('b1');
    expect(sent()[0].message).toBe('New bid received from Rajesh K: ₹300–₹1,450');
  });

  it('contact unlocked: the provider who paid', async () => {
    const { service, sent } = build();
    await service.contactUnlocked('b1');
    expect(sent()).toEqual([
      expect.objectContaining({ userId: 'u-p1', event: NotificationEvent.CONTACT_UNLOCKED }),
    ]);
  });

  it('bid refined: the customer', async () => {
    const { service, sent } = build();
    await service.bidRefined('b1');
    expect(sent()).toEqual([
      expect.objectContaining({ userId: 'cust-1', message: 'Rajesh Electricals updated their price range' }),
    ]);
  });

  it('provider confirmed: selected to the winner, not selected to the other bidders', async () => {
    const { service, prisma, sent } = build();
    await service.providerConfirmed('b1');

    expect(prisma.bid.findMany).toHaveBeenCalledWith(
      expect.objectContaining({ where: { requirementId: 'r1', providerId: { not: 'p1' } } }),
    );
    expect(sent().map((n: { userId: string; event: string }) => [n.userId, n.event])).toEqual([
      ['u-p1', NotificationEvent.SELECTED],
      ['u-p2', NotificationEvent.NOT_SELECTED],
      ['u-p3', NotificationEvent.NOT_SELECTED],
    ]);
  });

  it('job completed: the customer, prompting a rating', async () => {
    const { service, sent } = build();
    await service.jobCompleted('r1');
    expect(sent()).toEqual([
      expect.objectContaining({ userId: 'cust-1', event: NotificationEvent.JOB_COMPLETED }),
    ]);
  });

  it('rating received: the provider, with the stars', async () => {
    const { service, sent } = build();
    await service.ratingReceived('p1', 5, false);
    expect(sent()).toEqual([
      expect.objectContaining({ userId: 'u-p1', event: NotificationEvent.NEW_RATING, message: 'You received a new 5★ rating' }),
    ]);
  });

  it('rating that earns certification: also the certified badge', async () => {
    const { service, sent } = build();
    await service.ratingReceived('p1', 5, true);
    expect(sent().map((n: { event: string }) => n.event)).toEqual([NotificationEvent.NEW_RATING, NotificationEvent.CERTIFIED]);
  });

  it('every request event names its request, so the apps can open it', async () => {
    const { service, sent } = build();
    await service.bidSubmitted('b1');
    await service.contactUnlocked('b1');
    await service.bidRefined('b1');
    await service.providerConfirmed('b1');
    await service.jobCompleted('r1');

    const notes = sent() as { event: string; requirementId?: string }[];
    expect(notes).toHaveLength(7);
    expect(notes.every((n) => n.requirementId === 'r1')).toBe(true);
  });

  it('rating events are about the provider, not a request', async () => {
    const { service, sent } = build();
    await service.ratingReceived('p1', 5, true);
    expect(sent().map((n: { requirementId?: string }) => n.requirementId)).toEqual([undefined, undefined]);
  });

  it('a failure is logged and never thrown to the caller', async () => {
    const { service, prisma } = build();
    const warn = jest.spyOn(Logger.prototype, 'warn').mockImplementation(() => undefined);
    prisma.bid.findUniqueOrThrow.mockRejectedValue(new Error('db down'));

    await expect(service.bidSubmitted('b1')).resolves.toBeUndefined();

    expect(warn).toHaveBeenCalledWith(expect.stringContaining('db down'));
    expect(prisma.notification.createMany).not.toHaveBeenCalled();
    warn.mockRestore();
  });
});

describe('Mark all as read', () => {
  it("marks only the caller's unread notifications", async () => {
    const { service, prisma } = build();

    expect(await service.markAllRead('u1')).toEqual({ read: 3 });

    const args = prisma.notification.updateMany.mock.calls[0][0];
    expect(args.where).toEqual({ userId: 'u1', readAt: null });
    expect(args.data.readAt).toBeInstanceOf(Date);
  });

  it('controller uses the signed-in user', async () => {
    const notifications = { markAllRead: jest.fn().mockResolvedValue({ read: 2 }) };
    const controller = new NotificationsController(notifications as unknown as NotificationsService);

    expect(await controller.markAllRead({ user: { sub: 'u1', role: 'CUSTOMER' } })).toEqual({ read: 2 });
    expect(notifications.markAllRead).toHaveBeenCalledWith('u1');
  });
});
