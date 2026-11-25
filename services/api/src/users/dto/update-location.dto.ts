import { IsLatitude, IsLongitude, IsOptional, IsString, MaxLength } from 'class-validator';

// PUT /users/me/location: where the customer wants work done, or where the
// provider's business is. Left out or blank, the city is named from the
// coordinates.
export class UpdateLocationDto {
  @IsLatitude()
  latitude: number;

  @IsLongitude()
  longitude: number;

  @IsOptional()
  @IsString()
  @MaxLength(80)
  city?: string;
}
