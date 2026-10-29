import { BadRequestException, Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { UpdateBusinessDto } from './dto/update-business.dto';

// Fields the provider sees about their own business. Selected explicitly,
// like the public search, so the response never carries the ID proof URL or
// bank/UPI details even to the owner.
const BUSINESS_SELECT = {
  id: true,
  businessName: true,
  yearsExperience: true,
  coverageRadiusKm: true,
  subServices: {
    select: {
      subService: {
        select: { id: true, name: true, category: { select: { id: true, name: true } } },
      },
    },
  },
} as const;

type BusinessRow = {
  id: string;
  businessName: string | null;
  yearsExperience: number | null;
  coverageRadiusKm: number;
  subServices: { subService: { id: string; name: string; category: { id: string; name: string } } }[];
};

@Injectable()
export class ProvidersService {
  constructor(private readonly prisma: PrismaService) {}

  // docx 4.2 "Search" results list + 4.3 "Provider Selection". Filters to
  // providers offering the given sub-service. Distance/radius filtering needs
  // a geo query (PostGIS or a haversine calc) — left as a follow-up; for now
  // this returns everyone active for the sub-service, nearest-first is a TODO.
  //
  // This route is public, so it selects fields explicitly: the full provider
  // row also holds the ID proof URL and bank/UPI details.
  async findForSubService(subServiceId: string) {
    return this.prisma.provider.findMany({
      where: {
        status: 'ACTIVE',
        subServices: { some: { subServiceId } },
      },
      select: {
        id: true,
        businessName: true,
        yearsExperience: true,
        coverageRadiusKm: true,
        averageRating: true,
        ratingCount: true,
        certified: true,
        user: { select: { fullName: true, city: true } },
      },
      orderBy: { averageRating: 'desc' },
    });
  }

  // docx 5.2. Always looked up by the caller's own user id, so a provider can
  // only ever read their own business details.
  async getMine(userId: string) {
    const row = await this.prisma.provider.findUniqueOrThrow({
      where: { userId },
      select: BUSINESS_SELECT,
    });
    return toBusiness(row as BusinessRow);
  }

  // docx 5.2. Updates the caller's own provider row only. A new service list
  // replaces the old one in the same nested write, so it is all or nothing.
  async updateMine(userId: string, dto: UpdateBusinessDto) {
    const ids = dto.subServiceIds ? [...new Set(dto.subServiceIds)] : undefined;
    if (ids) await this.assertOneCategory(ids);

    const row = await this.prisma.provider.update({
      where: { userId },
      data: {
        yearsExperience: dto.yearsExperience,
        coverageRadiusKm: dto.coverageRadiusKm,
        subServices: ids
          ? { deleteMany: {}, create: ids.map((subServiceId) => ({ subServiceId })) }
          : undefined,
      },
      select: BUSINESS_SELECT,
    });
    return toBusiness(row as BusinessRow);
  }

  private async assertOneCategory(ids: string[]) {
    const found = await this.prisma.subService.findMany({
      where: { id: { in: ids } },
      select: { id: true, categoryId: true },
    });
    if (found.length !== ids.length) throw new BadRequestException('unknown sub-service');
    if (new Set(found.map((s) => s.categoryId)).size > 1) {
      throw new BadRequestException('sub-services must all belong to one category');
    }
  }
}

// Flattens the nested Prisma shape into what the app shows: one category
// (a provider offers services from a single category) and its services.
function toBusiness(row: BusinessRow) {
  const services = row.subServices.map((s) => s.subService);
  return {
    id: row.id,
    businessName: row.businessName,
    yearsExperience: row.yearsExperience,
    coverageRadiusKm: row.coverageRadiusKm,
    category: services[0]?.category ?? null,
    subServices: services.map(({ id, name }) => ({ id, name })),
  };
}
