import { UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { createHash } from 'crypto';
import { AuthController } from './auth.controller';
import { AuthService, REFRESH_TOKEN_DAYS } from './auth.service';
import { OtpService } from '../common/otp.service';
import { PrismaService } from '../prisma/prisma.service';

jest.mock('bcrypt', () => ({ hash: jest.fn(async () => 'hashed'), compare: jest.fn(async () => true) }));

const sha = (t: string) => createHash('sha256').update(t).digest('hex');
const DAY = 24 * 60 * 60 * 1000;

function build(stored: object | null = null) {
  const prisma = {
    user: {
      findFirst: jest.fn().mockResolvedValue({ id: 'u1', role: 'CUSTOMER', passwordHash: 'x', provider: null }),
      update: jest.fn().mockResolvedValue({}),
    },
    refreshToken: {
      create: jest.fn().mockResolvedValue({}),
      findUnique: jest.fn().mockResolvedValue(stored),
      update: jest.fn().mockResolvedValue({}),
      updateMany: jest.fn().mockResolvedValue({ count: 1 }),
    },
  };
  const jwt = { sign: jest.fn().mockReturnValue('access') };
  const otp = { verify: jest.fn().mockReturnValue(true) };
  const service = new AuthService(
    prisma as unknown as PrismaService,
    jwt as unknown as JwtService,
    otp as unknown as OtpService,
  );
  return { service, prisma, jwt };
}

const live = (extra: object = {}) => ({
  id: 'rt1',
  userId: 'u1',
  revokedAt: null,
  expiresAt: new Date(Date.now() + DAY),
  user: { role: 'CUSTOMER', provider: null },
  ...extra,
});

describe('refresh tokens', () => {
  it('login returns a refresh token and stores only its hash, for 30 days', async () => {
    const { service, prisma } = build();

    const result = await service.login({ mobileOrEmail: '9000000001', password: 'x' });

    expect(result.refreshToken).toMatch(/^[A-Za-z0-9_-]{40,}$/);
    const data = prisma.refreshToken.create.mock.calls[0][0].data;
    expect(data.userId).toBe('u1');
    expect(data.tokenHash).toBe(sha(result.refreshToken));
    expect(JSON.stringify(data)).not.toContain(result.refreshToken);
    const days = (data.expiresAt.getTime() - Date.now()) / DAY;
    expect(days).toBeGreaterThan(REFRESH_TOKEN_DAYS - 0.01);
    expect(days).toBeLessThanOrEqual(REFRESH_TOKEN_DAYS);
  });

  it('each login gets its own token', async () => {
    const { service } = build();
    const a = await service.login({ mobileOrEmail: 'm', password: 'x' });
    const b = await service.login({ mobileOrEmail: 'm', password: 'x' });
    expect(a.refreshToken).not.toBe(b.refreshToken);
  });

  it('refresh uses the token up and returns a new pair for the same user and role', async () => {
    const { service, prisma, jwt } = build(live({ user: { role: 'PROVIDER', provider: { status: 'ACTIVE' } } }));

    const result = await service.refresh('old-token');

    expect(prisma.refreshToken.findUnique.mock.calls[0][0].where).toEqual({ tokenHash: sha('old-token') });
    expect(prisma.refreshToken.update).toHaveBeenCalledWith({
      where: { id: 'rt1' },
      data: { revokedAt: expect.any(Date) },
    });
    expect(jwt.sign).toHaveBeenCalledWith({ sub: 'u1', role: 'PROVIDER' });
    expect(result.accessToken).toBe('access');
    expect(result.refreshToken).not.toBe('old-token');
  });

  it('refuses an unknown token', async () => {
    const { service } = build(null);
    await expect(service.refresh('nope')).rejects.toBeInstanceOf(UnauthorizedException);
  });

  it('refuses an expired token', async () => {
    const { service, prisma } = build(live({ expiresAt: new Date(Date.now() - 1000) }));
    await expect(service.refresh('t')).rejects.toBeInstanceOf(UnauthorizedException);
    expect(prisma.refreshToken.create).not.toHaveBeenCalled();
  });

  it('a used-up token presented again revokes every sign-in of that user', async () => {
    const { service, prisma } = build(live({ revokedAt: new Date() }));

    await expect(service.refresh('copied')).rejects.toBeInstanceOf(UnauthorizedException);

    expect(prisma.refreshToken.updateMany).toHaveBeenCalledWith({
      where: { userId: 'u1', revokedAt: null },
      data: { revokedAt: expect.any(Date) },
    });
    expect(prisma.refreshToken.create).not.toHaveBeenCalled();
  });

  it('refuses a provider whose account went back to pending verification', async () => {
    const { service } = build(live({ user: { role: 'PROVIDER', provider: { status: 'PENDING_VERIFICATION' } } }));
    await expect(service.refresh('t')).rejects.toThrow('account is pending verification');
  });

  it('logout revokes only that token, and is fine with an unknown one', async () => {
    const { service, prisma } = build();

    expect(await service.logout('mine')).toEqual({ loggedOut: true });

    expect(prisma.refreshToken.updateMany).toHaveBeenCalledWith({
      where: { tokenHash: sha('mine'), revokedAt: null },
      data: { revokedAt: expect.any(Date) },
    });
  });

  it('a password reset ends every sign-in of that user', async () => {
    const { service, prisma } = build();

    await service.resetPassword({ mobileOrEmail: 'm', otp: '1', newPassword: 'p', confirmNewPassword: 'p' });

    expect(prisma.refreshToken.updateMany).toHaveBeenCalledWith({
      where: { userId: 'u1', revokedAt: null },
      data: { revokedAt: expect.any(Date) },
    });
  });

  it('the controller passes the token through', async () => {
    const auth = {
      refresh: jest.fn().mockResolvedValue({ accessToken: 'a', refreshToken: 'r' }),
      logout: jest.fn().mockResolvedValue({ loggedOut: true }),
    };
    const controller = new AuthController(auth as unknown as AuthService);

    expect(await controller.refresh({ refreshToken: 't' })).toEqual({ accessToken: 'a', refreshToken: 'r' });
    expect(await controller.logout({ refreshToken: 't' })).toEqual({ loggedOut: true });
    expect(auth.refresh).toHaveBeenCalledWith('t');
    expect(auth.logout).toHaveBeenCalledWith('t');
  });
});
