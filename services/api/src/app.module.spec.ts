import { INestApplication, ValidationPipe } from '@nestjs/common';
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
});
