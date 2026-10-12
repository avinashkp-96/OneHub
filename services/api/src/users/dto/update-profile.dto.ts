import { IsEmail, IsOptional, IsString } from 'class-validator';

// Only these three fields may be changed through PATCH /users/me. The global
// ValidationPipe runs with `whitelist: true`, which strips everything else
// (role, passwordHash, mobile, ...) before it can reach the database.
export class UpdateProfileDto {
  @IsOptional()
  @IsString()
  fullName?: string;

  @IsOptional()
  @IsEmail()
  email?: string;

  @IsOptional()
  @IsString()
  profilePhotoUrl?: string;
}
