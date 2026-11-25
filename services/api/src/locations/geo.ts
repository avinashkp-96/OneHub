export interface Coordinates {
  latitude: number | null;
  longitude: number | null;
}

// Straight-line (haversine) distance in km, to one decimal; null when either
// point is missing a coordinate.
export function distanceKm(a: Coordinates, b: Coordinates): number | null {
  if (a.latitude == null || a.longitude == null || b.latitude == null || b.longitude == null) {
    return null;
  }
  const rad = (deg: number) => (deg * Math.PI) / 180;
  const dLat = rad(b.latitude - a.latitude);
  const dLon = rad(b.longitude - a.longitude);
  const h =
    Math.sin(dLat / 2) ** 2 + Math.cos(rad(a.latitude)) * Math.cos(rad(b.latitude)) * Math.sin(dLon / 2) ** 2;
  const km = 2 * 6371 * Math.asin(Math.sqrt(h));
  return Math.round(km * 10) / 10;
}

// Nearest first; anything without a distance goes last, keeping its order.
export function byDistance<T extends { distanceKm: number | null }>(a: T, b: T) {
  return (a.distanceKm ?? Infinity) - (b.distanceKm ?? Infinity);
}
