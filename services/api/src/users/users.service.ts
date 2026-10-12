import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { UpdateProfileDto } from './dto/update-profile.dto';

@Injectable()
export class UsersService {
  constructor(private readonly prisma: PrismaService) {}

  // docx 4.8 / 5.2 profile screens
  profile(userId: string) {
    return this.prisma.user.findUniqueOrThrow({
      where: { id: userId },
      include: { provider: { include: { subServices: true } }, addresses: true },
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
    return this.prisma.user.update({ where: { id: userId }, data });
  }
}
