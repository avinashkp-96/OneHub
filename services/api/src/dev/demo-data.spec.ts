import { PrismaClient } from '@prisma/client';
import {
  assertNotProduction,
  DEMO_CATALOG,
  DEMO_CUSTOMER,
  DEMO_PASSWORD,
  DEMO_PROVIDERS,
  seedDemoData,
} from './demo-data';

type RequestData = { customerId: string; targetedProviders: { create: { providerId: string }[] } };

function fakeDb(opts: { existingSubs?: boolean; existingRequest?: boolean } = {}) {
  let n = 0;
  const db = {
    category: { upsert: jest.fn(async ({ where }) => ({ id: `cat-${where.name}` })) },
    subService: {
      findFirst: jest.fn(async ({ where }) => (opts.existingSubs ? { id: `old-${where.name}` } : null)),
      create: jest.fn(async ({ data }) => ({ id: `sub-${data.name}-${n++}` })),
    },
    user: { upsert: jest.fn(async ({ where }) => ({ id: `user-${where.mobile}` })) },
    provider: { update: jest.fn(async ({ where }) => ({ id: `prov-${where.userId}` })) },
    requirement: {
      findFirst: jest.fn(async () => (opts.existingRequest ? { id: 'r1' } : null)),
      create: jest.fn<Promise<{ id: string }>, [{ data: RequestData }]>(async () => ({ id: 'r-new' })),
    },
  };
  return { db, client: db as unknown as PrismaClient };
}

const hash = jest.fn(async (plain: string) => `hashed:${plain}`);

describe('assertNotProduction', () => {
  it('refuses to run in production', () => {
    expect(() => assertNotProduction({ NODE_ENV: 'production' })).toThrow('production');
  });

  it('allows development and unset environments', () => {
    expect(() => assertNotProduction({ NODE_ENV: 'development' })).not.toThrow();
    expect(() => assertNotProduction({})).not.toThrow();
  });
});

describe('seedDemoData', () => {
  it('creates both categories and all their sub-services on an empty database', async () => {
    const { db, client } = fakeDb();

    const result = await seedDemoData(client, hash);

    expect(db.category.upsert).toHaveBeenCalledTimes(2);
    expect(db.subService.create).toHaveBeenCalledTimes(8);
    expect(result).toEqual({ categories: 2, subServices: 8, providers: 2, requestCreated: true });
  });

  it('reuses existing sub-services instead of duplicating them', async () => {
    const { db, client } = fakeDb({ existingSubs: true, existingRequest: true });

    const result = await seedDemoData(client, hash);

    expect(db.subService.create).not.toHaveBeenCalled();
    expect(db.requirement.create).not.toHaveBeenCalled();
    expect(result.requestCreated).toBe(false);
  });

  it('hashes the demo password once and uses it for every account, including on reseed', async () => {
    const { db, client } = fakeDb();
    hash.mockClear();

    await seedDemoData(client, hash);

    expect(hash).toHaveBeenCalledTimes(1);
    expect(hash).toHaveBeenCalledWith(DEMO_PASSWORD);
    for (const call of db.user.upsert.mock.calls) {
      expect(call[0].update).toEqual(expect.objectContaining({ passwordHash: `hashed:${DEMO_PASSWORD}` }));
      expect(call[0].update.latitude).toBe(call[0].create.latitude);
      expect(call[0].update.longitude).toBe(call[0].create.longitude);
      expect(call[0].create.latitude).toEqual(expect.any(Number));
      expect(call[0].create.passwordHash).toBe(`hashed:${DEMO_PASSWORD}`);
    }
  });

  it('creates the customer, and active providers offering their own category', async () => {
    const { db, client } = fakeDb();

    await seedDemoData(client, hash);

    const [customerCall, ...providerCalls] = db.user.upsert.mock.calls.map((c) => c[0]);
    expect(customerCall.where).toEqual({ mobile: DEMO_CUSTOMER.mobile });
    expect(customerCall.create.role).toBe('CUSTOMER');

    expect(providerCalls.map((c) => c.where.mobile)).toEqual(DEMO_PROVIDERS.map((p) => p.mobile));
    for (const call of providerCalls) {
      const provider = call.create.provider.create;
      expect(call.create.role).toBe('PROVIDER');
      expect(provider.status).toBe('ACTIVE');
      expect(provider.subServices.create).toHaveLength(4);
    }
    const plumberSubs = providerCalls[1].create.provider.create.subServices.create.map(
      (s: { subServiceId: string }) => s.subServiceId,
    );
    const plumberNames = DEMO_CATALOG.Plumber.subs.map(([name]) => name);
    expect(plumberSubs.every((id: string) => plumberNames.some((name) => id.includes(name)))).toBe(true);

    expect(db.provider.update).toHaveBeenCalledTimes(2);
    for (const call of db.provider.update.mock.calls) {
      expect(call[0].data).toEqual({ status: 'ACTIVE' });
    }
  });

  it('sends the demo request to the electrician only', async () => {
    const { db, client } = fakeDb();

    await seedDemoData(client, hash);

    const data = db.requirement.create.mock.calls[0][0].data;
    expect(data.customerId).toBe(`user-${DEMO_CUSTOMER.mobile}`);
    expect(data.targetedProviders.create).toEqual([{ providerId: `prov-user-${DEMO_PROVIDERS[0].mobile}` }]);
  });
});
