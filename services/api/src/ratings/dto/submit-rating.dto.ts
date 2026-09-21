import { IsInt, IsOptional, IsString, Max, Min } from 'class-validator';

// docx 4.6
export class SubmitRatingDto {
  @IsString()
  requirementId: string;

  @IsString()
  providerId: string;

  @IsInt()
  @Min(1)
  @Max(5)
  stars: number;

  @IsOptional()
  @IsString()
  feedback?: string;
}
