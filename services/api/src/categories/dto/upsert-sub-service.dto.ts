import { IsNumber, IsOptional, IsString } from 'class-validator';

// docx 3.2
export class UpsertSubServiceDto {
  @IsString()
  name: string;

  @IsOptional()
  categoryId?: string;

  @IsOptional()
  @IsString()
  description?: string;

  @IsOptional()
  @IsNumber()
  suggestedMinPrice?: number;

  @IsOptional()
  @IsNumber()
  suggestedMaxPrice?: number;
}
