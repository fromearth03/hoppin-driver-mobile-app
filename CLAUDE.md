# Hoppin driver app

**This is the live driver app.** `../hoppin-driver-mobile-app` is **dead** —
do not work in it, do not port from it without checking first (see below).

Flutter app in `app/`, package `hoppin_driver`.

---

## Running and building

```sh
cd app
flutter test                                              # ~604 tests, all should pass
flutter analyze lib/<path>                                # scoped is much faster than whole-project
flutter build apk --release --dart-define-from-file=config/dev.json
flutter build web --profile   --dart-define-from-file=config/dev.json
```

Config lives in `app/config/dev.json` — `SUPABASE_URL`, `SUPABASE_ANON_KEY`,
`API_BASE_URL`. Never build without `--dart-define-from-file` or the app has
no backend.

APK lands at `app/build/app/outputs/flutter-apk/app-release.apk`.
JDK 21 is required (`C:\Users\Hp\java\jdk-21`); Flutter already points at it.

Git: one remote shared with the dead repo,
`https://github.com/fromearth03/hoppin-driver-mobile-app`. **This app pushes
to `master`.**

---

## Architecture

```
lib/core/       api (ApiClient, ApiException, error_codes), theme, auth, device
lib/features/<name>/{data,logic,ui}
lib/shared/     nav (AppShell, SideDrawer), widgets
```

- **Riverpod.** Controllers are `AsyncNotifier`, state travels as `AsyncValue`.
- **`Result<T>` + `ApiException`**, not exceptions, across repository calls.
- **Theme is `AppColors` / `AppText`** from `core/theme`. There is no
  `context.hoppin` and no `HoppinTokens` — that is the dead repo's system.

---

## Conventions that are load-bearing

**Render async state with `AsyncView`, never `AsyncValue.when`.**
`.when` routes on the *current* state, so a refresh over data the app already
holds takes the loading branch and the screen blanks. On a polling app that is
every tick. `shared/widgets/async_view.dart` asks value-first: held value →
blocking error → cold start.

**Cold starts get a skeleton, not a spinner.** `shared/widgets/app_skeleton.dart`
(`Skeleton`, `SkeletonCard`, `SkeletonList`). The placeholder must be shaped
like what lands, or content jumps when it arrives.

**Frosted surfaces go through `AppGlass`.** `shared/widgets/app_glass.dart`,
tiers `chrome` (72% fill) and `panel` (86%, for readable copy). It degrades to
opaque under reduced transparency. Four files still hand-roll their own blur —
see `HANDOFF-2026-09-03.md`. Note `AppGlass` replaces *two* widgets
(`ClipRRect` + `BackdropFilter`), so migrating drops a closing paren.

**Error copy is centralised** in `core/api/error_codes.dart`. A code with no
entry falls through to "Something went wrong. Please try again", which names
no cause and no fix. If the backend adds a code, add copy for it.

**Bounded pumps in widget tests.** Never `pumpAndSettle` — this app has live
polling providers and settle-detection never terminates.

**Golden tests exist** under `test/visual/`. A deliberate visual change fails
them; check the diff is only what you intended, then
`flutter test test/visual/<file> --update-goldens`.

---

## Before porting anything from the dead repo

Five of six bugs "found" there did not exist here — they were fixed properly
when this app was written: safe JSON parsing, pull-to-refresh, the
online/offline flicker, declined-ride resume, and a real
`DraggableScrollableSheet` bottom card. Multi-stop is built here and richer
(per-leg fares, waiting charges, arrive/depart).

**Verify the bug exists in this repo before writing a fix for it.**

---

## Talking to the live API

Two traps, each of which has already produced a wrong diagnosis:

1. **Cloudflare blocks curl's default UA** with `error code: 1010` (403). It
   looks exactly like a backend permission failure. Send a browser UA.
2. **Supabase JWTs expire in one hour.** Every route then answers
   `AUTH_REQUIRED`, which looks like a wiring bug. Re-mint before concluding.

```sh
curl -H "User-Agent: Mozilla/5.0 (Linux; Android 13) Chrome/120 Mobile Safari/537.36" \
     -H "Authorization: Bearer $TOKEN" \
     https://api.hoppin.tech/api/v1/drivers/me/status
```

---

## Known live outage

**Document upload is broken on every device.** The presign returns
`http://minio:9000/...` — an internal Docker hostname, over cleartext. The
app's flow is correct; step 2 cannot connect. Full write-up and both fix
options: `docs/BACKEND-ASK-ROUND6-2026-09-03.md`.

---

## Where things are written down

- `HANDOFF-2026-09-03.md` — current state, what is half-done, what is open.
- `docs/BACKEND-ASK-ROUND6-2026-09-03.md` — what the backend owes the app,
  each marked BUILT / PARTLY BUILT / NOT BUILT with exact payloads.
- `docs/backend-asks.md` and `docs/BACKEND-*ROUND5*` — earlier rounds, several
  still open.
