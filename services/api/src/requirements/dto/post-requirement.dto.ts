import { ArrayMinSize, IsArray, IsDateString, IsOptional, IsString, Matches, MaxLength } from 'class-validator';

export const REQUIREMENT_TITLE_MAX = 60;

// docx 4.3
export class PostRequirementDto {
  @IsString()
  subServiceId: string;

  // A short headline for the request, shown above the description in both
  // apps' lists.
  @IsString()
  @Matches(/\S/, { message: 'title must not be blank' })
  @MaxLength(REQUIREMENT_TITLE_MAX)
  title: string;

  @IsString()
  description: string;

  @IsOptional()
  @IsString()
  voiceTranscript?: string;

  @IsOptional()
  @IsArray()
  photoUrls?: string[];

  @IsOptional()
  @IsDateString()
  preferredAt?: string;

  @IsArray()
  @ArrayMinSize(1)
  providerIds: string[];
}
