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

**Authoritative source: `docs/onehub-signup-style-guide.pdf`** (copied into
the repo 2026-09-25, "Component library and visual tokens extracted from
the signup screen"). Where this PDF and any Figma link/screenshot disagree,
the PDF wins — it's the exact hex/rgba/px tokens, not an eyeballed reading.
Every value in `OneHubColors`, `OneHubTheme`'s named spacing/radius
constants, and `OneHubTextStyles`' 7-entry type scale traces back to a
specific line in that PDF; see each file's doc comments for the mapping.

**Mobile (customer-app, provider-app)**: dark-first, Tailwind blue-500/700
(`#3B82F6`→`#1D4ED8`) gradient CTAs, translucent white-on-dark cards/inputs
with a visible border, 20px card / 14px button / 12px input / 6px small-badge
/ 99px pill-badge radii, named spacing tokens (`OneHubTheme.gapIconLabel`
through `.pagePaddingY`), one font throughout (Plus Jakarta Sans), Iconly
icons (thin "Light" stroke, two deliberate Bold exceptions — rating stars
and the signup success check). This is the **fourth** design iteration in
four days (2026-09-22 through -25), each superseding the last as a newer,
more specific reference arrived: teal → indigo-on-lavender ("PetCare"
mockup) → light-purple (`#6C63FF`, a Figma snapshot read from a screenshot)
→ Tailwind blue (the same Figma file's "Version 5", read via live computed
CSS) → this one (the style guide PDF, more precise still — e.g. the CSS
reading had the card radius at 16px and the background at `#121714`; the
PDF says 20px and `#111318`). If a fifth reference shows up, same rule
applies: check it, don't assume the current read is final. The PDF also
revealed one real layout correction: the earlier CSS-based reading rendered
"NEW ACCOUNT"/"FREE SIGNUP" badges above the signup heading (they appeared
on that live page); the actual reference screenshot that came with this PDF
doesn't have them — the style guide's "Badges" section is a component
showcase, not a spec for this screen's layout, so they were removed.
Figma source (superseded, kept for history): https://www.figma.com/make/EaytjRnHfHfvqaMMKUdeDD/App-Signup-Screen-UI
`admin-web` was deliberately left on the original teal palette throughout
all four design rounds; it is not "the one shared brand across all three
surfaces" and that's intentional, not drift — don't "fix" it back without asking.

Screen rebuilds to match this reference are scoped to the **customer app
only** (explicitly confirmed, twice) — provider screens inherit the shared
colors/fonts/shapes/icons automatically, but their layouts (login, signup,
dashboard, etc.) haven't been individually rebuilt against this reference.
Customer login and signup are done as of 2026-09-25, including the full
3-step signup flow (form → 6-box OTP → success) and the icon-next-to-label
field pattern (icons sit beside the field's label, not inside the field
itself). Other customer screens (dashboard, category browsing, requirements,
ratings) still use earlier layout conventions, just with the current
colors/fonts/shapes/icons applied automatically since those come from the
shared theme. If provider screens or the rest of customer screens are
wanted in this style too, that's a separate ask.

Semantic success/warning/danger colors stay separate from the Material
color slots (there's no built-in success/warning concept). Full-width
48px-tall primary CTAs for outdoor/gloved-hand use are kept from the
original design.

- Mobile: `packages/shared-flutter/lib/src/theme/` (`OneHubColors`, `OneHubTheme`, `OneHubTextStyles`, `OneHubIcons`, `GlowBackground`, `TintedBadge`). Both apps must use `OneHubTheme.light()`/`.dark()` rather than building their own `ThemeData`, `OneHubTextStyles.*` rather than generic `Theme.of(context).textTheme` slots on screens this style guide documents, and `OneHubIcons.*` rather than `Icons.*` or a raw Iconly reference. `PrimaryCta` is a custom gradient rounded-rect (not a themed `FilledButton`) — widget tests that find it by button type need to find it by ancestor/type instead (see `packages/shared-flutter/test/screens/reset_password_screen_test.dart` for the pattern). **Named spacing/radius constants exist specifically so a value can't silently drift out of sync the way it already did once** — two retheme rounds' worth of hardcoded `24`s survived a card-radius change from 24→16→20 in four call sites and two tests before this pass caught it; every remaining radius reference now points at `OneHubTheme.radiusFormCard` etc. instead of a bare number.
- Admin web: `apps/admin-web/src/theme.css` (CSS custom properties, teal palette, unchanged), loaded once in `main.tsx`.
- **Icons**: Iconly, vendored directly rather than via the `iconly` or `flutter_iconly` pub packages — both subclass `IconData`, which became a `final class` in this Flutter version, so neither compiles. `OneHubIcons` defines plain `IconData` constants against `packages/shared-flutter/assets/fonts/IconlyLight.ttf`/`IconlyBold.ttf` (MIT-licensed, see `IconlyFont-LICENSE.txt` next to them), with codepoints read directly out of the `iconly` package's source rather than guessed. If a future Flutter/Dart release fixes the subclassing issue and a maintained package appears, this vendoring could be dropped, but there's no urgency — it works and has no runtime dependency risk.
- Plus Jakarta Sans is referenced by family name (`TextTheme` per-slot, not `ThemeData.fontFamily`), not through the `google_fonts` package — that package's runtime API fetches fonts over the network with no offline fallback, which broke every test touching this theme and would be a real production risk on a bad connection. Web loads it via a `<link>` in `web/index.html`; mobile falls back to the platform default until the actual `.ttf` is bundled as an asset (not done yet). This also means no Devanagari/regional-script coverage (Noto Sans, used earlier, had it) — a real regression to revisit before any localization work starts, not re-litigated when each reference was adopted since the user handed over an explicit spec each time.

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
