import { INestApplication, ValidationPipe } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { AppModule } from './app.module';
import { PrismaService } from './prisma/prisma.service';

// Boots the real module graph with only the database swapped out, so a
// missing provider or import, or a route without its guard, fails here.
describe('AppModule wiring', () => {
  let app: INestApplication;
  const prisma = {
    category: { findMany: jest.fn().mockResolvedValue([{ id: 'c1', name: 'Electrician' }]) },
    user: { update: jest.fn().mockResolvedValue({}) },
    provider: {
      findUniqueOrThrow: jest.fn().mockResolvedValue({ id: 'p-mine' }),
      update: jest.fn().mockResolvedValue({ id: 'p-mine', coverageRadiusKm: 5, subServices: [] }),
    },
    bid: { findUniqueOrThrow: jest.fn().mockResolvedValue({ id: 'b1', providerId: 'p-other' }) },
    payment: { create: jest.fn() },
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

  it('serves the public category list', async () => {
    const res = await request(app.getHttpServer()).get('/api/v1/categories').expect(200);
    expect(res.body).toEqual([{ id: 'c1', name: 'Electrician' }]);
  });

  it('refuses a protected route without a token', async () => {
    await request(app.getHttpServer()).get('/api/v1/requirements/mine').expect(401);
  });

  it('validates the request body before it reaches the service', async () => {
    const res = await request(app.getHttpServer())
      .post('/api/v1/auth/customer/login')
      .send({})
      .expect(400);
    expect(JSON.stringify(res.body)).toContain('mobileOrEmail');
  });

  it('strips fields a caller must not set when updating their own profile', async () => {
    const token = app.get(JwtService).sign({ sub: 'u1', role: 'CUSTOMER' });

    await request(app.getHttpServer())
      .patch('/api/v1/users/me')
      .set('Authorization', `Bearer ${token}`)
      .send({ fullName: 'Asha', role: 'ADMIN', passwordHash: 'evil' })
      .expect(200);

    const data = prisma.user.update.mock.calls[0][0].data;
    expect(data.fullName).toBe('Asha');
    expect(data).not.toHaveProperty('role');
    expect(data).not.toHaveProperty('passwordHash');
  });

  it("refuses a provider confirming another provider's unlock", async () => {
    const token = app.get(JwtService).sign({ sub: 'u2', role: 'PROVIDER' });

    await request(app.getHttpServer())
      .post('/api/v1/bids/b1/unlock-contact')
      .set('Authorization', `Bearer ${token}`)
      .expect(403);

    expect(prisma.payment.create).not.toHaveBeenCalled();
  });

  it("updates only the caller's own business details and strips protected fields", async () => {
    const token = app.get(JwtService).sign({ sub: 'u2', role: 'PROVIDER' });

    await request(app.getHttpServer())
      .patch('/api/v1/providers/me')
      .set('Authorization', `Bearer ${token}`)
      .send({ yearsExperience: 4, userId: 'u-other', status: 'ACTIVE', certified: true })
      .expect(200);

    const args = prisma.provider.update.mock.calls[0][0];
    expect(args.where).toEqual({ userId: 'u2' });
    expect(args.data.yearsExperience).toBe(4);
    expect(args.data).not.toHaveProperty('status');
    expect(args.data).not.toHaveProperty('certified');
  });

  it('refuses a customer reading or editing provider business details', async () => {
    const token = app.get(JwtService).sign({ sub: 'u1', role: 'CUSTOMER' });

    await request(app.getHttpServer())
      .get('/api/v1/providers/me')
      .set('Authorization', `Bearer ${token}`)
      .expect(403);
    await request(app.getHttpServer())
      .patch('/api/v1/providers/me')
      .set('Authorization', `Bearer ${token}`)
      .send({ yearsExperience: 4 })
      .expect(403);
  });

  it('validates business detail values', async () => {
    const token = app.get(JwtService).sign({ sub: 'u2', role: 'PROVIDER' });

    const res = await request(app.getHttpServer())
      .patch('/api/v1/providers/me')
      .set('Authorization', `Bearer ${token}`)
      .send({ yearsExperience: -1, coverageRadiusKm: 0, subServiceIds: [] })
      .expect(400);
    const body = JSON.stringify(res.body);
    expect(body).toContain('yearsExperience');
    expect(body).toContain('coverageRadiusKm');
    expect(body).toContain('subServiceIds');
  });

  it('rejects a customer token on a provider-only route', async () => {
    const token = app.get(JwtService).sign({ sub: 'u1', role: 'CUSTOMER' });

    await request(app.getHttpServer())
      .post('/api/v1/bids/b1/unlock-contact')
      .set('Authorization', `Bearer ${token}`)
      .expect(403);
  });
});
