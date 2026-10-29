import { BadRequestException, ForbiddenException } from '@nestjs/common';
import { RequirementsController } from './requirements.controller';
import { RequirementsService } from './requirements.service';
import { PrismaService } from '../prisma/prisma.service';
import { NotificationsService } from '../notifications/notifications.service';

function buildService(
  link: object | null = { requirementId: 'r1', providerId: 'p1' },
  requirement: object = { status: 'CONFIRMED', confirmedBidId: 'b1' },
  bid: object = { id: 'b1', providerId: 'p1' },
) {
  const prisma = {
    requirement: {
      create: jest.fn().mockResolvedValue({ id: 'r1' }),
      findMany: jest.fn().mockResolvedValue([]),
      update: jest.fn().mockResolvedValue({ id: 'r1', status: 'COMPLETED' }),
      findUniqueOrThrow: jest.fn().mockResolvedValue(requirement),
    },
    bid: { findUniqueOrThrow: jest.fn().mockResolvedValue(bid) },
    requirementProvider: {
      findUnique: jest.fn().mockResolvedValue(link),
      update: jest.fn().mockResolvedValue({}),
    },
  };
  const notifications = {
    requestSent: jest.fn().mockResolvedValue(undefined),
    requestAccepted: jest.fn().mockResolvedValue(undefined),
    jobCompleted: jest.fn().mockResolvedValue(undefined),
  };
  return {
    service: new RequirementsService(
      prisma as unknown as PrismaService,
      notifications as unknown as NotificationsService,
    ),
    prisma,
    notifications,
  };
}

describe('RequirementsService notifications', () => {
  const dto = { subServiceId: 's1', description: 'Fix fan', providerIds: ['p1', 'p2'] };

  it('tells the targeted providers about a new request', async () => {
    const { service, notifications } = buildService();
    await service.postRequirement('cust-1', dto);
    expect(notifications.requestSent).toHaveBeenCalledWith('r1');
  });

  it('tells the customer when a provider accepts, but not when one rejects', async () => {
    const { service, notifications } = buildService();
    await service.respond('r1', 'p1', true);
    expect(notifications.requestAccepted).toHaveBeenCalledWith('r1', 'p1');

    notifications.requestAccepted.mockClear();
    await service.respond('r1', 'p1', false);
    expect(notifications.requestAccepted).not.toHaveBeenCalled();
  });

  it('tells the customer when the job is completed', async () => {
    const { service, notifications } = buildService();
    await service.markCompleted('r1', 'p1');
    expect(notifications.jobCompleted).toHaveBeenCalledWith('r1');
  });

  it('sends nothing when completing is refused', async () => {
    const { service, notifications } = buildService(undefined, { status: 'CONFIRMED', confirmedBidId: 'b1' }, { id: 'b1', providerId: 'someone-else' });
    await expect(service.markCompleted('r1', 'p1')).rejects.toBeInstanceOf(ForbiddenException);
    expect(notifications.jobCompleted).not.toHaveBeenCalled();
  });
});

describe('RequirementsService.postRequirement', () => {
  it('creates the request as SENT and targets each chosen provider', async () => {
    const { service, prisma } = buildService();

    await service.postRequirement('cust-1', {
      subServiceId: 's1',
      description: 'Fix a fan',
      providerIds: ['p1', 'p2'],
    });

    const data = prisma.requirement.create.mock.calls[0][0].data;
    expect(data.customerId).toBe('cust-1');
    expect(data.status).toBe('SENT');
    expect(data.photoUrls).toEqual([]);
    expect(data.preferredAt).toBeUndefined();
    expect(data.targetedProviders.create).toEqual([{ providerId: 'p1' }, { providerId: 'p2' }]);
  });

  it('keeps photos and parses the preferred date', async () => {
    const { service, prisma } = buildService();

    await service.postRequirement('cust-1', {
      subServiceId: 's1',
      description: 'Fix a fan',
      photoUrls: ['a.png'],
      preferredAt: '2026-11-01T10:00:00.000Z',
      providerIds: ['p1'],
    });

    const data = prisma.requirement.create.mock.calls[0][0].data;
    expect(data.photoUrls).toEqual(['a.png']);
    expect(data.preferredAt).toEqual(new Date('2026-11-01T10:00:00.000Z'));
  });
});

describe('RequirementsService.listForCustomer', () => {
  it("lists only the customer's requests, newest first, with bids", async () => {
    const { service, prisma } = buildService();

    await service.listForCustomer('cust-1');

    expect(prisma.requirement.findMany).toHaveBeenCalledWith({
      where: { customerId: 'cust-1' },
      include: { targetedProviders: true, bids: true },
      orderBy: { createdAt: 'desc' },
    });
  });
});

