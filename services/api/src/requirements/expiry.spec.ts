import { BadRequestException } from '@nestjs/common';
import { BidsService } from '../bids/bids.service';
import { NotificationsService } from '../notifications/notifications.service';
import { PrismaService } from '../prisma/prisma.service';
import { closesAt, expireStale, hasExpired, REQUEST_OPEN_DAYS, staleWhere } from './expiry';
import { RequirementsService } from './requirements.service';

const DAY = 24 * 60 * 60 * 1000;
const now = new Date('2026-11-25T10:00:00Z');
const ago = (days: number) => new Date(now.getTime() - days * DAY);

describe('request expiry rule', () => {
  it(`closes ${REQUEST_OPEN_DAYS} days after posting`, () => {
    expect(closesAt({ createdAt: ago(1) })).toEqual(new Date(ago(1).getTime() + 3 * DAY));
  });

  it('stays open until the day after a later preferred date', () => {
    const preferredAt = new Date(now.getTime() + 10 * DAY);
    expect(closesAt({ createdAt: ago(1), preferredAt })).toEqual(new Date(preferredAt.getTime() + DAY));
  });

  it('an earlier preferred date does not shorten the window', () => {
    expect(closesAt({ createdAt: ago(1), preferredAt: ago(1) })).toEqual(new Date(ago(1).getTime() + 3 * DAY));
  });

  it('only open requests past their time, or ones marked EXPIRED, have expired', () => {
    expect(hasExpired({ status: 'BID_RECEIVED', createdAt: ago(4) }, now)).toBe(true);
    expect(hasExpired({ status: 'SENT', createdAt: ago(2) }, now)).toBe(false);
    expect(hasExpired({ status: 'CONFIRMED', createdAt: ago(30) }, now)).toBe(false);
    expect(hasExpired({ status: 'EXPIRED', createdAt: ago(0) }, now)).toBe(true);
  });

  it('the database filter matches the same rule', () => {
    expect(staleWhere(now)).toEqual({
      status: { in: ['SENT', 'ACCEPTED', 'BID_RECEIVED'] },
      createdAt: { lte: ago(3) },
      OR: [{ preferredAt: null }, { preferredAt: { lte: ago(1) } }],
    });
  });

  it('expireStale marks matching requests EXPIRED within the scope', async () => {
    const prisma = { requirement: { updateMany: jest.fn().mockResolvedValue({ count: 2 }) } };

    await expireStale(prisma as unknown as PrismaService, { customerId: 'c1' }, now);

    expect(prisma.requirement.updateMany).toHaveBeenCalledWith({
      where: { AND: [staleWhere(now), { customerId: 'c1' }] },
      data: { status: 'EXPIRED' },
    });
  });
});

describe('lists sweep expired requests first', () => {
  const build = () => {
    const prisma = {
      requirement: { findMany: jest.fn().mockResolvedValue([]), updateMany: jest.fn().mockResolvedValue({ count: 0 }) },
      provider: { findMany: jest.fn().mockResolvedValue([]), findUnique: jest.fn().mockResolvedValue(null) },
    };
    return { service: new RequirementsService(prisma as unknown as PrismaService, {} as NotificationsService), prisma };
  };

  it("for the customer's own requests", async () => {
    const { service, prisma } = build();
    await service.listForCustomer('c1');
    expect(prisma.requirement.updateMany.mock.calls[0][0].where.AND[1]).toEqual({ customerId: 'c1' });
    expect(prisma.requirement.updateMany.mock.invocationCallOrder[0]).toBeLessThan(
      prisma.requirement.findMany.mock.invocationCallOrder[0],
    );
  });

  it("for the requests sent to a provider", async () => {
    const { service, prisma } = build();
    await service.listForProvider('p1');
    expect(prisma.requirement.updateMany.mock.calls[0][0].where.AND[1]).toEqual({
      targetedProviders: { some: { providerId: 'p1' } },
    });
  });
});

describe('bids on an expired request', () => {
  const build = (requirement: object, bid: object = {}) => {
    const prisma = {
      bid: {
        create: jest.fn(),
        findFirst: jest.fn().mockResolvedValue(null),
        findUniqueOrThrow: jest.fn().mockResolvedValue({
          id: 'b1',
          providerId: 'p1',
          requirementId: 'r1',
          contactUnlocked: false,
          requirement: { customerId: 'c1', ...requirement },
          ...bid,
        }),
        update: jest.fn(),
      },
      requirement: {
        findUniqueOrThrow: jest.fn().mockResolvedValue(requirement),
        updateMany: jest.fn().mockResolvedValue({ count: 1 }),
      },
      requirementProvider: { findUnique: jest.fn().mockResolvedValue({ status: 'SENT' }) },
      payment: { create: jest.fn() },
      $transaction: jest.fn(),
    };
    return { service: new BidsService(prisma as unknown as PrismaService, {} as NotificationsService), prisma };
  };
  const stale = { status: 'BID_RECEIVED', createdAt: new Date(Date.now() - 4 * DAY), preferredAt: null };

  it('a price is refused and the request is marked expired', async () => {
    const { service, prisma } = build(stale);

    await expect(service.submitInitialBid('r1', 'p1', { minPrice: 1, maxPrice: 2 })).rejects.toThrow(
      'this request has expired',
    );
    expect(prisma.bid.create).not.toHaveBeenCalled();
    expect(prisma.requirement.updateMany.mock.calls[0][0].data).toEqual({ status: 'EXPIRED' });
  });

  it('an unlock is refused and nothing is charged', async () => {
    const { service, prisma } = build({ status: 'EXPIRED', createdAt: new Date(), preferredAt: null });

    await expect(service.unlockContact('b1', 'p1')).rejects.toBeInstanceOf(BadRequestException);
    expect(prisma.payment.create).not.toHaveBeenCalled();
  });

  it('a second unlock of the same bid is refused, so it is never paid twice', async () => {
    const { service, prisma } = build(stale, { contactUnlocked: true });

    await expect(service.unlockContact('b1', 'p1')).rejects.toThrow('contact is already unlocked for this bid');
    expect(prisma.payment.create).not.toHaveBeenCalled();
  });

  it('the customer cannot confirm on an expired request', async () => {
    const { service, prisma } = build(stale);

    await expect(service.confirmBid('b1', 'c1')).rejects.toThrow('post it again to get new prices');
    expect(prisma.$transaction).not.toHaveBeenCalled();
  });
});
