import { BadRequestException, INestApplication, NotFoundException, ValidationPipe } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { Test } from '@nestjs/testing';
import { existsSync, mkdtempSync, readdirSync, readFileSync, rmSync } from 'fs';
import { tmpdir } from 'os';
import { join } from 'path';
import request from 'supertest';
import { AppModule } from '../app.module';
import { PrismaService } from '../prisma/prisma.service';
import { imageType, MAX_UPLOAD_BYTES, PHOTO_URL_PREFIX, UploadsService } from './uploads.service';

// Smallest real headers for each accepted type, padded past the 12 bytes the
// sniffer reads.
const JPEG = Buffer.concat([Buffer.from([0xff, 0xd8, 0xff, 0xe0]), Buffer.alloc(40, 1)]);
const PNG = Buffer.concat([Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]), Buffer.alloc(40, 1)]);
const WEBP = Buffer.concat([Buffer.from('RIFF'), Buffer.alloc(4, 1), Buffer.from('WEBP'), Buffer.alloc(40, 1)]);
const GIF = Buffer.concat([Buffer.from('GIF89a'), Buffer.alloc(40, 1)]);

let dir: string;
beforeEach(() => {
  dir = mkdtempSync(join(tmpdir(), 'onehub-uploads-'));
  process.env.UPLOAD_DIR = dir;
});
afterEach(() => {
  rmSync(dir, { recursive: true, force: true });
  delete process.env.UPLOAD_DIR;
});

const file = (buffer: Buffer) => ({ buffer, size: buffer.length });

describe('imageType', () => {
  it('reads the type from the first bytes', () => {
    expect(imageType(JPEG)?.ext).toBe('jpg');
    expect(imageType(PNG)?.ext).toBe('png');
    expect(imageType(WEBP)?.ext).toBe('webp');
    expect(imageType(GIF)).toBeUndefined();
    expect(imageType(Buffer.from([0xff, 0xd8, 0xff]))).toBeUndefined();
  });
});

describe('UploadsService', () => {
  it('saves a photo under a random name and returns its public url', () => {
    const service = new UploadsService();

    const a = service.savePhoto(file(PNG));
    const b = service.savePhoto(file(PNG));

    expect(a.url).toMatch(new RegExp(`^${PHOTO_URL_PREFIX}[a-f0-9]{32}\\.png$`));
    expect(a.url).not.toBe(b.url);
    const name = a.url.slice(PHOTO_URL_PREFIX.length);
    expect(readFileSync(join(dir, 'photos', name))).toEqual(PNG);
  });

  it('keeps an ID proof private and returns only a reference', () => {
    const service = new UploadsService();

    const { url } = service.saveIdProof(file(JPEG));

    expect(url).toMatch(/^upload:id-proofs\/[a-f0-9]{32}\.jpg$/);
    expect(readdirSync(join(dir, 'private', 'id-proofs'))).toHaveLength(1);
    expect(existsSync(join(dir, 'photos'))).toBe(false);
  });

  it('refuses a missing, empty, oversized or non-image file', () => {
    const service = new UploadsService();
    expect(() => service.savePhoto(undefined)).toThrow(BadRequestException);
    expect(() => service.savePhoto(file(Buffer.alloc(0)))).toThrow('choose an image');
    expect(() => service.savePhoto({ buffer: JPEG, size: MAX_UPLOAD_BYTES + 1 })).toThrow('5 MB');
    expect(() => service.savePhoto(file(GIF))).toThrow('only JPEG, PNG or WebP');
  });

  it('finds a stored photo and refuses bad or unknown names', () => {
    const service = new UploadsService();
    const name = service.savePhoto(file(WEBP)).url.slice(PHOTO_URL_PREFIX.length);

    expect(service.photoPath(name)).toEqual({ path: join(dir, 'photos', name), mime: 'image/webp' });
    expect(() => service.photoPath('../private/id-proofs/x.jpg')).toThrow(NotFoundException);
    expect(() => service.photoPath(`${'0'.repeat(32)}.jpg`)).toThrow(NotFoundException);
  });
});

describe('upload routes', () => {
  let app: INestApplication;
  const prisma = {
    requirement: { create: jest.fn() },
    onModuleInit: jest.fn(),
    onModuleDestroy: jest.fn(),
  };

  beforeEach(async () => {
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

  afterEach(() => app.close());

  const token = (role = 'CUSTOMER') => `Bearer ${app.get(JwtService).sign({ sub: 'u1', role })}`;

  it('a signed-in user uploads a photo, and anyone can then load it', async () => {
    const res = await request(app.getHttpServer())
      .post('/api/v1/uploads/photo')
      .set('Authorization', token())
      .attach('file', JPEG, 'fan.jpg')
      .expect(201);

    const served = await request(app.getHttpServer()).get(res.body.url).expect(200);
    expect(served.headers['content-type']).toBe('image/jpeg');
    expect(served.headers['cache-control']).toContain('immutable');
    expect(served.headers['x-content-type-options']).toBe('nosniff');
    expect(Buffer.from(served.body)).toEqual(JPEG);
  });

  it('refuses a photo upload without signing in', async () => {
    await request(app.getHttpServer()).post('/api/v1/uploads/photo').attach('file', JPEG, 'a.jpg').expect(401);
  });

  it('refuses a file that is not an image, whatever its name', async () => {
    const res = await request(app.getHttpServer())
      .post('/api/v1/uploads/photo')
      .set('Authorization', token())
      .attach('file', Buffer.from('<script>alert(1)</script>xxxxxx'), 'evil.jpg')
      .expect(400);
    expect(res.body.message).toContain('only JPEG, PNG or WebP');
  });

  it('refuses a file over 5 MB', async () => {
    const big = Buffer.concat([JPEG, Buffer.alloc(MAX_UPLOAD_BYTES + 10)]);
    await request(app.getHttpServer())
      .post('/api/v1/uploads/photo')
      .set('Authorization', token())
      .attach('file', big, 'big.jpg')
      .expect(413);
  });

  it('takes an ID proof during signup, with no account yet, and never serves it', async () => {
    const res = await request(app.getHttpServer())
      .post('/api/v1/uploads/id-proof')
      .attach('file', PNG, 'id.png')
      .expect(201);

    expect(res.body.url).toMatch(/^upload:id-proofs\//);
    const name = res.body.url.split('/').pop();
    await request(app.getHttpServer()).get(`/api/v1/uploads/photos/${name}`).expect(404);
  });

  it('a request may only carry photos uploaded here, at most five', async () => {
    const send = (photoUrls: string[]) =>
      request(app.getHttpServer())
        .post('/api/v1/requirements')
        .set('Authorization', token())
        .send({ subServiceId: 's1', title: 'Fan', description: 'Noisy', providerIds: ['p1'], photoUrls });

    const outside = await send(['https://example.com/x.jpg']).expect(400);
    expect(JSON.stringify(outside.body)).toContain('photos must be uploaded through the app');

    const six = Array.from({ length: 6 }, (_, i) => `${PHOTO_URL_PREFIX}${String(i).repeat(32)}.jpg`);
    await send(six).expect(400);
  });
});