describe('RequirementsService.respond', () => {
  it('rejects a provider the request was not sent to', async () => {
    const { service, prisma } = buildService(null);

    await expect(service.respond('r1', 'p9', true)).rejects.toBeInstanceOf(BadRequestException);
    expect(prisma.requirementProvider.update).not.toHaveBeenCalled();
  });

  it('accepting updates the link and the requirement', async () => {
    const { service, prisma } = buildService();

    const result = await service.respond('r1', 'p1', true);

    expect(prisma.requirementProvider.update).toHaveBeenCalledWith(
      expect.objectContaining({ data: { status: 'ACCEPTED' } }),
    );
    expect(prisma.requirement.update).toHaveBeenCalledWith({
      where: { id: 'r1' },
      data: { status: 'ACCEPTED' },
    });
    expect(result).toEqual({ requirementId: 'r1', providerId: 'p1', status: 'ACCEPTED' });
  });

  it('rejecting updates only the link', async () => {
    const { service, prisma } = buildService();

    const result = await service.respond('r1', 'p1', false);

    expect(prisma.requirementProvider.update).toHaveBeenCalledWith(
      expect.objectContaining({ data: { status: 'REJECTED' } }),
    );
    expect(prisma.requirement.update).not.toHaveBeenCalled();
    expect(result.status).toBe('REJECTED');
  });
});

describe('RequirementsService.markCompleted', () => {
  it('sets the status to COMPLETED for the confirmed provider', async () => {
    const { service, prisma } = buildService();

    await service.markCompleted('r1', 'p1');

    expect(prisma.requirement.update).toHaveBeenCalledWith({
      where: { id: 'r1' },
      data: { status: 'COMPLETED' },
    });
  });

  it('refuses a provider who was not confirmed for the job', async () => {
    const { service, prisma } = buildService();

    await expect(service.markCompleted('r1', 'p2')).rejects.toBeInstanceOf(ForbiddenException);
    expect(prisma.requirement.update).not.toHaveBeenCalled();
  });

  it('refuses a request nobody has been confirmed for', async () => {
    const { service, prisma } = buildService(undefined, { status: 'BID_RECEIVED', confirmedBidId: null });

    await expect(service.markCompleted('r1', 'p1')).rejects.toBeInstanceOf(BadRequestException);
    expect(prisma.requirement.update).not.toHaveBeenCalled();
  });

  it('refuses a job that is already completed', async () => {
    const { service, prisma } = buildService(undefined, { status: 'COMPLETED', confirmedBidId: 'b1' });

    await expect(service.markCompleted('r1', 'p1')).rejects.toBeInstanceOf(BadRequestException);
    expect(prisma.requirement.update).not.toHaveBeenCalled();
  });
});

describe('RequirementsController', () => {
  function build() {
    const requirements = {
      postRequirement: jest.fn().mockResolvedValue('posted'),
      listForCustomer: jest.fn().mockResolvedValue('mine'),
      listForProvider: jest.fn().mockResolvedValue('incoming'),
      respond: jest.fn().mockResolvedValue('responded'),
      markCompleted: jest.fn().mockResolvedValue('completed'),
    };
    const prisma = { provider: { findUniqueOrThrow: jest.fn().mockResolvedValue({ id: 'prov-1' }) } };
    const controller = new RequirementsController(
      requirements as unknown as RequirementsService,
      prisma as unknown as PrismaService,
    );
    return { controller, requirements };
  }
  const req = { user: { sub: 'user-1', role: 'CUSTOMER' as const } };

  it('post and mine use the signed-in customer id', async () => {
    const { controller, requirements } = build();
    const dto = { subServiceId: 's', description: 'd', providerIds: ['p'] };

    expect(await controller.post(req, dto)).toBe('posted');
    expect(await controller.mine(req)).toBe('mine');
    expect(requirements.postRequirement).toHaveBeenCalledWith('user-1', dto);
    expect(requirements.listForCustomer).toHaveBeenCalledWith('user-1');
  });

  it('incoming, accept and reject resolve the provider id first', async () => {
    const { controller, requirements } = build();

    expect(await controller.incoming(req)).toBe('incoming');
    await controller.accept(req, 'r1');
    await controller.reject(req, 'r1');

    expect(requirements.listForProvider).toHaveBeenCalledWith('prov-1');
    expect(requirements.respond).toHaveBeenNthCalledWith(1, 'r1', 'prov-1', true);
    expect(requirements.respond).toHaveBeenNthCalledWith(2, 'r1', 'prov-1', false);
  });

  it('complete delegates', async () => {
    const { controller, requirements } = build();
    expect(await controller.complete(req, 'r1')).toBe('completed');
    expect(requirements.markCompleted).toHaveBeenCalledWith('r1', 'prov-1');
  });
});
