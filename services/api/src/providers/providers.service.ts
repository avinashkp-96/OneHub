import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class ProvidersService {
  constructor(private readonly prisma: PrismaService) {}

  // docx 4.2 "Search" results list + 4.3 "Provider Selection". Filters to
  // providers offering the given sub-service. Distance/radius filtering needs
  // a geo query (PostGIS or a haversine calc) — left as a follow-up; for now
  // this returns everyone active for the sub-service, nearest-first is a TODO.
  async findForSubService(subServiceId: string) {
    return this.prisma.provider.findMany({
      where: {
        status: 'ACTIVE',
        subServices: { some: { subServiceId } },
      },
      include: { user: { select: { fullName: true, city: true } } },
      orderBy: { averageRating: 'desc' },
    });
  }
}
