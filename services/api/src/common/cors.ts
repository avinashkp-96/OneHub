import { CorsOptions } from '@nestjs/common/interfaces/external/cors-options.interface';

// Which browser origins may call the API. Only browsers enforce this (the
// Flutter web builds and admin-web); the installed mobile apps and curl send
// no Origin header and are always let through.
//
// - CORS_ORIGINS: comma-separated exact origins that are always allowed, e.g.
//   "https://admin.onehub.example". This is the only list used in production.
// - Outside production, localhost and private-network addresses (10.x,
//   172.16-31.x, 192.168.x) on any port are allowed too, so the web previews
//   work on this machine and from a phone on the same Wi-Fi.
const LOCAL_ORIGIN =
  /^https?:\/\/(localhost|127\.0\.0\.1|\[::1\]|10(\.\d{1,3}){3}|192\.168(\.\d{1,3}){2}|172\.(1[6-9]|2\d|3[01])(\.\d{1,3}){2})(:\d+)?$/;

type CorsEnv = { CORS_ORIGINS?: string; NODE_ENV?: string };

export function isOriginAllowed(origin: string, env: CorsEnv): boolean {
  const listed = (env.CORS_ORIGINS ?? '')
    .split(',')
    .map((o) => o.trim())
    .filter(Boolean);
  if (listed.includes(origin)) return true;
  return env.NODE_ENV !== 'production' && LOCAL_ORIGIN.test(origin);
}

export function corsOptions(env: CorsEnv = process.env): CorsOptions {
  return {
    origin: (origin, callback) => callback(null, !origin || isOriginAllowed(origin, env)),
    methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE'],
    allowedHeaders: ['Authorization', 'Content-Type'],
  };
}
