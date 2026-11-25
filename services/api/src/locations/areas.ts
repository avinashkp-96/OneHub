import { distanceKm } from './geo';

// The areas the app serves, for people who pick their area instead of using
// GPS, and to name a GPS position. A fixed list because there is no geocoding
// service; extend it as the service grows beyond Kochi.
export interface ServiceArea {
  name: string;
  latitude: number;
  longitude: number;
}

export const SERVICE_AREAS: readonly ServiceArea[] = [
  { name: 'Edappally', latitude: 10.0261, longitude: 76.3125 },
  { name: 'Kakkanad', latitude: 10.0159, longitude: 76.3419 },
  { name: 'Kadavanthra', latitude: 9.9667, longitude: 76.2999 },
  { name: 'Vyttila', latitude: 9.9658, longitude: 76.3185 },
  { name: 'Palarivattom', latitude: 10.0036, longitude: 76.3061 },
  { name: 'Kaloor', latitude: 9.9986, longitude: 76.2913 },
  { name: 'Ernakulam South', latitude: 9.9689, longitude: 76.2891 },
  { name: 'Fort Kochi', latitude: 9.9658, longitude: 76.2421 },
  { name: 'Thrippunithura', latitude: 9.9439, longitude: 76.3463 },
  { name: 'Kalamassery', latitude: 10.0527, longitude: 76.3180 },
  { name: 'Aluva', latitude: 10.1076, longitude: 76.3516 },
];

// A GPS position further than this from every area is not named after one.
export const AREA_NAME_RADIUS_KM = 8;
export const UNNAMED_PLACE = 'Your location';

// The area a position is in (the nearest one within AREA_NAME_RADIUS_KM), or
// UNNAMED_PLACE when it is outside them all.
export function placeName(latitude: number, longitude: number): string {
  let best: { name: string; km: number } | null = null;
  for (const area of SERVICE_AREAS) {
    const km = distanceKm({ latitude, longitude }, area)!;
    if (km <= AREA_NAME_RADIUS_KM && (!best || km < best.km)) best = { name: area.name, km };
  }
  return best?.name ?? UNNAMED_PLACE;
}
