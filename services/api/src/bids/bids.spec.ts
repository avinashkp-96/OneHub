import { BadRequestException, ForbiddenException } from '@nestjs/common';
import { BidsController } from './bids.controller';
import { BidsService, PUBLIC_PROVIDER_FIELDS } from './bids.service';
import { PrismaService } from '../prisma/prisma.service';
import { NotificationsService } from '../notifications/notifications.service';

interface Setup {
  bid?: object;
  link?: object | null;
  requirement?: object | null;
}

function buildService(o: Setup = {}) {
  const bid = o.bid ?? {
    id: 'b1',
    providerId: 'p1',
    requirementId: 'r1',
    contactUnlocked: false,
    requirement: { customerId: 'cust-1', status: 'BID_RECEIVED' },
  };
  const prisma = {
    bid: {
      create: jest.fn().mockResolvedValue({ id: 'b1' }),
      findUniqueOrThrow: jest.fn().mockResolvedValue(bid),
      update: jest.fn().mockImplementation(async (args) => ({ id: args.where.id, ...args.data })),
      findMany: jest.fn().mockResolvedValue([{ id: 'b1' }]),
    },
    requirement: {
      update: jest.fn().mockResolvedValue({}),
      findUnique: jest
        .fn()
        .mockResolvedValue(o.requirement === undefined ? { customerId: 'cust-1' } : o.requirement),
    },
    requirementProvider: {
      findUnique: jest.fn().mockResolvedValue(o.link === undefined ? { providerId: 'p1' } : o.link),
    },
    payment: { create: jest.fn().mockResolvedValue({}) },
    $transaction: jest.fn().mockResolvedValue([]),
  };
  const notifications = {
    bidSubmitted: jest.fn().mockResolvedValue(undefined),
    contactUnlocked: jest.fn().mockResolvedValue(undefined),
    bidRefined: jest.fn().mockResolvedValue(undefined),
    providerConfirmed: jest.fn().mockResolvedValue(undefined),
  };
  const service = new BidsService(prisma as unknown as PrismaService, notifications as unknown as NotificationsService);
  return { service, prisma, notifications };
}

describe('BidsService.submitInitialBid', () => {
  it('stores the range and marks the requirement as having bids', async () => {
    const { service, prisma } = buildService();

    const bid = await service.submitInitialBid('r1', 'p1', { minPrice: 500, maxPrice: 900 });

    expect(prisma.bid.create).toHaveBeenCalledWith({
      data: { requirementId: 'r1', providerId: 'p1', initialMinPrice: 500, initialMaxPrice: 900 },
    });
    expect(prisma.requirement.update).toHaveBeenCalledWith({
      where: { id: 'r1' },
      data: { status: 'BID_RECEIVED' },
    });
    expect(bid).toEqual({ id: 'b1' });
  });

  it('refuses a provider the request was never sent to', async () => {
    const { service, prisma } = buildService({ link: null });

    await expect(service.submitInitialBid('r1', 'p9', { minPrice: 1, maxPrice: 2 })).rejects.toBeInstanceOf(
      ForbiddenException,
    );
    expect(prisma.bid.create).not.toHaveBeenCalled();
  });
});

describe('BidsService.unlockContact', () => {
  it('records a successful payment then flags the bid', async () => {
    const { service, prisma } = buildService();

    const result = await service.unlockContact('b1', 'p1');

    expect(prisma.payment.create).toHaveBeenCalledWith({
      data: {
        providerId: 'p1',
        bidId: 'b1',
        amount: 50,
        purpose: 'CONTACT_UNLOCK',
        status: 'SUCCESS',
      },
    });
    expect(prisma.bid.update).toHaveBeenCalledWith({
      where: { id: 'b1' },
      data: { contactUnlocked: true },
    });
    expect(result).toMatchObject({ contactUnlocked: true });
  });

  it("refuses another provider's bid and records no payment", async () => {
    const { service, prisma } = buildService();

    await expect(service.unlockContact('b1', 'someone-else')).rejects.toBeInstanceOf(ForbiddenException);
    expect(prisma.payment.create).not.toHaveBeenCalled();
    expect(prisma.bid.update).not.toHaveBeenCalled();
  });
});

