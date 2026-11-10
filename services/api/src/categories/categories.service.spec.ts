import { CategoriesService } from './categories.service';
import { PrismaService } from '../prisma/prisma.service';

describe('CategoriesService.listActive', () => {
  function setup(offered: { providerId: string; categoryId: string }[]) {
    const categoryFindMany = jest.fn().mockResolvedValue([
      { id: 'cat-e', name: 'Electrician', active: true },
      { id: 'cat-p', name: 'Plumber', active: true },
      { id: 'cat-x', name: 'Painter', active: true },
    ]);
    const offeredFindMany = jest.fn().mockResolvedValue(
      offered.map((o) => ({ providerId: o.providerId, subService: { categoryId: o.categoryId } })),
    );
    const service = new CategoriesService({
      category: { findMany: categoryFindMany },
      providerSubService: { findMany: offeredFindMany },
    } as unknown as PrismaService);
    return { service, categoryFindMany, offeredFindMany };
  }

  it('counts each active provider once per category', async () => {
    const { service } = setup([
      { providerId: 'p1', categoryId: 'cat-e' },
      { providerId: 'p1', categoryId: 'cat-e' }, // a second service, same category
      { providerId: 'p2', categoryId: 'cat-e' },
      { providerId: 'p1', categoryId: 'cat-p' },
    ]);

    const result = await service.listActive();

    expect(result.map((c) => [c.name, c.providerCount])).toEqual([
      ['Electrician', 2],
      ['Plumber', 1],
      ['Painter', 0],
    ]);
  });

  it('lists only active categories by name, and counts only ACTIVE providers', async () => {
    const { service, categoryFindMany, offeredFindMany } = setup([]);

    await service.listActive();

    expect(categoryFindMany.mock.calls[0][0]).toEqual({
      where: { active: true },
      orderBy: { name: 'asc' },
    });
    expect(offeredFindMany.mock.calls[0][0].where).toEqual({ provider: { status: 'ACTIVE' } });
  });
});
