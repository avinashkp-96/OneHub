import { IsEmail, IsLatitude, IsLongitude, IsOptional, IsString, Matches, MinLength } from 'class-validator';

// docx 2.1 Customer — Sign Up
export class SignupCustomerDto {
  @IsString()
  fullName: string;

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
  city: string;

  @IsOptional()
  @IsLatitude()
  latitude?: number;

  @IsOptional()
  @IsLongitude()
  longitude?: number;
}
