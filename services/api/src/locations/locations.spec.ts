import { INestApplication, ValidationPipe } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { AppModule } from '../app.module';
import { AuthService } from '../auth/auth.service';
import { OtpService } from '../common/otp.service';
import { PrismaService } from '../prisma/prisma.service';
import { ProvidersService } from '../providers/providers.service';
import { ProvidersController } from '../providers/providers.controller';
import { SearchService } from '../search/search.service';
import { UsersService } from '../users/users.service';
import { placeName, SERVICE_AREAS, UNNAMED_PLACE } from './areas';
import { byDistance } from './geo';
import { LocationsController } from './locations.controller';

const asPrisma = (p: object) => p as unknown as PrismaService;
const EDAPPALLY = { latitude: 10.0261, longitude: 76.3125 };

describe('service areas', () => {
  it('names a position after the nearest area', () => {
    expect(placeName(10.027, 76.311)).toBe('Edappally');
    expect(placeName(9.967, 76.3)).toBe('Kadavanthra');
  });

  it('does not name a position far from every area', () => {
    // Thiruvananthapuram, about 200 km south.
    expect(placeName(8.5241, 76.9366)).toBe(UNNAMED_PLACE);
  });

  it('every area is named after itself', () => {
    for (const area of SERVICE_AREAS) expect(placeName(area.latitude, area.longitude)).toBe(area.name);
  });

  it('byDistance puts the nearest first and unknown distances last', () => {
    const list = [{ distanceKm: null }, { distanceKm: 5 }, { distanceKm: 1.2 }];
    expect(list.sort(byDistance).map((x) => x.distanceKm)).toEqual([1.2, 5, null]);
  });

  it('the controller lists the areas and names a place', () => {
    const controller = new LocationsController();
    expect(controller.areas()).toBe(SERVICE_AREAS);
    expect(controller.place({ latitude: 10.0159, longitude: 76.3419 })).toEqual({ city: 'Kakkanad' });
  });
});

describe('UsersService.updateLocation', () => {
  const build = () => {
    const prisma = { user: { update: jest.fn().mockResolvedValue({ id: 'u1' }) } };
    return { service: new UsersService(asPrisma(prisma)), prisma };
  };

  it('saves the coordinates and names the city when none is given', async () => {
    const { service, prisma } = build();

    await service.updateLocation('u1', { ...EDAPPALLY, city: '  ' });

    const args = prisma.user.update.mock.calls[0][0];
    expect(args.where).toEqual({ id: 'u1' });
    expect(args.data).toEqual({ ...EDAPPALLY, city: 'Edappally' });
    expect(args.select.passwordHash).toBeUndefined();
  });

  it('keeps a picked area name', async () => {
    const { service, prisma } = build();
    await service.updateLocation('u1', { ...EDAPPALLY, city: ' Edappally North ' });
    expect(prisma.user.update.mock.calls[0][0].data.city).toBe('Edappally North');
  });
});

describe('provider signup location', () => {
  const dto = {
    fullNameOrBusinessName: 'Asha Electricals',
    mobile: '9876543210',
    otp: '1234',
    password: 'secret1',
    confirmPassword: 'secret1',
    categoryId: 'cat-1',
    subServiceIds: ['s1'],
    coverageRadiusKm: 5,
    latitude: 9.9667,
    longitude: 76.2999,
    idProofUrl: 'upload:id-proofs/a.jpg',
  };
  const build = () => {
    const prisma = {
      user: {
        findUnique: jest.fn().mockResolvedValue(null),
        create: jest.fn().mockResolvedValue({ id: 'u1', provider: { status: 'PENDING_VERIFICATION' } }),
      },
    };
    const otp = { verify: jest.fn().mockReturnValue(true) };
    const service = new AuthService(asPrisma(prisma), {} as JwtService, otp as unknown as OtpService);
    return { service, prisma };
  };

  it('stores where the business is, naming the area', async () => {
    const { service, prisma } = build();

    await service.signupProvider(dto);

    const data = prisma.user.create.mock.calls[0][0].data;
    expect(data).toMatchObject({ latitude: 9.9667, longitude: 76.2999, city: 'Kadavanthra' });
  });

  it('keeps the area the provider picked', async () => {
    const { service, prisma } = build();
    await service.signupProvider({ ...dto, city: 'Panampilly Nagar' });
    expect(prisma.user.create.mock.calls[0][0].data.city).toBe('Panampilly Nagar');
  });

  it('refuses 0, 0, which older app builds sent for no location', async () => {
    const { service, prisma } = build();
    await expect(service.signupProvider({ ...dto, latitude: 0, longitude: 0 })).rejects.toThrow(
      'choose where your business is',
    );
    expect(prisma.user.create).not.toHaveBeenCalled();
  });
});

