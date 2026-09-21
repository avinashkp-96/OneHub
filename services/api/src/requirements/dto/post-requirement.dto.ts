import { ArrayMinSize, IsArray, IsDateString, IsOptional, IsString } from 'class-validator';

// docx 4.3
export class PostRequirementDto {
  @IsString()
  subServiceId: string;

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
