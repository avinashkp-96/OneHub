import { BadRequestException, INestApplication, NotFoundException, ValidationPipe } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { AppModule } from '../app.module';
import { NotificationsService } from '../notifications/notifications.service';
import { PrismaService } from '../prisma/prisma.service';
import { RequirementsService } from '../requirements/requirements.service';
import { AddressesController } from './addresses.controller';
import { addressFields } from './addresses';
import { AddressesService } from './addresses.service';

const asPrisma = (p: object) => p as unknown as PrismaService;
const home = {
  house: ' 12B, Palm Grove ',
  street: ' Changampuzha Nagar ',
  landmark: '  ',
  pincode: '682024',
  latitude: 10.0261,
  longitude: 76.3125,
};

describe('addressFields', () => {
  it('trims, defaults the label to Home, names the area and drops a blank landmark', () => {
    expect(addressFields(home)).toEqual({
      label: 'Home',
      house: '12B, Palm Grove',
      street: 'Changampuzha Nagar',
      landmark: null,
      pincode: '682024',
      city: 'Edappally',
      latitude: 10.0261,
      longitude: 76.3125,
    });
  });

  it('keeps a given label, landmark and area', () => {
    expect(addressFields({ ...home, label: ' Office ', landmark: ' Near Lulu ', city: ' Infopark ' })).toMatchObject({
      label: 'Office',
      landmark: 'Near Lulu',
      city: 'Infopark',
    });
  });
});

describe('AddressesService', () => {
  const build = (ids: string[] = ['a1', 'a2']) => {
    const prisma = {
      address: {
        findMany: jest.fn().mockResolvedValue(ids.map((id) => ({ id }))),
        create: jest.fn().mockResolvedValue({ id: 'a3' }),
        delete: jest.fn().mockResolvedValue({}),
      },
    };
    return { service: new AddressesService(asPrisma(prisma)), prisma };
  };

  it("lists only the caller's addresses, oldest first", async () => {
    const { service, prisma } = build();
    await service.list('u1');
    expect(prisma.address.findMany.mock.calls[0][0]).toMatchObject({ where: { userId: 'u1' }, orderBy: { createdAt: 'asc' } });
  });

  it('saves a new address for the caller', async () => {
    const { service, prisma } = build();
    await service.create('u1', { ...home, label: 'Office' });
    expect(prisma.address.create.mock.calls[0][0].data).toMatchObject({ userId: 'u1', label: 'Office', city: 'Edappally' });
  });

  it("deletes the caller's own address", async () => {
    const { service, prisma } = build();
    expect(await service.remove('u1', 'a2')).toEqual({ deleted: 'a2' });
    expect(prisma.address.delete).toHaveBeenCalledWith({ where: { id: 'a2' } });
  });

  it("refuses someone else's address, and the last one", async () => {
    const { service, prisma } = build(['a1']);
    await expect(service.remove('u1', 'a9')).rejects.toBeInstanceOf(NotFoundException);
    await expect(service.remove('u1', 'a1')).rejects.toBeInstanceOf(BadRequestException);
    expect(prisma.address.delete).not.toHaveBeenCalled();
  });

  it('the controller passes the signed-in user', async () => {
    const addresses = { list: jest.fn(), create: jest.fn(), remove: jest.fn() };
    const controller = new AddressesController(addresses as unknown as AddressesService);
    const req = { user: { sub: 'u1', role: 'CUSTOMER' as const } };

    await controller.list(req);
    await controller.create(req, home);
    await controller.remove(req, 'a1');

    expect(addresses.list).toHaveBeenCalledWith('u1');
    expect(addresses.create).toHaveBeenCalledWith('u1', home);
    expect(addresses.remove).toHaveBeenCalledWith('u1', 'a1');
  });
});

describe('the job address on a provider’s incoming list', () => {
  const job = { label: 'Home', house: '12B', street: 'MG Road', landmark: null, pincode: '682024', city: 'Kakkanad', latitude: 10.0159, longitude: 76.3419 };
  const row = (bids: object[], confirmedBidId: string | null, address: object | null = job) => ({
    id: 'r1',
    status: 'BID_RECEIVED',
    confirmedBidId,
    address,
    bids,
    targetedProviders: [{ status: 'ACCEPTED' }],
    customer: { fullName: 'Meera', city: 'Edappally', latitude: 10.0261, longitude: 76.3125 },
  });
  const listFor = async (r: object) => {
    const prisma = {
      requirement: { findMany: jest.fn().mockResolvedValue([r]), updateMany: jest.fn() },
      provider: { findUnique: jest.fn().mockResolvedValue({ user: { latitude: 10.0261, longitude: 76.3125 } }) },
    };
    const service = new RequirementsService(asPrisma(prisma), {} as NotificationsService);
    return (await service.listForProvider('p1'))[0];
  };

  it('before being chosen: the area and distance of the job, not the address', async () => {
    const r = await listFor(row([{ id: 'b1', confirmed: false }], null));
    expect(r.address).toBeNull();
    expect(r.customerPlace).toBe('Kakkanad');
    expect(r.distanceKm).toBeCloseTo(3.4, 0);
  });

  it('the chosen provider gets the full address', async () => {
    const r = await listFor(row([{ id: 'b1', confirmed: true }], 'b1'));
    expect(r.address).toEqual(job);
  });

  it("another provider's confirmation shows nothing", async () => {
    const r = await listFor(row([{ id: 'b2', confirmed: false }], 'b1'));
    expect(r.address).toBeNull();
  });

  it('an older request with no address falls back to the customer', async () => {
    const r = await listFor(row([], null, null));
    expect(r.customerPlace).toBe('Edappally');
    expect(r.distanceKm).toBe(0);
    expect(r.address).toBeNull();
  });
});

describe('address routes over HTTP', () => {
  let app: INestApplication;
  const prisma = {
    address: { findMany: jest.fn().mockResolvedValue([]), create: jest.fn().mockResolvedValue({ id: 'a1' }) },
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

  it('need a sign-in, and a complete address to save', async () => {
    await request(app.getHttpServer()).get('/api/v1/users/me/addresses').expect(401);

    const token = app.get(JwtService).sign({ sub: 'u1', role: 'CUSTOMER' });
    const auth = { Authorization: `Bearer ${token}` };
    await request(app.getHttpServer()).get('/api/v1/users/me/addresses').set(auth).expect(200);
    await request(app.getHttpServer())
      .post('/api/v1/users/me/addresses')
      .set(auth)
      .send({ ...home, pincode: '12' })
      .expect(400);
    await request(app.getHttpServer()).post('/api/v1/users/me/addresses').set(auth).send(home).expect(201);
    expect(prisma.address.create.mock.calls[0][0].data.userId).toBe('u1');
  });
});
