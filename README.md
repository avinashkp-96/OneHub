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
installed, tested, and manually verified running as of 2026-09-24 —
`flutter test` and `flutter analyze` pass clean across all three, and both
apps render correctly via `flutter run -d web-server`. Customer login and
signup match a Figma Make reference exactly (colors/border style extracted
from the live page's computed CSS, not eyeballed) — see the Design section
in `CLAUDE.md` for the retheme history and what is/isn't rebuilt to match it.
The backend and admin-web are still source-only: this machine has no Node.js
or Postgres, so neither has ever been installed, built, or run. See
`CLAUDE.md` for the full list of gaps.

## Getting started

```bash
# Backend
cd services/api
cp .env.example .env   # point DATABASE_URL at a real Postgres instance
npm install
npm run prisma:migrate
npm run start:dev

# Admin web
cd apps/admin-web
npm install
npm run dev

# Mobile apps
cd apps/customer-app && flutter pub get && flutter run
cd apps/provider-app && flutter pub get && flutter run
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
Plus Jakarta Sans as an actual bundled asset on mobile (works on web via a
stylesheet link; Android/iOS currently fall back to the platform default
font — see the Design section in `CLAUDE.md`). Iconly icons, by contrast,
*are* bundled as real font assets (`packages/shared-flutter/assets/fonts/`)
since the pub packages for them don't compile on this Flutter version —
see `OneHubIcons`' doc comment.
