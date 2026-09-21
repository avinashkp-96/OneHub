import { BadRequestException, ConflictException, Injectable, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcrypt';
import { PrismaService } from '../prisma/prisma.service';
import { OtpService } from '../common/otp.service';
import { SignupCustomerDto } from './dto/signup-customer.dto';
import { SignupProviderDto } from './dto/signup-provider.dto';
import { LoginDto, ResetPasswordDto } from './dto/login.dto';

const SALT_ROUNDS = 10;

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
    const user = await this.prisma.user.create({
      data: {
        role: 'CUSTOMER',
        fullName: dto.fullName,
        mobile: dto.mobile,
        mobileVerifiedAt: new Date(),
        email: dto.email,
        passwordHash,
        city: dto.city,
        latitude: dto.latitude,
        longitude: dto.longitude,
      },
    });
    return this.issueToken(user.id, 'CUSTOMER');
  }

  // docx 2.3
  async signupProvider(dto: SignupProviderDto) {
    if (dto.password !== dto.confirmPassword) {
      throw new BadRequestException('password and confirmPassword must match');
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
        provider: {
          create: {
            businessName: dto.fullNameOrBusinessName,
            yearsExperience: dto.yearsExperience,
            coverageRadiusKm: dto.coverageRadiusKm,
            idProofUrl: dto.idProofUrl,
            bankOrUpiDetails: dto.bankOrUpiDetails,
            status: 'PENDING_VERIFICATION',
            subServices: {
              create: dto.subServiceIds.map((subServiceId) => ({ subServiceId })),
            },
          },
        },
      },
      include: { provider: true },
    });

    // Status starts PENDING_VERIFICATION until admin approves ID proof — docx 2.3/2.4.
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

    if (user.role === 'PROVIDER' && user.provider?.status === 'PENDING_VERIFICATION') {
      throw new UnauthorizedException('account is pending verification');
    }

    return this.issueToken(user.id, user.role);
  }

  // docx 2.5
  requestOtp(mobile: string) {
    const code = this.otp.generate(mobile);
    // TODO: dispatch via SMS provider; returned here only until that integration exists.
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
    return { reset: true };
  }

  private issueToken(sub: string, role: 'CUSTOMER' | 'PROVIDER' | 'ADMIN') {
    return { accessToken: this.jwt.sign({ sub, role }) };
  }
}
