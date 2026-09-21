import { IsArray, IsEmail, IsNumber, IsOptional, IsString, Matches, MinLength } from 'class-validator';

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

  @IsString()
  categoryId: string;

  @IsArray()
  subServiceIds: string[];

  @IsOptional()
  @IsNumber()
  yearsExperience?: number;

  @IsNumber()
  coverageRadiusKm: number;

  @IsNumber()
  latitude: number;

  @IsNumber()
  longitude: number;

  @IsOptional()
  @IsString()
  profilePhotoUrl?: string;

  @IsString()
  idProofUrl: string;

  @IsOptional()
  @IsString()
  bankOrUpiDetails?: string;
}
