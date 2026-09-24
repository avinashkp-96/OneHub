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
through `.pagePaddingY`), a two-font type system (Bricolage Grotesque for
headings, DM Sans for body/UI text — see the Typography note below), Iconly
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

A **fifth** round (2026-09-24) corrected the implementation directly against
verbal instructions, superseding the PDF/screenshot reading on five points:
`PrimaryCta`'s gradient/label color now use the literal `OneHubColors.primary`
→ `.primaryGradientEnd` and `Colors.white` rather than
`Theme.of(context).colorScheme.primary`/`.onPrimary` — `ColorScheme.fromSeed`
derives a tonal-palette color from a seed and doesn't guarantee the result
equals the seed's own hex, so the button was silently off the exact spec.
Signup's City/Location field (with its GPS badge) was removed entirely —
it's coming back later, not deleted for good; the signup API call now sends
`'city': ''` since the backend DTO requires a string with no `@IsOptional()`.
Signup's Password/Confirm moved from a side-by-side `Row` back to two full-
width stacked fields. And the glow effect moved from a page-level
`GlowBackground` (three blobs behind the whole screen, now deleted) to a new
`GlowCard` (`packages/shared-flutter/lib/src/theme/glow_card.dart`) — clipped
*inside* a form card, replacing bare `Card` usage on the auth screens. This
is a general principle now, not a one-off: any future ambient-glow effect
belongs to its own component, clipped to that component's bounds, never
bled onto the page background.

A same-day follow-up (still 2026-09-24) extended `GlowCard` with a second
glow: it now renders both a bottom-left blue glow (`OneHubColors.glowBlue1`,
`#2563EB`) and a subtle top-right light glow (`OneHubColors.glowLight`),
confirmed explicitly to apply "across all screens" but *only for form-card*-
style content (the single primary card on a screen, e.g. login/signup) —
not repeated list-item cards (dashboard sections, category tiles, request/
bid list rows), which would turn a subtle effect into a distracting,
repeated one. Since `GlowCard` is the shared component, any screen that
adopts the form-card pattern gets both glows automatically; existing
list-tile `Card` usage elsewhere in the app was deliberately left alone.

A second same-day follow-up moved the top-right glow back out of the card:
per explicit instruction, it now lives on the page background, behind the
card, not inside it — a deliberate, explicit exception to "glows stay
inside their component." `GlowCard` (`glow_card.dart`) keeps only the
bottom-left blue glow; a new `PageGlow` widget in the same file renders the
top-right light glow on the page background and wraps each auth screen's
`Scaffold.body` (outside `SafeArea`, so it isn't clipped by safe-area
insets). Both widgets are dark-mode-only, matching the reference.

Login's content is also now vertically centered on the page (was top-
aligned) via a `LayoutBuilder` + `ConstrainedBox(minHeight: ...)` wrapping
the `SingleChildScrollView`'s child, so it still scrolls if content
overflows a short viewport.
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
itself). The customer Dashboard (home screen) went through two redesign
passes on 2026-09-24. First: a greeting header + real search field replaced
the old plain `AppBar`, placeholder sections gained icon badges, and the
old 5-item Material `NavigationBar` (Home, Search, My Requests,
Notifications, Profile) was replaced by `CurvedNavBar`
(`packages/shared-flutter/lib/src/theme/curved_nav_bar.dart`): a floating,
icon-only, 3-item bar (Home, Requests, Profile — Profile still unwired)
with a wavy top edge painted via a `CustomPainter` (`_WaveNavPainter`), per
a reference screenshot. `OneHubColors.navBarFillDark`/`.navBarFillLight`
are solid (not translucent) fills specifically for this bar, since it
floats over arbitrary scrolling content rather than a fixed backdrop.

