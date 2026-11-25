import { IsBoolean, IsOptional } from 'class-validator';

// PATCH /users/me/settings: any of the switches, each true or false. Which
// ones a user may set depends on their role (see settings.ts); the validation
// pipe strips anything not listed here.
export class UpdateSettingsDto {
  @IsOptional()
  @IsBoolean()
  requestUpdates?: boolean;

  @IsOptional()
  @IsBoolean()
  reminders?: boolean;

  @IsOptional()
  @IsBoolean()
  newRequests?: boolean;

  @IsOptional()
  @IsBoolean()
  jobUpdates?: boolean;

  @IsOptional()
  @IsBoolean()
  offers?: boolean;
}