describe('BidsService.updateRefinedBid', () => {
  it("refuses another provider's bid", async () => {
    const { service, prisma } = buildService({
      bid: { id: 'b1', providerId: 'p1', contactUnlocked: true },
    });

    await expect(service.updateRefinedBid('b1', 'p2', { minPrice: 1, maxPrice: 2 })).rejects.toBeInstanceOf(
      ForbiddenException,
    );
    expect(prisma.bid.update).not.toHaveBeenCalled();
  });

  it('refuses until the contact is unlocked', async () => {
    const { service, prisma } = buildService({
      bid: { id: 'b1', providerId: 'p1', contactUnlocked: false },
    });

    await expect(service.updateRefinedBid('b1', 'p1', { minPrice: 1, maxPrice: 2 })).rejects.toBeInstanceOf(
      BadRequestException,
    );
    expect(prisma.bid.update).not.toHaveBeenCalled();
  });

  it('saves the refined range once unlocked', async () => {
    const { service, prisma } = buildService({
      bid: { id: 'b1', providerId: 'p1', contactUnlocked: true },
    });

    await service.updateRefinedBid('b1', 'p1', { minPrice: 600, maxPrice: 800 });

    expect(prisma.bid.update).toHaveBeenCalledWith({
      where: { id: 'b1' },
      data: { refinedMinPrice: 600, refinedMaxPrice: 800 },
    });
  });
});

describe('BidsService.confirmBid', () => {
  it('confirms the bid and closes the requirement in one transaction', async () => {
    const { service, prisma } = buildService();

    const result = await service.confirmBid('b1', 'cust-1');

    expect(prisma.$transaction).toHaveBeenCalledTimes(1);
    expect(prisma.bid.update).toHaveBeenCalledWith({ where: { id: 'b1' }, data: { confirmed: true } });
    expect(prisma.requirement.update).toHaveBeenCalledWith({
      where: { id: 'r1' },
      data: { status: 'CONFIRMED', confirmedBidId: 'b1' },
    });
    expect(result).toEqual({ confirmed: true, bidId: 'b1' });
  });

  it("refuses a customer who does not own the request", async () => {
    const { service, prisma } = buildService();

    await expect(service.confirmBid('b1', 'someone-else')).rejects.toBeInstanceOf(ForbiddenException);
    expect(prisma.$transaction).not.toHaveBeenCalled();
  });

  it.each(['CONFIRMED', 'COMPLETED'])('refuses when the request is already %s', async (status) => {
    const { service, prisma } = buildService({
      bid: {
        id: 'b1',
        providerId: 'p1',
        requirementId: 'r1',
        requirement: { customerId: 'cust-1', status },
      },
    });

    await expect(service.confirmBid('b1', 'cust-1')).rejects.toBeInstanceOf(BadRequestException);
    expect(prisma.$transaction).not.toHaveBeenCalled();
  });
});

describe('BidsService notifications', () => {
  const unlockedBid = {
    id: 'b1',
    providerId: 'p1',
    requirementId: 'r1',
    contactUnlocked: true,
    requirement: { customerId: 'cust-1', status: 'BID_RECEIVED' },
  };

  it('tells the customer about a new bid', async () => {
    const { service, notifications } = buildService();
    await service.submitInitialBid('r1', 'p1', { minPrice: 300, maxPrice: 450 });
    expect(notifications.bidSubmitted).toHaveBeenCalledWith('b1');
  });

  it('confirms the unlock payment to the provider', async () => {
    const { service, notifications } = buildService();
    await service.unlockContact('b1', 'p1');
    expect(notifications.contactUnlocked).toHaveBeenCalledWith('b1');
  });

  it('tells the customer about a refined bid', async () => {
    const { service, notifications } = buildService({ bid: unlockedBid });
    await service.updateRefinedBid('b1', 'p1', { minPrice: 350, maxPrice: 400 });
    expect(notifications.bidRefined).toHaveBeenCalledWith('b1');
  });

  it('tells the providers who was selected', async () => {
    const { service, notifications } = buildService();
    await service.confirmBid('b1', 'cust-1');
    expect(notifications.providerConfirmed).toHaveBeenCalledWith('b1');
  });

  it('sends nothing when the action is refused', async () => {
    const { service, notifications } = buildService({ link: null });
    await expect(service.submitInitialBid('r1', 'p1', { minPrice: 1, maxPrice: 2 })).rejects.toBeInstanceOf(
      ForbiddenException,
    );
    await expect(service.unlockContact('b1', 'intruder')).rejects.toBeInstanceOf(ForbiddenException);
    await expect(service.updateRefinedBid('b1', 'p1', { minPrice: 1, maxPrice: 2 })).rejects.toBeInstanceOf(
      BadRequestException,
    );
    await expect(service.confirmBid('b1', 'someone-else')).rejects.toBeInstanceOf(ForbiddenException);
    for (const fn of Object.values(notifications)) expect(fn).not.toHaveBeenCalled();
  });
});

