import { PrismaService } from '../prisma/prisma.service';
import { SearchController } from './search.controller';
import { SearchService } from './search.service';

const elec = { id: 'c1', name: 'Electrician', active: true };
const plumb = { id: 'c2', name: 'Plumber', active: true };
const hidden = { id: 'c3', name: 'Painter', active: false };

const svc = (id: string, name: string, category: typeof elec, min: number | null, max: number | null = null) => ({
  id,
  name,
  suggestedMinPrice: min,
  suggestedMaxPrice: max,
  category,
});

const switchboard = svc('s1', 'Switchboard Repair', elec, 200, 500);
const fan = svc('s2', 'Fan Installation', elec, 250, 450);
const wiring = svc('s3', 'House Wiring', elec, 1500, 5000);
const tap = svc('s4', 'Tap Installation', plumb, 200, 400);
const leak = svc('s5', 'Leak Repair', plumb, 300, 800);
const wall = svc('s6', 'Wall Painting', hidden, 100);
const unpriced = svc('s7', 'Inspection', elec, null);

const provider = (
  id: string,
  businessName: string | null,
  fullName: string,
  rating: number,
  count: number,
  services: ReturnType<typeof svc>[],
) => ({
  id,
  businessName,
  yearsExperience: 5,
  averageRating: rating,
  ratingCount: count,
  certified: false,
  user: { fullName },
  subServices: services.map((subService) => ({ subService })),
});

function build() {
  const allProviders = [
    provider('p1', 'Rajesh Electricals', 'Rajesh K', 4.6, 12, [switchboard, fan, wiring, wall]),
    provider('p2', 'Kochi Plumbing Co', 'Anil T', 4.1, 5, [tap, leak]),
    provider('p3', null, 'Volt Masters Sharma', 4.8, 3, [wiring, unpriced]),
  ];
  const prisma = {
    subService: {
      findMany: jest.fn(async (args?: { where?: unknown }) =>
        args?.where ? [switchboard, fan, wiring, tap, leak, unpriced] : [switchboard, fan, wiring, tap, leak, wall, unpriced],
      ),
    },
    category: { findMany: jest.fn().mockResolvedValue([elec, plumb]) },
    provider: {
      findMany: jest.fn(async ({ where }) => allProviders.filter((p) => p.averageRating >= where.averageRating.gte)),
    },
  };
  return { service: new SearchService(prisma as unknown as PrismaService), prisma };
}

