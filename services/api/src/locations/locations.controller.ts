import { Controller, Get, Query } from '@nestjs/common';
import { Type } from 'class-transformer';
import { IsLatitude, IsLongitude } from 'class-validator';
import { placeName, SERVICE_AREAS } from './areas';

export class PlaceQueryDto {
  @Type(() => Number)
  @IsLatitude()
  latitude: number;

  @Type(() => Number)
  @IsLongitude()
  longitude: number;
}

// Public: provider signup picks a location before the account exists, and
// neither route returns anything about a user.
@Controller('locations')
export class LocationsController {
  @Get('areas')
  areas() {
    return SERVICE_AREAS;
  }

  // Names a GPS position, so the app can show "Edappally" rather than numbers.
  @Get('place')
  place(@Query() query: PlaceQueryDto) {
    return { city: placeName(query.latitude, query.longitude) };
  }
}
