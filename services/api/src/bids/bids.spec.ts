import { BadRequestException } from '@nestjs/common';
import { BidsController } from './bids.controller';
import { BidsService } from './bids.service';
import { PrismaService } from '../prisma/prisma.service';

function buildService(bid: object = { id: 'b1', providerId: 'p1', requirementId: 'r1', contactUnlocked: false }) {
  const prisma = {
    bid: {
      create: jest.fn().mockResolvedValue({ id: 'b1' }),
      findUniqueOrThrow: jest.fn().mockResolvedValue(bid),
      update: jest.fn().mockImplementation(async (args) => ({ id: args.where.id, ...args.data })),
      findMany: jest.fn().mockResolvedValue([{ id: 'b1' }]),
    },
    requirement: { update: jest.fn().mockResolvedValue({}) },
    payment: { create: jest.fn().mockResolvedValue({}) },
    $transaction: jest.fn().mockResolvedValue([]),
  };
  const service = new BidsService(prisma as unknown as PrismaService);
  return { service, prisma };
}

describe('BidsService', () => {
  it('submitInitialBid stores the range and marks the requirement as having bids', async () => {
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

  it('unlockContact records a successful payment then flags the bid', async () => {
    const { service, prisma } = buildService();

    const result = await service.unlockContact('b1');

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

  it('updateRefinedBid refuses until the contact is unlocked', async () => {
    const { service, prisma } = buildService({ id: 'b1', contactUnlocked: false });

    await expect(service.updateRefinedBid('b1', { minPrice: 1, maxPrice: 2 })).rejects.toBeInstanceOf(
      BadRequestException,
    );
    expect(prisma.bid.update).not.toHaveBeenCalled();
  });

  it('updateRefinedBid saves the refined range once unlocked', async () => {
    const { service, prisma } = buildService({ id: 'b1', contactUnlocked: true });

    await service.updateRefinedBid('b1', { minPrice: 600, maxPrice: 800 });

    expect(prisma.bid.update).toHaveBeenCalledWith({
      where: { id: 'b1' },
      data: { refinedMinPrice: 600, refinedMaxPrice: 800 },
    });
  });

  it('confirmBid confirms the bid and closes the requirement in one transaction', async () => {
    const { service, prisma } = buildService();

    const result = await service.confirmBid('b1');

    expect(prisma.$transaction).toHaveBeenCalledTimes(1);
    expect(prisma.bid.update).toHaveBeenCalledWith({ where: { id: 'b1' }, data: { confirmed: true } });
    expect(prisma.requirement.update).toHaveBeenCalledWith({
      where: { id: 'r1' },
      data: { status: 'CONFIRMED', confirmedBidId: 'b1' },
    });
    expect(result).toEqual({ confirmed: true, bidId: 'b1' });
  });

  it('listForRequirement includes the provider', async () => {
    const { service, prisma } = buildService();

    await service.listForRequirement('r1');

    expect(prisma.bid.findMany).toHaveBeenCalledWith({
      where: { requirementId: 'r1' },
      include: { provider: true },
    });
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
  const req = { user: { sub: 'user-1', role: 'PROVIDER' as const } };

  it('submit resolves the provider from the signed-in user', async () => {
    const { controller, bids, prisma } = build();

    await controller.submit(req, 'r1', { minPrice: 1, maxPrice: 2 });

    expect(prisma.provider.findUniqueOrThrow).toHaveBeenCalledWith({ where: { userId: 'user-1' } });
    expect(bids.submitInitialBid).toHaveBeenCalledWith('r1', 'prov-1', { minPrice: 1, maxPrice: 2 });
  });

  it('delegates list, unlock, refine and confirm', async () => {
    const { controller, bids } = build();

    expect(await controller.list('r1')).toBe('listed');
    expect(await controller.unlock('b1')).toBe('unlocked');
    expect(await controller.refine('b1', { minPrice: 1, maxPrice: 2 })).toBe('refined');
    expect(await controller.confirm('b1')).toBe('confirmed');
    expect(bids.listForRequirement).toHaveBeenCalledWith('r1');
    expect(bids.confirmBid).toHaveBeenCalledWith('b1');
  });
});
