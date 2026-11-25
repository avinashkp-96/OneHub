import { Type } from 'class-transformer';
import { IsDefined, IsEmail, IsOptional, IsString, Matches, MinLength, ValidateNested } from 'class-validator';
import { AddressDto } from '../../users/dto/address.dto';

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

  // The customer's first saved address (Home), where providers come to.
  // Its map position also becomes the account's location.
  @IsDefined()
  @ValidateNested()
  @Type(() => AddressDto)
  address: AddressDto;
}
