import {
  ArrayMaxSize,
  ArrayMinSize,
  IsArray,
  IsDateString,
  IsOptional,
  IsString,
  Matches,
  MaxLength,
} from 'class-validator';
import { PHOTO_NAME, PHOTO_URL_PREFIX } from '../../uploads/uploads.service';

export const REQUIREMENT_PHOTOS_MAX = 5;
const UPLOADED_PHOTO = new RegExp(`^${PHOTO_URL_PREFIX.replace(/\//g, '\\/')}${PHOTO_NAME.source.slice(1)}`);

export const REQUIREMENT_TITLE_MAX = 60;

// docx 4.3
export class PostRequirementDto {
  @IsString()
  subServiceId: string;

  // One of the customer's saved addresses: where the job is.
  @IsString()
  addressId: string;

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

  // Photos uploaded through POST /uploads/photo, up to five. Links elsewhere
  // are refused so a request can only show files this API holds.
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(REQUIREMENT_PHOTOS_MAX)
  @Matches(UPLOADED_PHOTO, { each: true, message: 'photos must be uploaded through the app' })
  photoUrls?: string[];

  @IsOptional()
  @IsDateString()
  preferredAt?: string;

  @IsArray()
  @ArrayMinSize(1)
  providerIds: string[];
}
