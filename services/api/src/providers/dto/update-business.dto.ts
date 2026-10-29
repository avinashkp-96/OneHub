import { ArrayNotEmpty, IsArray, IsInt, IsNumber, IsOptional, IsString, Max, Min } from 'class-validator';

// docx 5.2 "Profile & Service Mapping": the business details a provider may
// change after signup through PATCH /providers/me. The global ValidationPipe
// runs with `whitelist: true`, so status, rating, certification, ID proof and
// bank details can never be set through this route.
export class UpdateBusinessDto {
  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(60)
  yearsExperience?: number;

  @IsOptional()
  @IsNumber()
  @Min(1)
  @Max(100)
  coverageRadiusKm?: number;

  // Replaces the whole set. All ids must belong to one category, checked in
  // ProvidersService because it needs the database.
  @IsOptional()
  @IsArray()
  @ArrayNotEmpty()
  @IsString({ each: true })
  subServiceIds?: string[];
}
