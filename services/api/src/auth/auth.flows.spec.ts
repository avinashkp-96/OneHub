import { BadRequestException, ConflictException, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcrypt';
import { AuthService } from './auth.service';
import { OtpService } from '../common/otp.service';
import { PrismaService } from '../prisma/prisma.service';

jest.mock('bcrypt', () => ({
  hash: jest.fn(async () => 'hashed-password'),
  compare: jest.fn(),
}));

const compare = bcrypt.compare as unknown as jest.Mock;

interface Overrides {
  existingUser?: object | null;
  loginUser?: object | null;
  otpValid?: boolean;
}

function build(o: Overrides = {}) {
  const prisma = {
    user: {
      findUnique: jest.fn().mockResolvedValue(o.existingUser ?? null),
      findFirst: jest.fn().mockResolvedValue(o.loginUser ?? null),
      create: jest.fn().mockResolvedValue({ id: 'u1', provider: { status: 'PENDING_VERIFICATION' } }),
      update: jest.fn().mockResolvedValue({}),
    },
  };
  const otp = {
    verify: jest.fn().mockReturnValue(o.otpValid ?? true),
    generate: jest.fn().mockReturnValue('4321'),
  };
  const jwt = { sign: jest.fn().mockReturnValue('signed-token') };
  const service = new AuthService(
    prisma as unknown as PrismaService,
    jwt as unknown as JwtService,
    otp as unknown as OtpService,
  );
  return { service, prisma, otp, jwt };
}

const providerDto = {
  fullNameOrBusinessName: 'Asha Electricals',
  mobile: '9876543210',
  otp: '1234',
  password: 'secret1',
  confirmPassword: 'secret1',
  categoryId: 'cat-1',
  subServiceIds: ['s1', 's2'],
  yearsExperience: 8,
  coverageRadiusKm: 5,
  latitude: 9.9,
  longitude: 76.3,
  idProofUrl: 'https://example.test/id.png',
};

describe('AuthService.signupCustomer (success)', () => {
  it('stores a hashed password, never the plain one', async () => {
    const { service, prisma } = build();

    await service.signupCustomer({
      fullName: 'Asha Rao',
      mobile: '9876543210',
      otp: '1234',
      password: 'secret1',
      confirmPassword: 'secret1',
      city: 'Kochi',
    });

    const data = prisma.user.create.mock.calls[0][0].data;
    expect(data.passwordHash).toBe('hashed-password');
    expect(data).not.toHaveProperty('password');
    expect(data.role).toBe('CUSTOMER');
  });
});

describe('AuthService.signupProvider', () => {
  it('rejects mismatched passwords', async () => {
    const { service } = build();
    await expect(
      service.signupProvider({ ...providerDto, confirmPassword: 'other' }),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  it('rejects an invalid OTP', async () => {
    const { service } = build({ otpValid: false });
    await expect(service.signupProvider(providerDto)).rejects.toBeInstanceOf(BadRequestException);
  });

  it('rejects a mobile number that is already registered', async () => {
    const { service } = build({ existingUser: { id: 'u9' } });
    await expect(service.signupProvider(providerDto)).rejects.toBeInstanceOf(ConflictException);
  });

  it('creates the provider as pending verification with its sub-services', async () => {
    const { service, prisma } = build();

    const result = await service.signupProvider(providerDto);

    const data = prisma.user.create.mock.calls[0][0].data;
    expect(data.role).toBe('PROVIDER');
    expect(data.provider.create.status).toBe('PENDING_VERIFICATION');
    expect(data.provider.create.subServices.create).toEqual([
      { subServiceId: 's1' },
      { subServiceId: 's2' },
    ]);
    expect(result).toEqual({ userId: 'u1', status: 'PENDING_VERIFICATION' });
  });
});

describe('AuthService.login', () => {
  beforeEach(() => compare.mockReset());

  it('rejects an unknown user', async () => {
    const { service } = build({ loginUser: null });
    await expect(
      service.login({ mobileOrEmail: '9000000000', password: 'x' }),
    ).rejects.toBeInstanceOf(UnauthorizedException);
  });

  it('rejects a wrong password', async () => {
    compare.mockResolvedValue(false);
    const { service } = build({ loginUser: { id: 'u1', role: 'CUSTOMER', passwordHash: 'h' } });
    await expect(
      service.login({ mobileOrEmail: '9876543210', password: 'bad' }),
    ).rejects.toBeInstanceOf(UnauthorizedException);
  });

  it('blocks a provider whose account is still pending verification', async () => {
    compare.mockResolvedValue(true);
    const { service } = build({
      loginUser: { id: 'u1', role: 'PROVIDER', passwordHash: 'h', provider: { status: 'PENDING_VERIFICATION' } },
    });
    await expect(
      service.login({ mobileOrEmail: '9876543210', password: 'ok' }),
    ).rejects.toThrow('account is pending verification');
  });

  it('signs a token carrying the user id and role', async () => {
    compare.mockResolvedValue(true);
    const { service, jwt } = build({
      loginUser: { id: 'u7', role: 'PROVIDER', passwordHash: 'h', provider: { status: 'ACTIVE' } },
    });

    const result = await service.login({ mobileOrEmail: 'a@b.co', password: 'ok' });

    expect(jwt.sign).toHaveBeenCalledWith({ sub: 'u7', role: 'PROVIDER' });
    expect(result).toEqual({ accessToken: 'signed-token' });
  });

  it('looks the user up by mobile or email', async () => {
    compare.mockResolvedValue(true);
    const { service, prisma } = build({ loginUser: { id: 'u1', role: 'CUSTOMER', passwordHash: 'h' } });

    await service.login({ mobileOrEmail: 'me@example.com', password: 'ok' });

    expect(prisma.user.findFirst).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { OR: [{ mobile: 'me@example.com' }, { email: 'me@example.com' }] },
      }),
    );
  });
});

describe('AuthService.requestOtp', () => {
  it('generates a code for the mobile number', () => {
    const { service, otp } = build();

    const result = service.requestOtp('9876543210');

    expect(otp.generate).toHaveBeenCalledWith('9876543210');
    expect(result).toEqual({ sent: true, devOnlyOtp: '4321' });
  });
});

describe('AuthService.resetPassword', () => {
  const dto = {
    mobileOrEmail: '9876543210',
    otp: '1234',
    newPassword: 'newsecret',
    confirmNewPassword: 'newsecret',
  };

  it('rejects mismatched passwords', async () => {
    const { service } = build();
    await expect(
      service.resetPassword({ ...dto, confirmNewPassword: 'different' }),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  it('rejects an invalid OTP', async () => {
    const { service } = build({ otpValid: false });
    await expect(service.resetPassword(dto)).rejects.toBeInstanceOf(BadRequestException);
  });

  it('rejects when no account matches', async () => {
    const { service } = build({ loginUser: null });
    await expect(service.resetPassword(dto)).rejects.toThrow('no account for that mobile/email');
  });

  it('updates the stored hash', async () => {
    const { service, prisma } = build({ loginUser: { id: 'u1' } });

    const result = await service.resetPassword(dto);

    expect(prisma.user.update).toHaveBeenCalledWith({
      where: { id: 'u1' },
      data: { passwordHash: 'hashed-password' },
    });
    expect(result).toEqual({ reset: true });
  });
});
