import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { UpsertCategoryDto } from './dto/upsert-category.dto';
import { UpsertSubServiceDto } from './dto/upsert-sub-service.dto';

@Injectable()
export class CategoriesService {
  constructor(private readonly prisma: PrismaService) {}

  // Each category carries `providerCount`: how many ACTIVE providers offer at
  // least one of its sub-services, the same providers search can return. A
  // provider offering several services in one category counts once.
  async listActive() {
    const [categories, offered] = await Promise.all([
      this.prisma.category.findMany({ where: { active: true }, orderBy: { name: 'asc' } }),
      this.prisma.providerSubService.findMany({
        where: { provider: { status: 'ACTIVE' } },
        select: { providerId: true, subService: { select: { categoryId: true } } },
      }),
    ]);
    const providersByCategory = new Map<string, Set<string>>();
    for (const row of offered) {
      const categoryId = row.subService.categoryId;
      const providers = providersByCategory.get(categoryId) ?? new Set<string>();
      providers.add(row.providerId);
      providersByCategory.set(categoryId, providers);
    }
    return categories.map((c) => ({
      ...c,
      providerCount: providersByCategory.get(c.id)?.size ?? 0,
    }));
  }

  listSubServices(categoryId: string) {
    return this.prisma.subService.findMany({ where: { categoryId } });
  }

  upsertCategory(dto: UpsertCategoryDto, id?: string) {
    if (id) {
      return this.prisma.category.update({ where: { id }, data: dto });
    }
    return this.prisma.category.create({ data: { ...dto, active: dto.active ?? true } });
  }

  upsertSubService(dto: UpsertSubServiceDto & { categoryId: string }) {
    return this.prisma.subService.create({
      data: {
        name: dto.name,
        categoryId: dto.categoryId,
        description: dto.description,
        suggestedMinPrice: dto.suggestedMinPrice,
        suggestedMaxPrice: dto.suggestedMaxPrice,
      },
    });
  }
}
