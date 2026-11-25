import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { ADDRESS_SELECT, addressFields } from './addresses';
import { AddressDto } from './dto/address.dto';

// A customer's saved addresses (docx 4.8). Every route acts on the caller's
// own addresses only.
@Injectable()
export class AddressesService {
  constructor(private readonly prisma: PrismaService) {}

  list(userId: string) {
    return this.prisma.address.findMany({
      where: { userId },
      select: ADDRESS_SELECT,
      orderBy: { createdAt: 'asc' },
    });
  }

  create(userId: string, dto: AddressDto) {
    return this.prisma.address.create({
      data: { userId, ...addressFields(dto) },
      select: ADDRESS_SELECT,
    });
  }

  // Requests keep their own copy, so removing an address never changes a job.
  // The last one stays, because a request needs an address.
  async remove(userId: string, id: string) {
    const mine = await this.prisma.address.findMany({ where: { userId }, select: { id: true } });
    if (!mine.some((a) => a.id === id)) throw new NotFoundException('address not found');
    if (mine.length === 1) throw new BadRequestException('keep at least one address');
    await this.prisma.address.delete({ where: { id } });
    return { deleted: id };
  }
}