describe('BidsService.listForRequirement', () => {
  it('shows the owning customer every bid, with public provider fields only', async () => {
    const { service, prisma } = buildService();

    await service.listForRequirement('r1', { userId: 'cust-1', role: 'CUSTOMER' });

    expect(prisma.bid.findMany).toHaveBeenCalledWith({
      where: { requirementId: 'r1' },
      include: { provider: { select: PUBLIC_PROVIDER_FIELDS } },
    });
    expect(PUBLIC_PROVIDER_FIELDS).not.toHaveProperty('bankOrUpiDetails');
    expect(PUBLIC_PROVIDER_FIELDS).not.toHaveProperty('idProofUrl');
  });

  it("refuses a customer who does not own the request", async () => {
    const { service, prisma } = buildService();

    await expect(
      service.listForRequirement('r1', { userId: 'someone-else', role: 'CUSTOMER' }),
    ).rejects.toBeInstanceOf(ForbiddenException);
    expect(prisma.bid.findMany).not.toHaveBeenCalled();
  });

  it('refuses a customer when the request does not exist', async () => {
    const { service } = buildService({ requirement: null });

    await expect(
      service.listForRequirement('nope', { userId: 'cust-1', role: 'CUSTOMER' }),
    ).rejects.toBeInstanceOf(ForbiddenException);
  });

  it("shows a targeted provider only that provider's own bid", async () => {
    const { service, prisma } = buildService();

    await service.listForRequirement('r1', { userId: 'u2', role: 'PROVIDER', providerId: 'p1' });

    expect(prisma.bid.findMany).toHaveBeenCalledWith({
      where: { requirementId: 'r1', providerId: 'p1' },
      include: { provider: { select: PUBLIC_PROVIDER_FIELDS } },
    });
  });

  it('refuses a provider the request was not sent to', async () => {
    const { service } = buildService({ link: null });

    await expect(
      service.listForRequirement('r1', { userId: 'u2', role: 'PROVIDER', providerId: 'p9' }),
    ).rejects.toBeInstanceOf(ForbiddenException);
  });

  it('refuses a provider-role caller with no provider profile', async () => {
    const { service } = buildService();

    await expect(
      service.listForRequirement('r1', { userId: 'u2', role: 'PROVIDER' }),
    ).rejects.toBeInstanceOf(ForbiddenException);
  });
});

describe('BidsController', () => {
  function build() {
    const bids = {
      submitInitialBid: jest.fn().mockResolvedValue('submitted'),
      listForRequirement: jest.fn().mockResolvedValue('listed'),
      unlockContact: jest.fn().mockResolvedValue('unlocked'),
      updateRefinedBid: jest.fn().mockResolvedValue('refined'),
      confirmBid: jest.fn().mockResolvedValue('confirmed'),
    };
    const prisma = { provider: { findUniqueOrThrow: jest.fn().mockResolvedValue({ id: 'prov-1' }) } };
    const controller = new BidsController(
      bids as unknown as BidsService,
      prisma as unknown as PrismaService,
    );
    return { controller, bids, prisma };
  }
  const providerReq = { user: { sub: 'user-1', role: 'PROVIDER' as const } };
  const customerReq = { user: { sub: 'cust-1', role: 'CUSTOMER' as const } };

  it('submit resolves the provider from the signed-in user', async () => {
    const { controller, bids, prisma } = build();

    await controller.submit(providerReq, 'r1', { minPrice: 1, maxPrice: 2 });

    expect(prisma.provider.findUniqueOrThrow).toHaveBeenCalledWith({ where: { userId: 'user-1' } });
    expect(bids.submitInitialBid).toHaveBeenCalledWith('r1', 'prov-1', { minPrice: 1, maxPrice: 2 });
  });

  it('list passes the viewer, adding the provider id only for providers', async () => {
    const { controller, bids } = build();

    await controller.list(providerReq, 'r1');
    await controller.list(customerReq, 'r1');

    expect(bids.listForRequirement).toHaveBeenNthCalledWith(1, 'r1', {
      userId: 'user-1',
      role: 'PROVIDER',
      providerId: 'prov-1',
    });
    expect(bids.listForRequirement).toHaveBeenNthCalledWith(2, 'r1', {
      userId: 'cust-1',
      role: 'CUSTOMER',
      providerId: undefined,
    });
  });

  it('unlock and refine act as the signed-in provider', async () => {
    const { controller, bids } = build();

    expect(await controller.unlock(providerReq, 'b1')).toBe('unlocked');
    expect(await controller.refine(providerReq, 'b1', { minPrice: 1, maxPrice: 2 })).toBe('refined');
    expect(bids.unlockContact).toHaveBeenCalledWith('b1', 'prov-1');
    expect(bids.updateRefinedBid).toHaveBeenCalledWith('b1', 'prov-1', { minPrice: 1, maxPrice: 2 });
  });

  it('confirm acts as the signed-in customer', async () => {
    const { controller, bids } = build();

    expect(await controller.confirm(customerReq, 'b1')).toBe('confirmed');
    expect(bids.confirmBid).toHaveBeenCalledWith('b1', 'cust-1');
  });
});
