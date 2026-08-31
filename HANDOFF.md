# Hoppin Driver App — Handoff

Flutter app for Hoppin drivers (package `tech.hoppin.driver`). Targets: web
(primary during development), Android, iOS. Built against the **live** backend
at `https://api.hoppin.tech/api/v1` — there is no staging environment, so use
a test driver account, never a real one.

## Repo layout

```
app/          the Flutter project (run everything from here)
docs/         backend contracts and the ask/answer exchange with the backend
figma/        design exports the screens were built against
```

## Getting it running

```bash
cd app
flutter pub get
flutter test                  # ~520 tests, all green at handoff
```

Run on Chrome:

```bash
flutter run -d chrome --dart-define-from-file=config/dev.json
```

Release web bundle (also substitutes the Maps key into index.html):

```bash
MAPS_API_KEY=<browser key> bash tool/build_web.sh
# output: build/web — serve statically, e.g. python -m http.server 8787
```

Android release APK:

```bash
ORG_GRADLE_PROJECT_MAPS_API_KEY=<android key> flutter build apk --release
# output: build/app/outputs/flutter-apk/app-release.apk
# note: the flutter CLI does not accept -P; the env var is how the Gradle
# property gets through.
```

## Secrets you need (none are committed)

| What | Where it goes | Template |
|---|---|---|
| Supabase URL + anon key | `app/config/dev.json` | `app/config/dev.json.example` |
| Google Maps browser key | env var to `tool/build_web.sh` | — |
| Google Maps Android key | env var at build (above) or `app/android/gradle.properties.example` flow | `gradle.properties.example` |
| Google Maps iOS key | `app/ios/Flutter/Secrets.xcconfig` | `Secrets.xcconfig.example` |

Get all of these from the project owner. Maps keys: restrict the Android key
to the app package + your signing SHA-1 (`cd android && ./gradlew
signingReport`), the browser key by HTTP referrer. Enable only Maps SDK for
Android / iOS / Maps JavaScript API — never Directions; route polylines come
from our backend.

You also need a **test driver account** (email + password) from the owner —
sign-up exists in the app but new drivers land in "under review" until an
admin approves them.

## Load-bearing conventions — read before writing code

- **The backend is the source of truth.** If a designed screen has no
  endpoint, it gets dropped or redesigned, never faked with invented data.
  The Go source lives in a separate repo (`hoppin/`, ask the owner for
  access); `docs/001`–`007` record every contract question already settled.
- Every repository method returns `Result<T>` (`Ok`/`Err`) — nothing throws
  across that boundary.
- Money is `Pence` (integer). `Pence.format()` uses U+2212 MINUS SIGN, so
  tests must match `−£5.00` exactly, not a hyphen-minus.
- Errors map on the server's `code` field (`app/lib/core/api/error_codes.dart`);
  the `error` string is log material, never shown to drivers.
- **The offer card must never show rider identity pre-accept** (name, photo,
  rating) — Equality Act ruling, enforced by a widget test. Full identity
  after accept via `/rides/:id/rider-context`.
- Avatars and any `/images/...` URL are in a private bucket: fetch through
  `ApiClient.getBytes` / `AuthedAvatar` (attaches the Bearer token), never
  `NetworkImage` — a plain image load answers 401.
- Golden tests (`app/test/visual/`) pin every screen. After a deliberate UI
  change: `flutter test --update-goldens test/visual/<file>` and eyeball the
  PNG. `test/visual/failures/` is gitignored output, never commit it.
- Realtime = FCM push + 5-second polling. No WebSocket, no SSE — don't add
  one; the backend has no stream endpoint.
- Editing Dart from a script on Windows: use Python with explicit UTF-8 —
  PowerShell's `Set-Content` mangles `£` and `−`.

## State at handoff

Everything in the Figma pack that the backend supports is built and matched
against the design (last sweep: all screens driven live against production
with Playwright). Suite green.

**Open items, in order of value:**

1. **Backend answers pending** — `docs/007-backend-ask-4-driver-app.md`:
   today's `online_seconds` counts whole still-open sessions (drivers see
   absurd totals), and `cancellation_rate` comes back null while
   `trips_cancelled` is non-zero. Both are backend-side; the app renders
   honestly either way.
2. **Owner rulings pending** — Settings screen omits five designed rows
   (screen-lock, Appearance, Navigation, Distance Units, Language: only
   notification prefs have API backing); the lilac accent on form CTAs
   deviates from the design's orange/navy; Delete Account lives in the
   drawer, the design puts it inside Settings. Don't "fix" these without a
   decision — each was deliberate.
3. **Web hosting** — the bundle builds clean but is deployed nowhere.
4. **iOS** — untouched beyond scaffolding; needs the Maps key file and a
   device test pass.
5. Two small refactors flagged in review, safe to fold into other work:
   dedupe the dashed-border painters (`credentials_screen.dart`,
   `breakdown_card.dart`), and extract the repeated golden-test capture
   harness into `test/visual/harness.dart`.

## Testing notes

The full suite takes 1–3 minutes; under parallel machine load a lone flake
(usually `onboarding_controller_test`) can appear — rerun the file in
isolation twice before treating it as real.
