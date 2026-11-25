import { BadRequestException, Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { UpdateBusinessDto } from './dto/update-business.dto';
import { byDistance, distanceKm } from '../locations/geo';

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
  user: {
    select: {
      fullName: true,
      mobile: true,
      email: true,
      profilePhotoUrl: true,
      city: true,
      latitude: true,
      longitude: true,
    },
  },
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
  user: {
    fullName: string;
    mobile: string;
    email: string | null;
    profilePhotoUrl: string | null;
    city: string | null;
    latitude: number | null;
    longitude: number | null;
  };
  subServices: { subService: { id: string; name: string; category: { id: string; name: string } } }[];
};

@Injectable()
export class ProvidersService {
  constructor(private readonly prisma: PrismaService) {}

  // docx 4.2 "Search" results list + 4.3 "Provider Selection". Filters to
  // providers offering the given sub-service, best rated first. Given the
  // customer's position, each provider gets a distanceKm, providers whose
  // coverage radius does not reach the customer are left out, and the list is
  // nearest first (providers with no saved location last). The distance is
  // worked out in memory, fine at MVP size; move it into the query (PostGIS)
  // when the provider count grows.
  //
  // This route is public, so it selects fields explicitly: the full provider
  // row also holds the ID proof URL and bank/UPI details. Provider
  // coordinates are read for the distance but never returned.
  async findForSubService(subServiceId: string, near?: { latitude: number; longitude: number }) {
    const rows = await this.prisma.provider.findMany({
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
        user: { select: { fullName: true, city: true, latitude: true, longitude: true } },
      },
      orderBy: { averageRating: 'desc' },
    });
    const listed = rows.map(({ user: { latitude, longitude, ...user }, ...p }) => ({
      ...p,
      user,
      distanceKm: near ? distanceKm(near, { latitude, longitude }) : null,
    }));
    if (!near) return listed;
    return listed.filter((p) => p.distanceKm === null || p.distanceKm <= p.coverageRadiusKm).sort(byDistance);
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
    if (ids) await this.assertKnown(ids);

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

  // Every service must exist. They may come from any number of categories.
  private async assertKnown(ids: string[]) {
    const found = await this.prisma.subService.findMany({
      where: { id: { in: ids } },
      select: { id: true },
    });
    if (found.length !== ids.length) throw new BadRequestException('unknown sub-service');
  }
}

// Flattens the nested Prisma shape into what the app shows: the categories
// the provider works in (in the order their services come) and the services,
// each with its category id. `category` is the first of them, kept for older
// app builds.
function toBusiness(row: BusinessRow) {
  const services = row.subServices.map((s) => s.subService);
  const categories = [...new Map(services.map((s) => [s.category.id, s.category])).values()];
  return {
    id: row.id,
    businessName: row.businessName ?? row.user.fullName,
    mobile: row.user.mobile,
    email: row.user.email,
    profilePhotoUrl: row.user.profilePhotoUrl,
    status: row.status,
    yearsExperience: row.yearsExperience,
    coverageRadiusKm: row.coverageRadiusKm,
    location:
      row.user.latitude != null && row.user.longitude != null
        ? { city: row.user.city, latitude: row.user.latitude, longitude: row.user.longitude }
        : null,
    category: categories[0] ?? null,
    categories,
    subServices: services.map(({ id, name, category }) => ({ id, name, categoryId: category.id })),
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
