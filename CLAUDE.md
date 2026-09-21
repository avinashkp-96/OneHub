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

Material 3, one shared brand: deep teal-blue primary (`#0E7C86`), semantic
success/warning/danger colors kept separate from the Material color slots
(there's no built-in success/warning concept), Noto Sans for future
regional-language coverage, rounded cards, full-width 48px-tall primary CTAs
for outdoor/gloved-hand use. Same palette across the customer app, provider
app, and admin panel, deliberately not differentiated by role — see the
tradeoff note this was decided against differentiating by in-app color.

- Mobile: `packages/shared-flutter/lib/src/theme/` (`OneHubColors`, `OneHubTheme`). Both apps must use `OneHubTheme.light()`/`.dark()` rather than building their own `ThemeData`.
- Admin web: `apps/admin-web/src/theme.css` (CSS custom properties), loaded once in `main.tsx`.
- These two aren't generated from one shared source — keep them in sync by hand until a token pipeline exists.

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
- No runtime installed on the dev machine this was scaffolded on (no Node.js, npm, Flutter, or Python) — nothing here has been installed, built, or run.
- Local git hooks and CI were copied from `Engineering/hooks-templates/` and `Engineering/ci-templates/`, which were created as part of this project's kickoff (they didn't exist before). Review them once a second project needs them.