Second: the user supplied a full HTML/CSS mockup ("OneHub home screen.html")
with its own distinct palette, fonts (Bricolage Grotesque/DM Sans), and
custom SVG icons. Explicitly scoped down before implementing: match its
**structure and alignment only** — location chip + bell header, headline,
search bar with a trailing filter button, a hero gradient CTA card, a
Services quick-access grid, an Active Requests list with a 4-step status
tracker, a Nearby Providers teaser, and a promo banner — while keeping the
current `OneHubColors`/`OneHubTheme`/`OneHubIcons` design system entirely
unchanged (not the mockup's own palette/fonts/icons). `CurvedNavBar` from
the first pass was kept as-is (not swapped for the mockup's flat 5-item
nav). At that point Services and Active Requests were wired to the real
`/categories` and `/requirements/mine` endpoints this app already calls
elsewhere, rather than the mockup's example content.

Third (same day): a pixel-exact screenshot of just the header/search/hero/
Services portion, explicitly authorizing dummy data ("use dummy data for
now") — the first explicit exception to not fabricating content. Applied
narrowly to what the screenshot actually specified: the location chip now
shows a fixed example ("Edappally, Kochi") instead of a generic "Set your
location" prompt, the headline includes a dummy name ("...Meera?"), and
the Services grid became 4 hardcoded `_DummyCategory` entries (name, icon,
"N available pros") in a 2-column card layout — `ServiceCategory` (the real
model) has no pro-count field at all, so this exact stat can't be real
regardless of data source. The Services grid's live `/categories` fetch was
removed since the section no longer displays fetched data; "See all" still
opens the real, API-backed `CategoryGridScreen`. Active Requests, Nearby
Providers, and the promo banner are unchanged — that screenshot didn't
show them, so they keep the second pass's real-data/honest-prompt
treatment. The hero card changed from a solid blue gradient to `GlowCard`
(dark, per that screenshot), with a "FREE TO POST" tinted pill badge and a
pill CTA (white icon-circle + label) replacing the earlier white-on-blue
button. Two new `OneHubIcons` entries support this: `filter` (search bar)
and `chevronDown` (location chip dropdown); `danger` and `edit` are
approximate stand-ins for "electrician"/"painter" since Iconly has no
trade-specific glyphs.

A fourth, same-day polish round against a follow-up screenshot: the hero
card's faint watermark icon was removed entirely; the "FREE TO POST" badge
was rebuilt inline (not `TintedBadge`) to drop its letter-spacing and bump
its size slightly, matching the reference's styling more closely; the
search bar's radius went from a full pill (`radiusPillBadge`) down to
`radiusFormCard`, a softer rounded rectangle instead of a stadium shape.
`PageGlow` gained a second glow — a soft blue one (`OneHubColors.glowBlue1`)
anchored bottom-right, alongside the existing top-right light glow —
applied consistently everywhere `PageGlow` already wraps a screen (all
auth screens and the dashboard), not just this one.

A fifth round matched the hero card's CTA icon exactly: it's a "»"
slide-button affordance, not a single chevron — Iconly has no
double-chevron glyph, so it's built from two `OneHubIcons.chevronRight`
icons overlapped via `Transform.translate`, recolored from
`OneHubColors.primary` (blue) to `OneHubColors.surfaceDark` (near-black)
to match the reference's dark icon on the white circle.

Other customer screens (category browsing, requirements, ratings) still
use earlier layout conventions, just with the current colors/fonts/shapes/
icons applied automatically since those come from the shared theme. If
provider screens or the rest of customer screens are wanted in this style
too, that's a separate ask.

Semantic success/warning/danger colors stay separate from the Material
color slots (there's no built-in success/warning concept). Full-width
48px-tall primary CTAs for outdoor/gloved-hand use are kept from the
original design.

- Mobile: `packages/shared-flutter/lib/src/theme/` (`OneHubColors`, `OneHubTheme`, `OneHubTextStyles`, `OneHubIcons`, `GlowCard`, `PageGlow`, `CurvedNavBar`, `TintedBadge`). Both apps must use `OneHubTheme.light()`/`.dark()` rather than building their own `ThemeData`, `OneHubTextStyles.*` rather than generic `Theme.of(context).textTheme` slots on screens this style guide documents, and `OneHubIcons.*` rather than `Icons.*` or a raw Iconly reference. `PrimaryCta` is a custom gradient rounded-rect (not a themed `FilledButton`) — widget tests that find it by button type need to find it by ancestor/type instead (see `packages/shared-flutter/test/screens/reset_password_screen_test.dart` for the pattern). **Named spacing/radius constants exist specifically so a value can't silently drift out of sync the way it already did once** — two retheme rounds' worth of hardcoded `24`s survived a card-radius change from 24→16→20 in four call sites and two tests before this pass caught it; every remaining radius reference now points at `OneHubTheme.radiusFormCard` etc. instead of a bare number.
- Admin web: `apps/admin-web/src/theme.css` (CSS custom properties, teal palette, unchanged), loaded once in `main.tsx`.
- **Icons**: Iconly, vendored directly rather than via the `iconly` or `flutter_iconly` pub packages — both subclass `IconData`, which became a `final class` in this Flutter version, so neither compiles. `OneHubIcons` defines plain `IconData` constants against `packages/shared-flutter/assets/fonts/IconlyLight.ttf`/`IconlyBold.ttf` (MIT-licensed, see `IconlyFont-LICENSE.txt` next to them), with codepoints read directly out of the `iconly` package's source rather than guessed. If a future Flutter/Dart release fixes the subclassing issue and a maintained package appears, this vendoring could be dropped, but there's no urgency — it works and has no runtime dependency risk.
- **Typography**: originally one font (Plus Jakarta Sans) throughout; switched 2026-09-24 to a two-font system per explicit instruction to match a separate HTML/CSS mockup's fonts exactly — `OneHubTheme.fontFamilyDisplay` (Bricolage Grotesque) for headings (`OneHubTextStyles.pageHeading` and the `TextTheme`'s display/headline slots), `OneHubTheme.fontFamily` (DM Sans, kept this name since most of the codebase already calls it that) for everything else. Both referenced by family name (`TextTheme` per-slot, not `ThemeData.fontFamily`), not through the `google_fonts` package — that package's runtime API fetches fonts over the network with no offline fallback, which broke every test touching this theme and would be a real production risk on a bad connection. Web loads both via one `<link>` in `web/index.html`, requesting only the weights actually used (Bricolage Grotesque 800; DM Sans 400/500/600/700) rather than the mockup's own narrower weight list, which didn't cover this app's full type scale. Mobile falls back to the platform default until the actual `.ttf`s are bundled as assets (not done yet). This also means no Devanagari/regional-script coverage (Noto Sans, used before Plus Jakarta Sans, had it) — a real regression to revisit before any localization work starts, not re-litigated when each reference was adopted since the user handed over an explicit spec each time.

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
