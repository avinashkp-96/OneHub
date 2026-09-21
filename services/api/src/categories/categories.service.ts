import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { UpsertCategoryDto } from './dto/upsert-category.dto';
import { UpsertSubServiceDto } from './dto/upsert-sub-service.dto';

@Injectable()
export class CategoriesService {
  constructor(private readonly prisma: PrismaService) {}

  listActive() {
    return this.prisma.category.findMany({ where: { active: true } });
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
