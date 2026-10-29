import { BadRequestException, ConflictException, ForbiddenException } from '@nestjs/common';
import { RatingsController } from './ratings.controller';
import { RatingsService } from './ratings.service';
import { PrismaService } from '../prisma/prisma.service';
import { NotificationsService } from '../notifications/notifications.service';

interface Setup {
  provider?: { ratingCount: number; averageRating: number; certified?: boolean };
  completed?: number;
  requirement?: object | null;
  bidProviderId?: string;
  alreadyRated?: boolean;
}

function build(o: Setup = {}) {
  const prisma = {
    ratingFeedback: {
      create: jest.fn().mockResolvedValue({ id: 'rating-1' }),
      findMany: jest.fn().mockResolvedValue([]),
      findUnique: jest.fn().mockResolvedValue(o.alreadyRated ? { id: 'old' } : null),
    },
    provider: {
      findUniqueOrThrow: jest.fn().mockResolvedValue(o.provider ?? { ratingCount: 0, averageRating: 0 }),
      update: jest.fn().mockResolvedValue({}),
    },
    requirement: {
      count: jest.fn().mockResolvedValue(o.completed ?? 0),
      findUnique: jest.fn().mockResolvedValue(
        o.requirement === undefined
          ? { customerId: 'cust-1', status: 'COMPLETED', confirmedBidId: 'b1' }
          : o.requirement,
      ),
    },
    bid: {
      findUniqueOrThrow: jest.fn().mockResolvedValue({ id: 'b1', providerId: o.bidProviderId ?? 'p1' }),
    },
  };
  const notifications = { ratingReceived: jest.fn().mockResolvedValue(undefined) };
  return {
    service: new RatingsService(prisma as unknown as PrismaService, notifications as unknown as NotificationsService),
    prisma,
    notifications,
  };
}

describe('RatingsService notifications', () => {
  const rate = { requirementId: 'r1', providerId: 'p1', stars: 4, feedback: 'Good' };

  it('tells the provider about the new rating', async () => {
    const { service, notifications } = build();
    await service.submitRating('cust-1', rate);
    expect(notifications.ratingReceived).toHaveBeenCalledWith('p1', 4, false);
  });

  it('also flags the certified badge when this rating earns it', async () => {
    const { service, notifications } = build({ provider: { ratingCount: 9, averageRating: 5 }, completed: 10 });
    await service.submitRating('cust-1', { ...rate, stars: 5 });
    expect(notifications.ratingReceived).toHaveBeenCalledWith('p1', 5, true);
  });

  it('does not flag the badge again for a provider already certified', async () => {
    const { service, notifications } = build({
      provider: { ratingCount: 9, averageRating: 5, certified: true },
      completed: 10,
    });
    await service.submitRating('cust-1', { ...rate, stars: 5 });
    expect(notifications.ratingReceived).toHaveBeenCalledWith('p1', 5, false);
  });

  it('sends nothing when the rating is refused', async () => {
    const { service, notifications } = build({ alreadyRated: true });
    await expect(service.submitRating('cust-1', rate)).rejects.toBeInstanceOf(ConflictException);
    expect(notifications.ratingReceived).not.toHaveBeenCalled();
  });
});

const dto = { requirementId: 'r1', providerId: 'p1', stars: 5, feedback: 'Great' };

