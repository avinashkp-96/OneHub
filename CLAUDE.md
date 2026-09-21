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

## **Deployment**

Not decided yet. Flag when a target (cloud provider, hosting) is chosen.

## **Quality floor**

Unit test line coverage: 80% (Engineering default, not raised here). Only `auth.service.spec.ts` exists so far — coverage is well under floor until more tests are written.

## **Constraints**

- No AI attribution in commits, comments, or file headers (Engineering default).
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
