import { BadRequestException, Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { UpdateBusinessDto } from './dto/update-business.dto';

// Fields read for the provider's own profile. The ID proof link and bank/UPI
// details are read only to work out "on file" and a masked value: toBusiness
// never returns them raw, even to the owner.
const BUSINESS_SELECT = {
  id: true,
  businessName: true,
  yearsExperience: true,
  coverageRadiusKm: true,
  status: true,
  idProofUrl: true,
  idProofNeedsReview: true,
  bankOrUpiDetails: true,
  user: { select: { fullName: true, mobile: true, email: true, profilePhotoUrl: true } },
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
  status: string;
  idProofUrl: string | null;
  idProofNeedsReview: boolean;
  bankOrUpiDetails: string | null;
  user: { fullName: string; mobile: string; email: string | null; profilePhotoUrl: string | null };
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
  //
  // A different ID proof link marks it for review (docx 5.2: "re-upload
  // triggers re-verification"). The provider stays ACTIVE, because there is
  // no approval flow yet and a PENDING provider cannot log in; switch to
  // re-verification once admins can approve. An empty payout value clears it.
  async updateMine(userId: string, dto: UpdateBusinessDto) {
    const ids = dto.subServiceIds ? [...new Set(dto.subServiceIds)] : undefined;
    if (ids) await this.assertOneCategory(ids);

    const idProofUrl = dto.idProofUrl?.trim();
    let idProofChanged = false;
    if (idProofUrl !== undefined) {
      const current = await this.prisma.provider.findUniqueOrThrow({
        where: { userId },
        select: { idProofUrl: true },
      });
      idProofChanged = idProofUrl !== current.idProofUrl;
    }
    const payout = dto.bankOrUpiDetails?.trim();

    const row = await this.prisma.provider.update({
      where: { userId },
      data: {
        businessName: dto.businessName?.trim(),
        yearsExperience: dto.yearsExperience,
        coverageRadiusKm: dto.coverageRadiusKm,
        ...(idProofChanged ? { idProofUrl, idProofNeedsReview: true } : {}),
        ...(payout !== undefined ? { bankOrUpiDetails: payout === '' ? null : payout } : {}),
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
    businessName: row.businessName ?? row.user.fullName,
    mobile: row.user.mobile,
    email: row.user.email,
    profilePhotoUrl: row.user.profilePhotoUrl,
    status: row.status,
    yearsExperience: row.yearsExperience,
    coverageRadiusKm: row.coverageRadiusKm,
    category: services[0]?.category ?? null,
    subServices: services.map(({ id, name }) => ({ id, name })),
    idProofOnFile: !!row.idProofUrl,
    idProofNeedsReview: row.idProofNeedsReview,
    bankOrUpiMasked: maskPayout(row.bankOrUpiDetails),
  };
}

// Payout details are only ever shown masked. A UPI id keeps its first two
// characters and its handle ("rajesh@okhdfc" -> "ra••••@okhdfc"); anything
// else (an account number, or account and IFSC) keeps its last four
// characters ("•••• 4321").
export function maskPayout(value: string | null): string | null {
  const v = value?.trim();
  if (!v) return null;
  const at = v.indexOf('@');
  if (at > 0) return `${v.slice(0, Math.min(2, at))}••••${v.slice(at)}`;
  const compact = v.replace(/\s+/g, '');
  return compact.length <= 4 ? '••••' : `•••• ${compact.slice(-4)}`;
}
