import { RequirementsService } from './requirements.service';

describe('RequirementsService.listForProvider', () => {
  it('filters the included bids to this provider only', async () => {
    const findMany = jest.fn().mockResolvedValue([]);
    const prisma = { requirement: { findMany } } as any;
    const service = new RequirementsService(prisma);

    await service.listForProvider('provider-1');

    expect(findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        include: { subService: true, bids: { where: { providerId: 'provider-1' } } },
      }),
    );
  });

  it('scopes the query to requirements targeted at this provider', async () => {
    const findMany = jest.fn().mockResolvedValue([]);
    const prisma = { requirement: { findMany } } as any;
    const service = new RequirementsService(prisma);

    await service.listForProvider('provider-1');

    expect(findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { targetedProviders: { some: { providerId: 'provider-1' } } },
      }),
    );
  });
});
