import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

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

  updateProfile(userId: string, data: { fullName?: string; email?: string; profilePhotoUrl?: string }) {
    return this.prisma.user.update({ where: { id: userId }, data });
  }
}
