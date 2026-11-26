import { BadRequestException, ConflictException, Injectable, UnauthorizedException } from '@nestjs/common';
import { placeName } from '../locations/areas';
import { addressFields } from '../users/addresses';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcrypt';
import { createHash, randomBytes } from 'crypto';
import { PrismaService } from '../prisma/prisma.service';
import { OtpService } from '../common/otp.service';
import { SignupCustomerDto } from './dto/signup-customer.dto';
import { SignupProviderDto } from './dto/signup-provider.dto';
import { LoginDto, ResetPasswordDto } from './dto/login.dto';

const SALT_ROUNDS = 10;

// How long a sign-in lasts without being used. Each renewal starts it again,
// so someone who opens the app at least monthly stays signed in.
export const REFRESH_TOKEN_DAYS = 30;

const hashToken = (token: string) => createHash('sha256').update(token).digest('hex');

@Injectable()
export class AuthService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly jwt: JwtService,
    private readonly otp: OtpService,
  ) {}

  // docx 2.1
  async signupCustomer(dto: SignupCustomerDto) {
    if (dto.password !== dto.confirmPassword) {
      throw new BadRequestException('password and confirmPassword must match');
    }
    if (!this.otp.verify(dto.mobile, dto.otp)) {
      throw new BadRequestException('invalid or expired OTP');
    }
    const existing = await this.prisma.user.findUnique({ where: { mobile: dto.mobile } });
    if (existing) throw new ConflictException('mobile number already registered');

    const passwordHash = await bcrypt.hash(dto.password, SALT_ROUNDS);
    const address = addressFields(dto.address);
    const user = await this.prisma.user.create({
      data: {
        role: 'CUSTOMER',
        fullName: dto.fullName,
        mobile: dto.mobile,
        mobileVerifiedAt: new Date(),
        email: dto.email,
        passwordHash,
        city: address.city,
        latitude: address.latitude,
        longitude: address.longitude,
        addresses: { create: address },
      },
    });
    return this.issueToken(user.id, 'CUSTOMER');
  }

  // docx 2.3
  async signupProvider(dto: SignupProviderDto) {
    if (dto.password !== dto.confirmPassword) {
      throw new BadRequestException('password and confirmPassword must match');
    }
    // 0, 0 is what the app sent before it asked for a location.
    if (dto.latitude === 0 && dto.longitude === 0) {
      throw new BadRequestException('choose where your business is');
    }
    if (!this.otp.verify(dto.mobile, dto.otp)) {
      throw new BadRequestException('invalid or expired OTP');
    }
    const existing = await this.prisma.user.findUnique({ where: { mobile: dto.mobile } });
    if (existing) throw new ConflictException('mobile number already registered');

    const passwordHash = await bcrypt.hash(dto.password, SALT_ROUNDS);

    const user = await this.prisma.user.create({
      data: {
        role: 'PROVIDER',
        fullName: dto.fullNameOrBusinessName,
        mobile: dto.mobile,
        mobileVerifiedAt: new Date(),
        email: dto.email,
        passwordHash,
        latitude: dto.latitude,
        longitude: dto.longitude,
        city: dto.city?.trim() || placeName(dto.latitude, dto.longitude),
        provider: {
          create: {
            businessName: dto.fullNameOrBusinessName,
            yearsExperience: dto.yearsExperience,
            coverageRadiusKm: dto.coverageRadiusKm,
            idProofUrl: dto.idProofUrl,
            bankOrUpiDetails: dto.bankOrUpiDetails,
            // Active straight away, with the ID proof flagged for review: there
            // is no approval flow yet (docx 2.3/2.4 asks for one), and until
            // there is, a new provider can log in, be found and get requests.
            status: 'ACTIVE',
            idProofNeedsReview: true,
            subServices: {
              create: dto.subServiceIds.map((subServiceId) => ({ subServiceId })),
            },
          },
        },
      },
      include: { provider: true },
    });

    return { userId: user.id, status: user.provider?.status };
  }

  // docx 2.2 / 2.4
  async login(dto: LoginDto) {
    const user = await this.prisma.user.findFirst({
      where: { OR: [{ mobile: dto.mobileOrEmail }, { email: dto.mobileOrEmail }] },
      include: { provider: true },
    });
    if (!user) throw new UnauthorizedException('invalid credentials');

    const valid = await bcrypt.compare(dto.password, user.passwordHash);
    if (!valid) throw new UnauthorizedException('invalid credentials');

    // A provider still pending verification may log in: there is no
    // approval flow yet.
    return this.issueToken(user.id, user.role);
  }

  // docx 2.5
  // No SMS provider is connected yet. Outside production the code comes back
  // as devOnlyOtp so the apps can show it as a test code; in production it
  // never leaves the server, so nobody can verify a number they do not hold.
  // Sign-ups there wait for the SMS provider (see Integrations in CLAUDE.md).
  requestOtp(mobile: string) {
    const code = this.otp.generate(mobile);
    if (process.env.NODE_ENV === 'production') return { sent: true };
    return { sent: true, devOnlyOtp: code };
  }

  async resetPassword(dto: ResetPasswordDto) {
    if (dto.newPassword !== dto.confirmNewPassword) {
      throw new BadRequestException('newPassword and confirmNewPassword must match');
    }
    if (!this.otp.verify(dto.mobileOrEmail, dto.otp)) {
      throw new BadRequestException('invalid or expired OTP');
    }
    const user = await this.prisma.user.findFirst({
      where: { OR: [{ mobile: dto.mobileOrEmail }, { email: dto.mobileOrEmail }] },
    });
    if (!user) throw new BadRequestException('no account for that mobile/email');

    const passwordHash = await bcrypt.hash(dto.newPassword, SALT_ROUNDS);
    await this.prisma.user.update({ where: { id: user.id }, data: { passwordHash } });
    // A new password ends every existing sign-in, on every device.
    await this.revokeAll(user.id);
    return { reset: true };
  }

  // Renews a sign-in: the presented refresh token is used up and a new pair
  // comes back. An unknown, expired or used-up token is refused; a used-up
  // one also revokes every sign-in of its user, because only a copy of the
  // token could still be presenting it.
  async refresh(refreshToken: string) {
    const stored = await this.prisma.refreshToken.findUnique({
      where: { tokenHash: hashToken(refreshToken) },
      include: { user: { select: { role: true, provider: { select: { status: true } } } } },
    });
    if (!stored) throw new UnauthorizedException('sign-in expired');
    if (stored.revokedAt) {
      await this.revokeAll(stored.userId);
      throw new UnauthorizedException('sign-in expired');
    }
    if (stored.expiresAt <= new Date()) throw new UnauthorizedException('sign-in expired');

    await this.prisma.refreshToken.update({ where: { id: stored.id }, data: { revokedAt: new Date() } });
    return this.issueToken(stored.userId, stored.user.role);
  }

  // Ends this one sign-in. Unknown tokens are fine: the result is the same.
  async logout(refreshToken: string) {
    await this.prisma.refreshToken.updateMany({
      where: { tokenHash: hashToken(refreshToken), revokedAt: null },
      data: { revokedAt: new Date() },
    });
    return { loggedOut: true };
  }

  private revokeAll(userId: string) {
    return this.prisma.refreshToken.updateMany({
      where: { userId, revokedAt: null },
      data: { revokedAt: new Date() },
    });
  }

  // A short access token (JWT_EXPIRES_IN, 1 hour by default) for API calls,
  // and a refresh token to renew it. Only the refresh token's hash is kept.
  private async issueToken(sub: string, role: 'CUSTOMER' | 'PROVIDER' | 'ADMIN') {
    const refreshToken = randomBytes(32).toString('base64url');
    await this.prisma.refreshToken.create({
      data: {
        userId: sub,
        tokenHash: hashToken(refreshToken),
        expiresAt: new Date(Date.now() + REFRESH_TOKEN_DAYS * 24 * 60 * 60 * 1000),
      },
    });
    return { accessToken: this.jwt.sign({ sub, role }), refreshToken };
  }
}