describe('RatingsService.submitRating', () => {
  it('stores the rating against the customer', async () => {
    const { service, prisma } = build();

    const rating = await service.submitRating('cust-1', dto);

    expect(prisma.ratingFeedback.create).toHaveBeenCalledWith({
      data: {
        customerId: 'cust-1',
        providerId: 'p1',
        requirementId: 'r1',
        stars: 5,
        feedback: 'Great',
      },
    });
    expect(rating).toEqual({ id: 'rating-1' });
  });

  it('folds the new stars into the running average', async () => {
    const { service, prisma } = build({ provider: { ratingCount: 3, averageRating: 4 } });

    await service.submitRating('cust-1', { ...dto, stars: 2 });

    const data = prisma.provider.update.mock.calls[0][0].data;
    expect(data.ratingCount).toBe(4);
    expect(data.averageRating).toBeCloseTo(3.5);
  });

  it('certifies a provider who meets both thresholds', async () => {
    const { service, prisma } = build({ provider: { ratingCount: 9, averageRating: 4.6 }, completed: 10 });

    await service.submitRating('cust-1', { ...dto, stars: 5 });

    expect(prisma.provider.update.mock.calls[0][0].data.certified).toBe(true);
  });

  it('does not certify with too few completed jobs', async () => {
    const { service, prisma } = build({ provider: { ratingCount: 9, averageRating: 4.9 }, completed: 9 });

    await service.submitRating('cust-1', dto);

    expect(prisma.provider.update.mock.calls[0][0].data.certified).toBe(false);
  });

  it('does not certify when the average is below the threshold', async () => {
    const { service, prisma } = build({ provider: { ratingCount: 9, averageRating: 3 }, completed: 10 });

    await service.submitRating('cust-1', { ...dto, stars: 3 });

    expect(prisma.provider.update.mock.calls[0][0].data.certified).toBe(false);
  });

  it("refuses a customer who does not own the request", async () => {
    const { service, prisma } = build();

    await expect(service.submitRating('intruder', dto)).rejects.toBeInstanceOf(ForbiddenException);
    expect(prisma.ratingFeedback.create).not.toHaveBeenCalled();
  });

  it('refuses a request that does not exist', async () => {
    const { service } = build({ requirement: null });

    await expect(service.submitRating('cust-1', dto)).rejects.toBeInstanceOf(ForbiddenException);
  });

  it('refuses a job that is not completed', async () => {
    const { service, prisma } = build({
      requirement: { customerId: 'cust-1', status: 'CONFIRMED', confirmedBidId: 'b1' },
    });

    await expect(service.submitRating('cust-1', dto)).rejects.toBeInstanceOf(BadRequestException);
    expect(prisma.ratingFeedback.create).not.toHaveBeenCalled();
  });

  it('refuses to rate a provider who did not do the job', async () => {
    const { service, prisma } = build({ bidProviderId: 'someone-else' });

    await expect(service.submitRating('cust-1', dto)).rejects.toBeInstanceOf(BadRequestException);
    expect(prisma.ratingFeedback.create).not.toHaveBeenCalled();
    expect(prisma.provider.update).not.toHaveBeenCalled();
  });

  it('refuses a second rating for the same job', async () => {
    const { service, prisma } = build({ alreadyRated: true });

    await expect(service.submitRating('cust-1', dto)).rejects.toBeInstanceOf(ConflictException);
    expect(prisma.ratingFeedback.create).not.toHaveBeenCalled();
  });
});

describe('RatingsService.overview', () => {
  it("lists a provider's ratings newest first", async () => {
    const { service, prisma } = build();

    await service.overview('p1');

    expect(prisma.ratingFeedback.findMany).toHaveBeenCalledWith({
      where: { providerId: 'p1' },
      orderBy: { createdAt: 'desc' },
    });
  });
});

describe('RatingsController', () => {
  it('delegates submit, overview and forRequirement', async () => {
    const ratings = {
      submitRating: jest.fn().mockResolvedValue('submitted'),
      overview: jest.fn().mockResolvedValue('overview'),
      forRequirement: jest.fn().mockResolvedValue('one'),
    };
    const controller = new RatingsController(ratings as unknown as RatingsService);
    const req = { user: { sub: 'cust-1', role: 'CUSTOMER' as const } };

    expect(await controller.submit(req, dto)).toBe('submitted');
    expect(await controller.overview('p1')).toBe('overview');
    expect(await controller.forRequirement('r1')).toBe('one');
    expect(ratings.submitRating).toHaveBeenCalledWith('cust-1', dto);
  });
});
