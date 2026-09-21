import { IsBoolean, IsOptional, IsString } from 'class-validator';

// docx 3.1
export class UpsertCategoryDto {
  @IsString()
  name: string;

  @IsOptional()
  @IsString()
  iconUrl?: string;

  @IsOptional()
  @IsString()
  description?: string;

  @IsOptional()
  @IsBoolean()
  active?: boolean;
}