describe('providers for a request, by distance', () => {
  const provider = (id: string, radius: number, latitude: number | null, longitude: number | null) => ({
    id,
    businessName: id,
    coverageRadiusKm: radius,
    averageRating: 4,
    user: { fullName: id, city: 'Kochi', latitude, longitude },
  });
  const build = () => {
    const prisma = {
      provider: {
        findMany: jest.fn().mockResolvedValue([
          provider('far-but-wide', 25, 10.1076, 76.3516), // Aluva, about 10 km
          provider('near', 10, 10.0159, 76.3419), // Kakkanad, about 3.4 km
          provider('out-of-reach', 5, 9.9658, 76.2421), // Fort Kochi, about 10 km
          provider('unknown', 5, null, null),
        ]),
      },
    };
    return { service: new ProvidersService(asPrisma(prisma)), prisma };
  };

  it('nearest first, leaves out providers who do not cover the customer, hides coordinates', async () => {
    const { service } = build();

    const list = await service.findForSubService('s1', EDAPPALLY);

    expect(list.map((p) => p.id)).toEqual(['near', 'far-but-wide', 'unknown']);
    expect(list[0].distanceKm).toBeCloseTo(3.4, 0);
    expect(list[2].distanceKm).toBeNull();
    expect(list[0].user).toEqual({ fullName: 'near', city: 'Kochi' });
  });

  it('without a position keeps everyone, best rated first, with no distance', async () => {
    const { service } = build();

    const list = await service.findForSubService('s1');

    expect(list).toHaveLength(4);
    expect(list.every((p) => p.distanceKm === null)).toBe(true);
    expect(list.every((p) => !('latitude' in p.user))).toBe(true);
  });

  it('the controller passes the position only when both halves are given', async () => {
    const providers = { findForSubService: jest.fn().mockResolvedValue([]) };
    const controller = new ProvidersController(providers as unknown as ProvidersService);

    await controller.search({ subServiceId: 's1', ...EDAPPALLY });
    await controller.search({ subServiceId: 's1', latitude: 10 });

    expect(providers.findForSubService.mock.calls).toEqual([
      ['s1', EDAPPALLY],
      ['s1', undefined],
    ]);
  });
});

describe("the provider's own business location", () => {
  it('GET /providers/me returns the saved location, or null without one', async () => {
    const row = {
      id: 'p1',
      businessName: 'Rajesh',
      coverageRadiusKm: 10,
      status: 'ACTIVE',
      idProofUrl: null,
      idProofNeedsReview: false,
      bankOrUpiDetails: null,
      user: { fullName: 'R', mobile: '9', email: null, profilePhotoUrl: null, city: 'Kadavanthra', latitude: 9.9667, longitude: 76.2999 },
      subServices: [],
    };
    const prisma = { provider: { findUniqueOrThrow: jest.fn().mockResolvedValue(row) } };
    const service = new ProvidersService(asPrisma(prisma));

    expect((await service.getMine('u1')).location).toEqual({ city: 'Kadavanthra', latitude: 9.9667, longitude: 76.2999 });

    prisma.provider.findUniqueOrThrow.mockResolvedValue({ ...row, user: { ...row.user, latitude: null, longitude: null } });
    expect((await service.getMine('u1')).location).toBeNull();
  });
});

