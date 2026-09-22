import { RatingsService } from './ratings.service';

describe('RatingsService.forRequirement', () => {
  it('looks the rating up by its unique requirementId', async () => {
    const findUnique = jest.fn().mockResolvedValue({ id: 'rating-1', stars: 5 });
    const prisma = { ratingFeedback: { findUnique } } as any;
    const service = new RatingsService(prisma);

    const result = await service.forRequirement('req-1');

    expect(findUnique).toHaveBeenCalledWith({ where: { requirementId: 'req-1' } });
    expect(result).toEqual({ id: 'rating-1', stars: 5 });
  });

  it('returns null when the job has not been rated yet', async () => {
    const findUnique = jest.fn().mockResolvedValue(null);
    const prisma = { ratingFeedback: { findUnique } } as any;
    const service = new RatingsService(prisma);

    expect(await service.forRequirement('req-2')).toBeNull();
  });
});
