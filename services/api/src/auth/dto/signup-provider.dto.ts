import { ArrayNotEmpty, IsArray, IsEmail, IsLatitude, IsLongitude, IsNumber, IsOptional, IsString, Matches, MaxLength, MinLength } from 'class-validator';

// docx 2.3 Provider — Sign Up
export class SignupProviderDto {
  @IsString()
  fullNameOrBusinessName: string;

  @Matches(/^[0-9]{10}$/, { message: 'mobile must be exactly 10 digits' })
  mobile: string;

  @IsString()
  otp: string;

  @IsOptional()
  @IsEmail()
  email?: string;

  @MinLength(6)
  password: string;

  @IsString()
  confirmPassword: string;

  // Older app builds sent the one category picked; a provider may now offer
  // services from several, so the services alone say which.
  @IsOptional()
  @IsString()
  categoryId?: string;

  @IsArray()
  @ArrayNotEmpty({ message: 'choose at least one service you offer' })
  @IsString({ each: true })
  subServiceIds: string[];

  @IsOptional()
  @IsNumber()
  yearsExperience?: number;

  @IsNumber()
  coverageRadiusKm: number;

  // Where the business is, from GPS or a picked area. Distances to customers
  // and the coverage radius are measured from here.
  @IsLatitude()
  latitude: number;

  @IsLongitude()
  longitude: number;

  // The area's name; named from the coordinates when left out.
  @IsOptional()
  @IsString()
  @MaxLength(80)
  city?: string;

  @IsOptional()
  @IsString()
  profilePhotoUrl?: string;

  @IsString()
  idProofUrl: string;

  @IsOptional()
  @IsString()
  bankOrUpiDetails?: string;
}
