import { Controller, Get, Query } from '@nestjs/common';
import { Type } from 'class-transformer';
import { IsLatitude, IsLongitude, IsOptional, IsString } from 'class-validator';
import { ProvidersService } from './providers.service';

export class ProvidersQueryDto {
  @IsString()
  subServiceId: string;

  // The customer's position; both or neither.
  @IsOptional()
  @Type(() => Number)
  @IsLatitude()
  latitude?: number;

  @IsOptional()
  @Type(() => Number)
  @IsLongitude()
  longitude?: number;
}

@Controller('providers')
export class ProvidersController {
  constructor(private readonly providers: ProvidersService) {}

  @Get()
  search(@Query() query: ProvidersQueryDto) {
    const near =
      query.latitude !== undefined && query.longitude !== undefined
        ? { latitude: query.latitude, longitude: query.longitude }
        : undefined;
    return this.providers.findForSubService(query.subServiceId, near);
  }
}
