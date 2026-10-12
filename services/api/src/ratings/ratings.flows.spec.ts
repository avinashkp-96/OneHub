import { RatingsController } from './ratings.controller';
import { RatingsService } from './ratings.service';
import { PrismaService } from '../prisma/prisma.service';

function build(provider: { ratingCount: number; averageRating: number }, completed = 0) {
  const prisma = {
    ratingFeedback: {
      create: jest.fn().mockResolvedValue({ id: 'rating-1' }),
      findMany: jest.fn().mockResolvedValue([]),
    },
    provider: {
      findUniqueOrThrow: jest.fn().mockResolvedValue(provider),
      update: jest.fn().mockResolvedValue({}),
    },
    requirement: { count: jest.fn().mockResolvedValue(completed) },
  };
  return { service: new RatingsService(prisma as unknown as PrismaService), prisma };
}

const dto = { requirementId: 'r1', providerId: 'p1', stars: 5, feedback: 'Great' };

describe('RatingsService.submitRating', () => {
  it('stores the rating against the customer', async () => {
    const { service, prisma } = build({ ratingCount: 0, averageRating: 0 });

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
    const { service, prisma } = build({ ratingCount: 3, averageRating: 4 });

    await service.submitRating('cust-1', { ...dto, stars: 2 });

    const data = prisma.provider.update.mock.calls[0][0].data;
    expect(data.ratingCount).toBe(4);
    expect(data.averageRating).toBeCloseTo(3.5);
  });

  it('certifies a provider who meets both thresholds', async () => {
    const { service, prisma } = build({ ratingCount: 9, averageRating: 4.6 }, 10);

    await service.submitRating('cust-1', { ...dto, stars: 5 });

    expect(prisma.provider.update.mock.calls[0][0].data.certified).toBe(true);
  });

  it('does not certify with too few completed jobs', async () => {
    const { service, prisma } = build({ ratingCount: 9, averageRating: 4.9 }, 9);

    await service.submitRating('cust-1', dto);

    expect(prisma.provider.update.mock.calls[0][0].data.certified).toBe(false);
  });

  it('does not certify when the average is below the threshold', async () => {
    const { service, prisma } = build({ ratingCount: 9, averageRating: 3 }, 10);

    await service.submitRating('cust-1', { ...dto, stars: 3 });

    expect(prisma.provider.update.mock.calls[0][0].data.certified).toBe(false);
  });
});

describe('RatingsService.overview', () => {
  it("lists a provider's ratings newest first", async () => {
    const { service, prisma } = build({ ratingCount: 0, averageRating: 0 });

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
