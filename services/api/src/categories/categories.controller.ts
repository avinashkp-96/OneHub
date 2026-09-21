import { Body, Controller, Get, Param, Patch, Post, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { RolesGuard } from '../auth/roles.guard';
import { Roles } from '../auth/roles.decorator';
import { CategoriesService } from './categories.service';
import { UpsertCategoryDto } from './dto/upsert-category.dto';
import { UpsertSubServiceDto } from './dto/upsert-sub-service.dto';

// docx 3.1/3.2 (admin-only writes) + 4.1 (public browse for the customer dashboard)
@Controller('categories')
export class CategoriesController {
  constructor(private readonly categories: CategoriesService) {}

  @Get()
  list() {
    return this.categories.listActive();
  }

  @Get(':id/sub-services')
  subServices(@Param('id') id: string) {
    return this.categories.listSubServices(id);
  }

  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('ADMIN')
  @Post()
  create(@Body() dto: UpsertCategoryDto) {
    return this.categories.upsertCategory(dto);
  }

  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('ADMIN')
  @Patch(':id')
  update(@Param('id') id: string, @Body() dto: UpsertCategoryDto) {
    return this.categories.upsertCategory(dto, id);
  }

  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('ADMIN')
  @Post(':id/sub-services')
  addSubService(@Param('id') categoryId: string, @Body() dto: UpsertSubServiceDto) {
    return this.categories.upsertSubService({ ...dto, categoryId });
  }
}
