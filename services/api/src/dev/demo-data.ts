import { PrismaClient } from '@prisma/client';

// Demo data for local development: two categories with their sub-services, one
// customer and two active providers, plus one open request so the electrician
// has something under Incoming requests. Run with `npm run db:seed` (see
// README). Safe to re-run: everything is upserted or looked up first, and
// existing demo accounts only get their password reset.
//
// DEVELOPMENT ONLY. The password below is public and the providers skip
// verification, so this must never run against a real database.
export const DEMO_PASSWORD = '123456';

export const DEMO_CATALOG: Record<string, { description: string; subs: [string, number, number][] }> = {
  Electrician: {
    description: 'Wiring, switchboards, fans and lighting',
    subs: [
      ['Switchboard Repair', 200, 500],
      ['House Wiring', 1500, 5000],
      ['Fan Installation', 250, 450],
      ['Light Fitting', 150, 400],
    ],
  },
  Plumber: {
    description: 'Taps, leaks, pipes and bathroom fittings',
    subs: [
      ['Tap Installation', 200, 400],
      ['Leak Repair', 300, 800],
      ['Pipe Replacement', 800, 2500],
      ['Bathroom Fitting', 1000, 4000],
    ],
  },
};

export const DEMO_CUSTOMER = {
  fullName: 'Meera Nair',
  mobile: '9000000001',
  email: 'meera@example.test',
  city: 'Kochi',
  // Edappally, so the providers' incoming requests show a distance.
  latitude: 10.0261,
  longitude: 76.3125,
};

export const DEMO_PROVIDERS = [
  { mobile: '9000000002', name: 'Rajesh Electricals', category: 'Electrician', years: 8, email: 'rajesh@example.test', latitude: 9.9667, longitude: 76.2999 },
  { mobile: '9000000003', name: 'Kochi Plumbing Co', category: 'Plumber', years: 5, email: 'kochiplumbing@example.test', latitude: 10.0159, longitude: 76.3419 },
];

export function assertNotProduction(env: { NODE_ENV?: string }) {
  if (env.NODE_ENV === 'production') {
    throw new Error('Refusing to seed demo data with NODE_ENV=production');
  }
}

type Db = Pick<PrismaClient, 'category' | 'subService' | 'user' | 'provider' | 'requirement'>;

export async function seedDemoData(db: Db, hashPassword: (plain: string) => Promise<string>) {
  const passwordHash = await hashPassword(DEMO_PASSWORD);
  const subsByCategory: Record<string, { id: string }[]> = {};

  for (const [name, { description, subs }] of Object.entries(DEMO_CATALOG)) {
    const category = await db.category.upsert({ where: { name }, update: {}, create: { name, description } });
    subsByCategory[name] = [];
    for (const [subName, min, max] of subs) {
      const existing = await db.subService.findFirst({ where: { categoryId: category.id, name: subName } });
      const sub =
        existing ??
        (await db.subService.create({
          data: { categoryId: category.id, name: subName, suggestedMinPrice: min, suggestedMaxPrice: max },
        }));
      subsByCategory[name].push(sub);
    }
  }

  const customer = await db.user.upsert({
    where: { mobile: DEMO_CUSTOMER.mobile },
    update: { passwordHash, latitude: DEMO_CUSTOMER.latitude, longitude: DEMO_CUSTOMER.longitude },
    create: { ...DEMO_CUSTOMER, role: 'CUSTOMER', mobileVerifiedAt: new Date(), passwordHash },
  });

  const providerIds: Record<string, string> = {};
  for (const p of DEMO_PROVIDERS) {
    const user = await db.user.upsert({
      where: { mobile: p.mobile },
      update: { passwordHash, latitude: p.latitude, longitude: p.longitude },
      create: {
        role: 'PROVIDER',
        fullName: p.name,
        mobile: p.mobile,
        mobileVerifiedAt: new Date(),
        email: p.email,
        passwordHash,
        city: 'Kochi',
        latitude: p.latitude,
        longitude: p.longitude,
        provider: {
          create: {
            businessName: p.name,
            yearsExperience: p.years,
            coverageRadiusKm: 10,
            idProofUrl: 'demo://id-proof',
            status: 'ACTIVE',
            online: true,
            subServices: { create: subsByCategory[p.category].map((s) => ({ subServiceId: s.id })) },
            subscription: { create: { plan: 'PER_SERVICE' } },
          },
        },
      },
    });
    // Demo providers skip verification, including ones created before a reseed.
    const provider = await db.provider.update({ where: { userId: user.id }, data: { status: 'ACTIVE' } });
    providerIds[p.category] = provider.id;
  }

  const hasRequest = await db.requirement.findFirst({ where: { customerId: customer.id } });
  if (!hasRequest) {
    await db.requirement.create({
      data: {
        customerId: customer.id,
        subServiceId: subsByCategory.Electrician[0].id,
        description: 'Kitchen switchboard sparks when the mixer is plugged in. Need it checked and fixed.',
        photoUrls: [],
        targetedProviders: { create: [{ providerId: providerIds.Electrician }] },
      },
    });
  }

  return {
    categories: Object.keys(DEMO_CATALOG).length,
    subServices: Object.values(subsByCategory).reduce((n, list) => n + list.length, 0),
    providers: DEMO_PROVIDERS.length,
    requestCreated: !hasRequest,
  };
}