describe('SearchService.search (docx 4.2)', () => {
  it('only considers active providers, and passes the minimum rating to the query', async () => {
    const { service, prisma } = build();

    await service.search({ minRating: 4.5 });

    expect(prisma.provider.findMany.mock.calls[0][0].where).toEqual({ status: 'ACTIVE', averageRating: { gte: 4.5 } });
    const { select } = prisma.provider.findMany.mock.calls[0][0];
    expect(select).not.toHaveProperty('idProofUrl');
    expect(select).not.toHaveProperty('bankOrUpiDetails');
  });

  it('matches services by service or category name, never from inactive categories', async () => {
    const { service } = build();

    const byService = await service.search({ q: 'repair' });
    expect(byService.services.map((s) => s.name)).toEqual(['Leak Repair', 'Switchboard Repair']);

    const byCategory = await service.search({ q: 'plumber' });
    expect(byCategory.services.map((s) => s.name)).toEqual(['Leak Repair', 'Tap Installation']);

    const inactive = await service.search({ q: 'painting' });
    expect(inactive.services).toEqual([]);
    expect(inactive.providers).toEqual([]);
  });

  it('needs every typed word to match, in any order and case', async () => {
    const { service } = build();
    const result = await service.search({ q: 'INSTALLATION fan' });
    expect(result.services.map((s) => s.name)).toEqual(['Fan Installation']);
  });

  it('finds providers by the services they offer, with only the matching services and their starting price', async () => {
    const { service } = build();

    const result = await service.search({ q: 'wiring' });

    expect(result.providers.map((p) => p.name)).toEqual(['Volt Masters Sharma', 'Rajesh Electricals']);
    expect(result.providers[1]).toEqual(
      expect.objectContaining({
        id: 'p1',
        categories: ['Electrician'],
        services: [{ id: 's3', name: 'House Wiring' }],
        startingPrice: 1500,
      }),
    );
  });

  it('finds a provider by name and then keeps all of their services', async () => {
    const { service } = build();

    const result = await service.search({ q: 'rajesh' });

    expect(result.providers).toHaveLength(1);
    expect(result.providers[0].services.map((s) => s.name)).toEqual([
      'Switchboard Repair',
      'Fan Installation',
      'House Wiring',
    ]);
    expect(result.providers[0].startingPrice).toBe(200);
  });

  it('uses the person’s name when a provider has no business name', async () => {
    const { service } = build();
    const result = await service.search({ q: 'sharma' });
    expect(result.providers.map((p) => p.name)).toEqual(['Volt Masters Sharma']);
  });

  it('lists everyone with an empty keyword, best rated first', async () => {
    const { service } = build();
    const result = await service.search({});
    expect(result.providers.map((p) => p.id)).toEqual(['p3', 'p1', 'p2']);
  });

  it('filters by category', async () => {
    const { service } = build();

    const result = await service.search({ categoryId: 'c2' });

    expect(result.providers.map((p) => p.id)).toEqual(['p2']);
    expect(result.services.every((s) => s.categoryName === 'Plumber')).toBe(true);
  });

  it('filters by maximum starting price', async () => {
    const { service } = build();

    const result = await service.search({ maxPrice: 250 });

    expect(result.providers.map((p) => p.id)).toEqual(['p1', 'p2']);
    expect(result.services.map((s) => s.name)).not.toContain('Leak Repair');
    expect(result.services.map((s) => s.name)).toContain('Inspection');
  });

  it('a provider with no priced services is dropped by a price filter', async () => {
    const { service } = build();
    const result = await service.search({ q: 'inspection', maxPrice: 1000 });
    expect(result.providers).toEqual([]);
  });

  it('sorts by lowest starting price when asked, rating breaking ties', async () => {
    const { service } = build();

    const result = await service.search({ sort: 'price' });

    expect(result.providers.map((p) => [p.id, p.startingPrice])).toEqual([
      ['p1', 200],
      ['p2', 200],
      ['p3', 1500],
    ]);
    expect(result.services[0].suggestedMinPrice).toBe(200);
    expect(result.services.at(-1)?.name).toBe('Inspection');
  });

  it('puts unpriced providers last when sorting by price', async () => {
    const { service, prisma } = build();
    prisma.provider.findMany.mockResolvedValue([
      provider('p9', 'No Price Co', 'X', 5, 1, [unpriced]),
      provider('p2', 'Kochi Plumbing Co', 'Anil T', 4.1, 5, [tap]),
    ] as never);

    const result = await service.search({ sort: 'price' });

    expect(result.providers.map((p) => p.id)).toEqual(['p2', 'p9']);
  });

  it('breaks rating ties by number of ratings', async () => {
    const { service, prisma } = build();
    prisma.provider.findMany.mockResolvedValue([
      provider('few', 'Few', 'A', 4.5, 2, [tap]),
      provider('many', 'Many', 'B', 4.5, 20, [tap]),
    ] as never);

    const result = await service.search({});

    expect(result.providers.map((p) => p.id)).toEqual(['many', 'few']);
  });
});

describe('SearchService.suggest', () => {
  it('suggests categories, then services, that start a word with what was typed', async () => {
    const { service, prisma } = build();

    expect(await service.suggest('in')).toEqual(['Fan Installation', 'Tap Installation', 'Inspection']);
    expect(await service.suggest('pl')).toEqual(['Plumber']);
    expect(await service.suggest('rep')).toEqual(['Switchboard Repair', 'Leak Repair']);
    expect(prisma.category.findMany.mock.calls[0][0].where).toEqual({ active: true });
  });

  it('waits for two characters and caps the list at eight', async () => {
    const { service, prisma } = build();

    expect(await service.suggest('a')).toEqual([]);
    expect(await service.suggest(undefined)).toEqual([]);
    expect(prisma.category.findMany).not.toHaveBeenCalled();

    prisma.subService.findMany.mockResolvedValue(
      Array.from({ length: 12 }, (_, i) => svc(`x${i}`, `Repair ${i}`, elec, 1)) as never,
    );
    expect(await service.suggest('repair')).toHaveLength(8);
  });
});

describe('SearchController', () => {
  it('passes the query through', async () => {
    const search = { search: jest.fn().mockResolvedValue('results'), suggest: jest.fn().mockResolvedValue(['x']) };
    const controller = new SearchController(search as unknown as SearchService);

    expect(await controller.search({ q: 'fan', sort: 'price' })).toBe('results');
    expect(search.search).toHaveBeenCalledWith({ q: 'fan', sort: 'price' });
    expect(await controller.suggest('fa')).toEqual(['x']);
  });
});
