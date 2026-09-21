import { IsString } from 'class-validator';

// docx 2.2 / 2.4 — Login (Customer and Provider share the same shape)
export class LoginDto {
  @IsString()
  mobileOrEmail: string;

  @IsString()
  password: string;
}

export class RequestOtpDto {
  @IsString()
  mobile: string;
}

export class ResetPasswordDto {
  @IsString()
  mobileOrEmail: string;

  @IsString()
  otp: string;

  @IsString()
  newPassword: string;

  @IsString()
  confirmNewPassword: string;
}
