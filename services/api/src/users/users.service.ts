import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { UpdateProfileDto } from './dto/update-profile.dto';

// What a user gets back about their own account, from GET and PATCH
// /users/me. Selected explicitly so the password hash never leaves the server
// (both routes used to return the whole row), and, as with GET /providers/me,
// the ID proof and bank/UPI details stay out too.
export const SELF_SELECT = {
  id: true,
  role: true,
  fullName: true,
  mobile: true,
  mobileVerifiedAt: true,
  email: true,
  city: true,
  latitude: true,
  longitude: true,
  profilePhotoUrl: true,
  createdAt: true,
  updatedAt: true,
  provider: {
    select: {
      id: true,
      businessName: true,
      yearsExperience: true,
      coverageRadiusKm: true,
      status: true,
      online: true,
      averageRating: true,
      ratingCount: true,
      certified: true,
      createdAt: true,
      subServices: true,
    },
  },
  addresses: true,
} as const;

@Injectable()
export class UsersService {
  constructor(private readonly prisma: PrismaService) {}

  // docx 4.8 / 5.2 profile screens
  profile(userId: string) {
    return this.prisma.user.findUniqueOrThrow({
      where: { id: userId },
      select: SELF_SELECT,
    });
  }

  updateProfile(userId: string, dto: UpdateProfileDto) {
    // Pick the allowed fields explicitly so a caller can never pass more, even
    // if the validation pipe is bypassed.
    const data = {
      fullName: dto.fullName,
      email: dto.email,
      profilePhotoUrl: dto.profilePhotoUrl,
    };
    return this.prisma.user.update({ where: { id: userId }, data, select: SELF_SELECT });
  }
}
