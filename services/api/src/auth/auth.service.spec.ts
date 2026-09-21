import { BadRequestException, ConflictException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { AuthService } from './auth.service';
import { OtpService } from '../common/otp.service';

describe('AuthService.signupCustomer', () => {
  const baseDto = {
    fullName: 'Asha Rao',
    mobile: '9876543210',
    otp: '1234',
    password: 'secret1',
    confirmPassword: 'secret1',
    city: 'Bengaluru',
  };

  function build(overrides: { userExists?: boolean; otpValid?: boolean }) {
    const prisma = {
      user: {
        findUnique: jest.fn().mockResolvedValue(overrides.userExists ? { id: 'u1' } : null),
        create: jest.fn().mockResolvedValue({ id: 'u1' }),
      },
    } as any;
    const otp = { verify: jest.fn().mockReturnValue(overrides.otpValid ?? true) } as unknown as OtpService;
    const jwt = { sign: jest.fn().mockReturnValue('signed-token') } as unknown as JwtService;
    return new AuthService(prisma, jwt, otp);
  }

  it('rejects mismatched passwords before touching the database', async () => {
    const service = build({});
    await expect(
      service.signupCustomer({ ...baseDto, confirmPassword: 'different' }),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  it('rejects an invalid OTP', async () => {
    const service = build({ otpValid: false });
    await expect(service.signupCustomer(baseDto)).rejects.toBeInstanceOf(BadRequestException);
  });

  it('rejects a mobile number that is already registered', async () => {
    const service = build({ userExists: true });
    await expect(service.signupCustomer(baseDto)).rejects.toBeInstanceOf(ConflictException);
  });

  it('issues a token on success', async () => {
    const service = build({});
    const result = await service.signupCustomer(baseDto);
    expect(result).toEqual({ accessToken: 'signed-token' });
  });
});
