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

Source scaffold only. Nothing has been installed, built, or run yet — this
machine has no Node.js, Flutter, or Python runtime installed. See `CLAUDE.md`
for the full list of gaps.

## Getting started (once runtimes are installed)

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
Forgot/Reset Password for both apps, dashboard shells, Category browsing +
Post a Requirement + Bid List on the customer app, and Incoming Requests +
Price Range & Contact Unlock on the provider app.

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
location permission handling), and the admin provider-verification queue.
