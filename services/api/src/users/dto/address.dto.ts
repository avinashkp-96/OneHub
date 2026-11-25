import { IsLatitude, IsLongitude, IsOptional, IsString, Matches, MaxLength } from 'class-validator';

const NOT_BLANK = /\S/;

// One saved address: what a provider needs to find the place, plus a map
// position (GPS or a picked area) for distances. Used at customer signup and
// by POST /users/me/addresses.
export class AddressDto {
  // "Home", "Office"...; Home when left out.
  @IsOptional()
  @IsString()
  @MaxLength(30)
  label?: string;

  // House or flat number and building.
  @IsString()
  @Matches(NOT_BLANK, { message: 'house or flat is required' })
  @MaxLength(120)
  house: string;

  // Street and area.
  @IsString()
  @Matches(NOT_BLANK, { message: 'street and area are required' })
  @MaxLength(120)
  street: string;

  @IsOptional()
  @IsString()
  @MaxLength(120)
  landmark?: string;

  @Matches(/^[1-9][0-9]{5}$/, { message: 'pincode must be a 6-digit PIN code' })
  pincode: string;

  // The area's name; worked out from the map position when left out.
  @IsOptional()
  @IsString()
  @MaxLength(80)
  city?: string;

  @IsLatitude()
  latitude: number;

  @IsLongitude()
  longitude: number;
}
