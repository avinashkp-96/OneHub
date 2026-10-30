import { ArrayNotEmpty, IsArray, IsInt, IsNumber, IsOptional, IsString, Max, MaxLength, Min, MinLength } from 'class-validator';

// docx 5.2 "Profile & Service Mapping": the business details a provider may
// change after signup through PATCH /providers/me. The global ValidationPipe
// runs with `whitelist: true`, so status, rating and certification can never
// be set through this route.
export class UpdateBusinessDto {
  @IsOptional()
  @IsString()
  @MinLength(2)
  @MaxLength(80)
  businessName?: string;

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

  // A link, as at signup: there is no file upload yet. A new one marks the ID
  // proof as awaiting review.
  @IsOptional()
  @IsString()
  @MinLength(5)
  @MaxLength(500)
  idProofUrl?: string;

  // Bank account or UPI id for payouts. Stored as given, only ever returned
  // masked. An empty string clears it.
  @IsOptional()
  @IsString()
  @MaxLength(120)
  bankOrUpiDetails?: string;
}