describe('search by distance', () => {
  const fan = { id: 's2', name: 'Fan Installation', suggestedMinPrice: 250, suggestedMaxPrice: 450, category: { id: 'c1', name: 'Electrician', active: true } };
  const provider = (id: string, rating: number, latitude: number | null, longitude: number | null) => ({
    id,
    businessName: id,
    yearsExperience: 1,
    averageRating: rating,
    ratingCount: 1,
    certified: false,
    user: { fullName: id, latitude, longitude },
    subServices: [{ subService: fan }],
  });
  const build = () => {
    const prisma = {
      subService: { findMany: jest.fn().mockResolvedValue([fan]) },
      provider: {
        findMany: jest.fn().mockResolvedValue([
          provider('best-far', 4.9, 10.1076, 76.3516),
          provider('nowhere', 4.5, null, null),
          provider('near', 4.0, 10.0159, 76.3419),
        ]),
      },
    };
    return new SearchService(asPrisma(prisma));
  };

  it('gives each provider a distance and can sort nearest first', async () => {
    const result = await build().search({ q: 'fan', sort: 'distance', ...EDAPPALLY });

    expect(result.providers.map((p) => p.id)).toEqual(['near', 'best-far', 'nowhere']);
    expect(result.providers[0].distanceKm).toBeCloseTo(3.4, 0);
    expect(result.providers[2].distanceKm).toBeNull();
  });

  it('sorts by rating when asked for nearest without a position', async () => {
    const result = await build().search({ q: 'fan', sort: 'distance' });

    expect(result.providers.map((p) => p.id)).toEqual(['best-far', 'nowhere', 'near']);
    expect(result.providers.every((p) => p.distanceKm === null)).toBe(true);
  });
});

describe('location routes over HTTP', () => {
  let app: INestApplication;
  const prisma = {
    user: { update: jest.fn().mockResolvedValue({ id: 'u1', city: 'Edappally' }) },
    provider: { findMany: jest.fn().mockResolvedValue([]) },
    subService: { findMany: jest.fn().mockResolvedValue([]) },
    onModuleInit: jest.fn(),
    onModuleDestroy: jest.fn(),
  };

  beforeAll(async () => {
    process.env.JWT_SECRET = 'test-secret';
    const moduleRef = await Test.createTestingModule({ imports: [AppModule] })
      .overrideProvider(PrismaService)
      .useValue(prisma)
      .compile();
    app = moduleRef.createNestApplication();
    app.useGlobalPipes(new ValidationPipe({ whitelist: true, transform: true }));
    app.setGlobalPrefix('api/v1');
    await app.init();
  });

  afterAll(async () => {
    await app.close();
  });

  it('serves the areas and names a place without signing in', async () => {
    const areas = await request(app.getHttpServer()).get('/api/v1/locations/areas').expect(200);
    expect(areas.body).toHaveLength(SERVICE_AREAS.length);

    const place = await request(app.getHttpServer())
      .get('/api/v1/locations/place?latitude=10.026&longitude=76.312')
      .expect(200);
    expect(place.body).toEqual({ city: 'Edappally' });

    await request(app.getHttpServer()).get('/api/v1/locations/place?latitude=95&longitude=76').expect(400);
  });

  it('saving a location needs a sign-in and real coordinates', async () => {
    await request(app.getHttpServer()).put('/api/v1/users/me/location').send(EDAPPALLY).expect(401);

    const token = app.get(JwtService).sign({ sub: 'u1', role: 'CUSTOMER' });
    await request(app.getHttpServer())
      .put('/api/v1/users/me/location')
      .set('Authorization', `Bearer ${token}`)
      .send({ latitude: 'here', longitude: 76.3 })
      .expect(400);

    await request(app.getHttpServer())
      .put('/api/v1/users/me/location')
      .set('Authorization', `Bearer ${token}`)
      .send(EDAPPALLY)
      .expect(200);
    expect(prisma.user.update.mock.calls[0][0].where).toEqual({ id: 'u1' });
  });

  it('turns the provider query position into numbers', async () => {
    await request(app.getHttpServer())
      .get('/api/v1/providers?subServiceId=s1&latitude=10.0261&longitude=76.3125')
      .expect(200);
    await request(app.getHttpServer()).get('/api/v1/providers?subServiceId=s1&latitude=abc').expect(400);
  });

  it('search takes a position and the nearest sort', async () => {
    await request(app.getHttpServer())
      .get('/api/v1/search?q=fan&sort=distance&latitude=10.0261&longitude=76.3125')
      .expect(200);
    await request(app.getHttpServer()).get('/api/v1/search?q=fan&longitude=200').expect(400);
  });
});
