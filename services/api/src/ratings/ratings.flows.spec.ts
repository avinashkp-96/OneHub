import { BadRequestException, ConflictException, ForbiddenException } from '@nestjs/common';
import { RatingsController } from './ratings.controller';
import { RatingsService, shortName } from './ratings.service';
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

describe('RatingsService.mine (Ratings received, docx 5.9)', () => {
  function withRatings(rows: { stars: number; fullName: string; feedback?: string | null }[]) {
    const prisma = {
      provider: { findUniqueOrThrow: jest.fn().mockResolvedValue({ id: 'p1' }) },
      ratingFeedback: {
        findMany: jest.fn().mockResolvedValue(
          rows.map((r, i) => ({
            id: `r${i}`,
            stars: r.stars,
            feedback: r.feedback ?? null,
            createdAt: new Date(2026, 9, 29 - i),
            customer: { fullName: r.fullName },
          })),
        ),
      },
    };
    const service = new RatingsService(prisma as unknown as PrismaService, {} as NotificationsService);
    return { service, prisma };
  }

  it("looks up the caller's own provider and their ratings, newest first", async () => {
    const { service, prisma } = withRatings([]);

    await service.mine('u-p1');

    expect(prisma.provider.findUniqueOrThrow.mock.calls[0][0].where).toEqual({ userId: 'u-p1' });
    const args = prisma.ratingFeedback.findMany.mock.calls[0][0];
    expect(args.where).toEqual({ providerId: 'p1' });
    expect(args.orderBy).toEqual({ createdAt: 'desc' });
  });

  it('summarises average, count and the 5-1 star distribution', async () => {
    const { service } = withRatings([
      { stars: 5, fullName: 'Meera Nair', feedback: 'Quick and tidy' },
      { stars: 5, fullName: 'Arun Kumar' },
      { stars: 4, fullName: 'Divya' },
      { stars: 2, fullName: 'Joseph Mathew Varghese' },
    ]);

    const result = await service.mine('u-p1');

    expect(result.averageRating).toBe(4);
    expect(result.ratingCount).toBe(4);
    expect(result.distribution).toEqual({ 5: 2, 4: 1, 3: 0, 2: 1, 1: 0 });
    expect(result.reviews.map((r) => r.customerName)).toEqual(['Meera N.', 'Arun K.', 'Divya', 'Joseph V.']);
    expect(result.reviews[0]).toEqual(
      expect.objectContaining({ id: 'r0', stars: 5, feedback: 'Quick and tidy' }),
    );
  });

  it('rounds the average to one decimal', async () => {
    const { service } = withRatings([
      { stars: 5, fullName: 'A' },
      { stars: 4, fullName: 'B' },
      { stars: 4, fullName: 'C' },
    ]);
    expect((await service.mine('u-p1')).averageRating).toBe(4.3);
  });

  it('reports zeros when there are no ratings yet', async () => {
    const { service } = withRatings([]);
    expect(await service.mine('u-p1')).toEqual({
      averageRating: 0,
      ratingCount: 0,
      distribution: { 5: 0, 4: 0, 3: 0, 2: 0, 1: 0 },
      reviews: [],
    });
  });

  it('never exposes customer ids', async () => {
    const { service, prisma } = withRatings([{ stars: 5, fullName: 'Meera Nair' }]);

    const result = await service.mine('u-p1');

    expect(prisma.ratingFeedback.findMany.mock.calls[0][0].select).not.toHaveProperty('customerId');
    expect(result.reviews[0]).not.toHaveProperty('customerId');
  });
});

describe('shortName', () => {
  it.each([
    ['Meera Nair', 'Meera N.'],
    ['  meera   nair  ', 'meera N.'],
    ['Divya', 'Divya'],
    ['Joseph Mathew Varghese', 'Joseph V.'],
  ])('%s -> %s', (full, short) => {
    expect(shortName(full)).toBe(short);
  });
});

describe('RatingsController', () => {
  it('mine uses the signed-in provider', async () => {
    const ratings = { mine: jest.fn().mockResolvedValue('summary') };
    const controller = new RatingsController(ratings as unknown as RatingsService);

    expect(await controller.mine({ user: { sub: 'u-p1', role: 'PROVIDER' } })).toBe('summary');
    expect(ratings.mine).toHaveBeenCalledWith('u-p1');
  });

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
