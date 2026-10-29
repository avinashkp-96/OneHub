# OneHub

Two-sided service marketplace connecting customers with local service providers (MVP scope: electricians and plumbers). Built from `OneHub_Requirements.docx`.

## Layout

```
services/api/          NestJS + TypeScript + Prisma backend, shared by all three clients
apps/customer-app/      Flutter — customer experience
apps/provider-app/      Flutter — provider experience
apps/admin-web/          React + TypeScript admin panel (categories, provider verification)
packages/shared-flutter/ Shared Flutter models + API client used by both mobile apps
```

## Status

The Flutter apps (`customer-app`, `provider-app`, `shared-flutter`) are
installed, tested, and manually verified running as of 2026-09-25 —
`flutter test` and `flutter analyze` pass clean across all three, and both
apps render correctly via `flutter run -d web-server`. Customer login and
signup match `docs/onehub-signup-style-guide.pdf` exactly (a formal style
guide with exact hex/rgba/px tokens — the authoritative design source,
superseding an earlier CSS-extraction reading of the same Figma file where
they differ) — see the Design section in `CLAUDE.md` for the full retheme
history and what is/isn't rebuilt to match it.
The backend has been run end to end against a local Postgres since
2026-10-29, with both apps logging in and working against it. admin-web is
still source-only. See `CLAUDE.md` for the full list of gaps.

## Getting started

### 1. Database

Any PostgreSQL 16 works. With Docker:

```bash
docker run -d --name onehub-db -p 5432:5432 -e POSTGRES_USER=onehub -e POSTGRES_PASSWORD=onehub -e POSTGRES_DB=onehub postgres:16
```

Or install PostgreSQL and create a database and user that match
`DATABASE_URL` in `.env`. The database must use UTF-8 (Docker's image does by
default). A Windows install can default to WIN1252, which cannot store `₹` or
`★`, and notifications that contain them are then silently dropped. Create it
with `CREATE DATABASE onehub ENCODING 'UTF8' TEMPLATE template0;` to be sure.

### 2. API

```bash
cd services/api
cp .env.example .env   # set DATABASE_URL and a real JWT_SECRET
npm install
npx prisma migrate deploy   # creates the tables from prisma/migrations
npm run db:seed             # demo data, see below
npm run start:dev           # http://localhost:3000/api/v1
```

Use `npm run prisma:migrate` instead of `migrate deploy` when you change
`schema.prisma`; it creates a new migration for the change.

`.env` settings: `DATABASE_URL`, `JWT_SECRET` (the API refuses the
`change-me` placeholder in production), `JWT_EXPIRES_IN`, `OTP_TTL_SECONDS`,
`CONTACT_UNLOCK_PRICE_INR`, and `CORS_ORIGINS`: exact browser origins allowed
to call the API, comma-separated. Outside production, localhost and
private-network origins are allowed anyway; in production only this list is.

### 3. Demo data

`npm run db:seed` adds two categories (Electrician, Plumber) with four
services each, one customer, two providers that skip verification, and one
open request sent to the electrician. It is safe to re-run. The logins are
customer `9000000001` and providers `9000000002` (electrician) and
`9000000003` (plumber); all use `DEMO_PASSWORD` from
`services/api/src/dev/demo-data.ts`. It refuses to run with
`NODE_ENV=production`. Never seed a real database.

### 4. Apps

The Flutter apps read the API address from `API_BASE_URL` at build time. The
default, `http://10.0.2.2:3000/api/v1`, is the Android emulator's address for
the host machine. For the web build on the same machine:

```bash
cd apps/customer-app && flutter pub get && flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:3000/api/v1
cd apps/provider-app && flutter pub get && flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:3000/api/v1
```

On web, login needs a secure page (`localhost` or `https`), because the token
is stored with the browser's crypto API. A phone on the same Wi-Fi therefore
needs the apps served over https, not plain `http://<pc-ip>`.

```bash
# Admin web
cd apps/admin-web
npm install
npm run dev
```

## What's implemented vs. stubbed

Backend (routes + Prisma-backed service logic): customer/provider sign-up
with OTP, login, forgot/reset password, category and sub-service CRUD,
provider search by sub-service, posting a requirement, accept/reject, initial
and refined bids, contact-unlock payment record, provider confirmation, job
completion, ratings (with a placeholder certification threshold — see
`src/ratings/ratings.service.ts`), notifications, and subscription plans.

Mobile UI wired to the backend, end to end: Sign Up (with OTP) + Login +
Forgot/Reset Password for both apps, dashboard shells, and on the customer
app Category browsing → Post a Requirement → My Requests → Bid List →
Rate the provider, matched on the provider app by Incoming Requests →
Price Range & Contact Unlock → Active Jobs → Mark as Completed. That's the
full request-to-rating loop from the requirements doc, start to finish.

Not implemented yet: real SMS/OTP delivery (the OTP flow works end to end,
but the backend returns the code in the response instead of sending it —
see `OtpService`), a real payment gateway for the ₹50 contact-unlock and
subscription charges, push notification delivery, nearest-first/radius
provider ranking (provider search currently returns every active provider
for a sub-service, sorted by rating only), the location selector and
free-text search bar from docx 4.1/4.2 (browsing is grid-only for now, no
search/filter/sort), real file upload for provider signup's profile
photo/ID proof (currently plain text fields for a document URL), GPS capture
during provider signup (coverage area is hardcoded to lat/lng 0,0 pending
location permission handling), the admin provider-verification queue, and
Bricolage Grotesque/DM Sans as actual bundled assets on mobile (works on
web via a stylesheet link; Android/iOS currently fall back to the platform
default font — see the Design section in `CLAUDE.md`). Iconly icons, by contrast,
*are* bundled as real font assets (`packages/shared-flutter/assets/fonts/`)
since the pub packages for them don't compile on this Flutter version —
see `OneHubIcons`' doc comment.
