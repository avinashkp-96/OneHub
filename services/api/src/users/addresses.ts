import { placeName } from '../locations/areas';
import { AddressDto } from './dto/address.dto';

// The stored form of an address, also what a request keeps a copy of.
export type AddressFields = {
  label: string;
  house: string;
  street: string;
  landmark: string | null;
  pincode: string;
  city: string;
  latitude: number;
  longitude: number;
};

// Everything but the id: what a request copies.
export const ADDRESS_FIELDS_SELECT = {
  label: true,
  house: true,
  street: true,
  landmark: true,
  pincode: true,
  city: true,
  latitude: true,
  longitude: true,
} as const;

export const ADDRESS_SELECT = { id: true, ...ADDRESS_FIELDS_SELECT } as const;

// The parts of a stored address, without its id, owner or dates.
export function addressCopy(a: AddressFields): AddressFields {
  return {
    label: a.label,
    house: a.house,
    street: a.street,
    landmark: a.landmark,
    pincode: a.pincode,
    city: a.city,
    latitude: a.latitude,
    longitude: a.longitude,
  };
}

// Trims every part, names the area from the map position when none is given,
// and defaults the label to Home.
export function addressFields(dto: AddressDto): AddressFields {
  return {
    label: dto.label?.trim() || 'Home',
    house: dto.house.trim(),
    street: dto.street.trim(),
    landmark: dto.landmark?.trim() || null,
    pincode: dto.pincode,
    city: dto.city?.trim() || placeName(dto.latitude, dto.longitude),
    latitude: dto.latitude,
    longitude: dto.longitude,
  };
}
