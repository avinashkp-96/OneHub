# **CLAUDE.md — OneHub**

Project-level config. Overrides `Engineering/CLAUDE.md` and the workspace root
`CLAUDE.md` where they conflict; otherwise inherits both.

## **What this is**

A two-sided marketplace connecting customers with local service providers (MVP: electricians and plumbers), covering signup, requirement posting, provider bidding, contact-unlock payments, subscriptions, ratings, and certification.

## **Stack**

- Backend: Node.js/TypeScript, NestJS, Prisma, PostgreSQL — shared by all three clients, one API contract to maintain.
- Customer app, Provider app: Flutter/Dart, separate apps sharing a `shared-flutter` package. The requirements doc left "separate apps vs. one role-based app" open (section 9); separate apps was chosen for cleaner store listings and role-specific UX, with the shared package absorbing the duplication cost.
- Admin panel: React + TypeScript + Vite.

## **Repo layout**

Monorepo. See `README.md` for the directory map.

## **Data**

PostgreSQL via Prisma. Schema at `services/api/prisma/schema.prisma`: User, Provider, Category, SubService, Requirement, Bid, Payment, Subscription, RatingFeedback, Notification.

## **Auth**

JWT (access token only, no refresh token yet), mobile OTP for signup and password reset. Role stored on the JWT payload (CUSTOMER / PROVIDER / ADMIN) and checked with a `RolesGuard`.

## **Integrations**

| Integration | Status | Notes |
|---|---|---|
| SMS/OTP delivery | open | `OtpService` currently holds OTPs in memory and returns them in the response for local testing. Needs a real SMS provider and Redis (or similar) before this leaves dev. |
| Payment gateway (₹50 contact-unlock, subscriptions) | open | `BidsService.unlockContact` records a `Payment` row as `SUCCESS` unconditionally. Needs a real gateway integration before this is trustworthy. |
| Push notifications | open | `NotificationsService` persists in-app records only; no push delivery yet. |

## **Design**

**Mobile (customer-app, provider-app)**: purple accent (`#6C63FF` exactly),
Outfit for headings, Inter for body copy, pill-shaped gradient CTAs with a
shadow, large-radius shadowed (not outlined) cards, icon-in-field text
inputs, a light/transparent app bar with dark centered text rather than a
bold color bar. This is the second retheme in as many days (2026-09-23):
first an indigo-on-lavender "PetCare"-referenced look replaced the original
teal, then a Figma Make prototype the user linked directly (a signup-screen
design) replaced that. Each time a newer, more specific reference took
priority over the previous one — if a third shows up, same rule applies.
`admin-web` was deliberately left on the original teal palette throughout;
it is not "the one shared brand across all three surfaces" and that's
intentional, not drift — don't "fix" it back without asking.

Screen rebuilds to match this reference are scoped to the **customer app
only** (explicitly confirmed) — provider screens inherit the new
colors/fonts/shapes automatically via the shared theme, but their layouts
(login, signup, dashboard, etc.) haven't been individually rebuilt against
this reference. Customer login and signup are done as of 2026-09-23; other
customer screens (dashboard, category browsing, requirements, ratings)
still use the previous PetCare-era layout conventions, just with the new
colors/shapes applied automatically. If provider screens or the rest of
customer screens are wanted in this style too, that's a separate ask.

Semantic success/warning/danger colors stay separate from the Material
color slots (there's no built-in success/warning concept). Full-width
48px-tall primary CTAs for outdoor/gloved-hand use are kept from the
original design.

- Mobile: `packages/shared-flutter/lib/src/theme/` (`OneHubColors`, `OneHubTheme`). Both apps must use `OneHubTheme.light()`/`.dark()` rather than building their own `ThemeData`. `PrimaryCta` is now a custom gradient pill (not a themed `FilledButton`) — widget tests that find it by button type need to find it by ancestor/type instead (see `packages/shared-flutter/test/screens/reset_password_screen_test.dart` for the pattern).
- Admin web: `apps/admin-web/src/theme.css` (CSS custom properties, teal palette, unchanged), loaded once in `main.tsx`.
- Outfit and Inter are referenced by family name (`TextTheme` per-slot, not `ThemeData.fontFamily`), not through the `google_fonts` package — that package's runtime API fetches fonts over the network with no offline fallback, which broke every test touching this theme and would be a real production risk on a bad connection. Web loads both via a `<link>` in `web/index.html`; mobile falls back to the platform default until the actual `.ttf` files are bundled as assets (not done yet). This also dropped Noto Sans's Devanagari/regional-script coverage, chosen earlier for the provider base's likely regional-language needs — a real regression to revisit before any localization work starts, not re-litigated when this reference was adopted since the user handed over an explicit font spec.

## **Deployment**

Not decided yet. Flag when a target (cloud provider, hosting) is chosen.

## **Quality floor**

Unit test line coverage: 85%, raised from the Engineering 80% default. Enforced
in CI (`.github/workflows/*.yml`) on every PR. Actual coverage is well under
that right now — only a handful of `*.spec.ts`/`*.test.ts` files exist so far;
treat the CI gate as real and write tests to clear it, not as aspirational.

Every commit must touch a test file alongside any source change (enforced by
the local `pre-commit` hook installed from `Engineering/hooks-templates/`) —
it checks for *a* test file in the commit, not that it's the right one or
that coverage moved in the right direction, so review test quality yourself.

## **Constraints**

- No AI attribution in commits, comments, or file headers (Engineering default).
- No reference to Claude/Anthropic anywhere in source code or commit messages — enforced by the local `pre-commit`/`commit-msg` hooks, not just a convention.
- Client data (customer/provider PII, ID proof uploads, bank/UPI details) stays out of logs and URLs.

## **Open items**

Carried over from the requirements doc, section 9:
- Whether an initial price range is mandatory before contact-unlock, or providers can skip straight to unlocking contact.
- Bid visibility/expiry rules.
- Provider verification workflow: manual admin review vs. automated document checks (current scaffold assumes manual — status starts `PENDING_VERIFICATION` and there's no approval endpoint yet).
- Certification thresholds (`CERTIFICATION_MIN_SERVICES`, `CERTIFICATION_MIN_RATING` in `ratings.service.ts`) are placeholders pending a business decision.

## **Known gaps at kickoff**

- No git remote created yet (Bitbucket `codelynks1` or GitHub `OrgMelethil` — not decided; project currently lives only at `Engineering/Projects/OneHub`, outside the `Personal/`/`Codelynks/` split).
- No commons libraries installed — `jm-ts-commons` / `jm-flutter-commons` aren't checked out locally. Revisit once they're available; several hand-rolled pieces here (JWT guard, OTP service, API client) are candidates to replace.
- No Node.js or Postgres on the dev machine this was scaffolded on — the backend and admin-web have still never been installed, built, or run. Flutter *is* now installed (shallow clone of `flutter/flutter` stable, not via an official package manager — none exists for this OS) and the mobile apps have been built, tested, and manually verified running (`flutter run -d web-server`) as of 2026-09-23.
- Local git hooks and CI were copied from `Engineering/hooks-templates/` and `Engineering/ci-templates/`, which were created as part of this project's kickoff (they didn't exist before). Review them once a second project needs them.
