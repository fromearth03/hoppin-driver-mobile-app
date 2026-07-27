# Hoppin Driver — Android

**Target: Android only.** The web target was dropped in v3.0 Phase 2 (decision **D1**), and it is not a preference.

A browser tab cannot honestly hold a driver's shift. Geolocation is not exposed to `ServiceWorkerGlobalScope` — the only web context that survives a backgrounded tab — and the W3C **declined to spec it**. Chrome freezes hidden tabs and clamps their timers to roughly one tick per minute. iOS Safari suspends `watchPosition` when backgrounded. And the server **drops a driver from the dispatch pool after 5 minutes without a ping**.

There is no web mitigation for that. Not a hard one — **none**. A web driver app would silently drop every driver who locked their phone, while showing them a confident green ONLINE badge. Android's typed foreground service is the only sanctioned way to keep reading location with the screen off, and that is the entire reason this app is native.

---

## Run

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://<ref>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<anon-key> \
  --dart-define=RIDE_SERVICE_URL=http://10.0.2.2:8080/api/v1
```

> **`10.0.2.2`, not `localhost`.** On the Android emulator `localhost` is the *emulator*. `10.0.2.2` is the host machine. A `:8080` that works fine from a browser will silently fail from the app — and it will look like an auth bug for an hour before you find it.

Demo (zero backend, no dart-defines):

```bash
flutter run -t lib/main_demo.dart
```

---

## The signed release command

```bash
# 1. Create the upload keystore ONCE. Keep it safe — losing it means you can
#    never update the app on Play again.
keytool -genkey -v -keystore ~/hoppin-driver-upload.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload

# 2. Point the build at it. GITIGNORED — never commit this file.
cat > apps/driver/android/key.properties <<'EOF'
storePassword=<the store password>
keyPassword=<the key password>
keyAlias=upload
storeFile=/absolute/path/to/hoppin-driver-upload.jks
EOF

# 3. Build the signed App Bundle (this is what Play takes; an APK is not).
cd apps/driver
flutter build appbundle --release \
  --dart-define=SUPABASE_URL=https://<ref>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<anon-key> \
  --dart-define=RIDE_SERVICE_URL=https://<production-api>/api/v1

# → build/app/outputs/bundle/release/app-release.aab
```

For a signed APK you can sideload onto a test device:

```bash
flutter build apk --release --dart-define=...   # → build/app/outputs/flutter-apk/app-release.apk
```

**Without `key.properties` the release build falls back to the debug keystore.** It will run locally and Play will refuse the upload — which is the intended friction. An artifact nobody can ship must not *look* shippable.

---

## Push (FCM)

**Registration is BOUND. Delivery is GATED. They are not the same thing.**

1. Firebase console → project settings → Add app → **Android** → package name `com.hoppin.hoppin_driver` → download `google-services.json` → drop it at `apps/driver/android/app/google-services.json`.

`google-services.json` is **gitignored**, and `google-services.json.example` documents the shape. We do **not** commit a placeholder: a fabricated project id, api key and app id in the repo is a fabricated credential record, and it would be *worse than nothing* — the build would succeed, `firebase_core` would "initialise", and every token request would fail against a project that does not exist. A green build that lies about being push-capable. Absent the file, `build.gradle.kts` skips the google-services plugin, `main.dart`'s guarded `initializeApp()` fails softly, and the app boots on `NoopDriverFcmGateway`, which reports the gate honestly.

**Gap #69 does NOT block the driver.** It has been read across the project as "push is blocked". `POST /me/device-tokens` validates `device_os` against `{ios, android}` and rejects only `"web"` — so it blocks the **rider** (which ships web, and correctly refuses to send a false `"android"` to get past the validator). **Going Android *unblocks* driver token registration**: `"android"` is a value the contract already accepts.

**What is still gated is delivery**, on the backend's `FCM_CREDENTIALS_FILE` (#15/#16) and on a push-event schema that has never been published. So the driver app registers a real token and simply never receives anything. That is the honest state of a correctly-wired client waiting on a server — and it is why the app draws **no bell, no badge, and no "you'll be notified" promise** off this rail. *No badge over a dead handler.*

---

## 🔴 HUMAN-VERIFY — things no test in this repository proves, and none pretends to

A green suite is not a shipped driver. These four are real gates, and each one needs a human, a phone, or a server we do not control.

| # | Gate | Blocked on | Why no test can cover it |
|---|------|-----------|--------------------------|
| 1 | **Actual push delivery** | Backend `FCM_CREDENTIALS_FILE` (#15/#16) | The server *cannot send*. A test asserting "push works" would be a lie about a subsystem whose server half does not exist. What IS tested: that a real token is POSTed with `device_os: "android"`, and that a missing token registers **nothing**. |
| 2 | **Tap-routing from a real OS notification** | (1), plus a published push schema | The `deep_link` field is an **assumption**. Until the backend publishes a schema, we parse defensively and route through the not-found screen on anything we do not recognise. |
| 3 | **The screen-locked 10-minute heartbeat** | A real Android phone | The runbook is below. `flutter test` has no Doze, no OEM battery manager, no lock screen. A test that claimed this would be theatre. |
| 4 | **An 8-hour real-device shift** | A real Android phone and eight hours | Same as (3), at the duration that actually matters. |
| 5 | **Play background-location approval** | Google review, **weeks** | The justification text is below. Submit it EARLY. |

---

## 🔴 The manual device test — the screen-locked heartbeat

**This is the one that decides whether the app works.** Everything else in Phase 2 exists to make this pass.

**You need:** a real Android phone (an emulator will not Doze convincingly), a debug build, a way to watch `POST /drivers/me/location` land (backend logs, or the admin panel's driver-presence view), and 15 minutes.

1. Install a debug build on the phone and sign in as a driver who is **compliance-approved** (an unapproved driver gets `403 NOT_ELIGIBLE` from `POST /drivers/me/online` and never gets to the part we are testing).
2. Tap **GO**. Accept the location prompt with **"While using the app"** — deliberately the *reduced* grant, so you can watch the honest path first.
   - ✅ **Expect:** the persistent notification appears: **"On shift · You're online. Hoppin is sending your location to dispatch."**
   - ✅ **Expect:** the pill reads **"On duty · app must stay open"** — **not** the green "On duty". The supporting line reads **"Trips stop if you lock your phone or switch apps"**, and the `BackgroundLocationLimitedNotice` banner is visible with a **"Fix in settings"** action.
   - 🔴 **If you see a confident green "On duty · Finding trips nearby" here, STOP. That is the bug this phase exists to delete** — the app is claiming background coverage it does not have.
3. Tap **"Fix in settings"** → Android Settings → Permissions → Location → **"Allow all the time"**. Return to the app.
   - ✅ **Expect:** the banner **disappears** and the pill goes green. It disappears because `AppLifecycleListener.onResume` re-asked the OS — not because we assumed the tap worked.
4. **Lock the phone. Put it in your pocket. Wait 10 minutes.** Do not touch it.
5. Watch the server.
   - ✅ **Expect:** `POST /drivers/me/location` **every ~20 seconds, without a gap**. Roughly 30 pings in 10 minutes.
   - ✅ **Expect:** the driver stays **Active** in the admin's presence view for the whole 10 minutes. The server drops a driver after **5 minutes** without a ping, so a single 5-minute gap anywhere in this window is a **FAIL**, not a hiccup.
6. Unlock. Tap **"Go offline"**.
   - ✅ **Expect:** the persistent notification **disappears**, and the heartbeat **stops**.

**Repeat step 4-5 on at least one Xiaomi/Huawei/Oppo/OnePlus device.** Their OEM battery managers kill foreground services far more aggressively than stock Android, and they are extremely common among UK private-hire drivers. If the service dies there, the app raises the #85 rung (permission held, service not running → same consequence, same disclosure) — verify it does, rather than showing a confident badge.

**Also worth doing:** revoke "Allow all the time" from Settings *while the app is backgrounded*, then return to it. The banner must come back. Android pushes us no event for that revocation — the resume hook is the only thing that catches it.

---

## 🔴 Play Store — background-location justification

> **Submit this EARLY.** Google reviews background-location requests **by hand**, and it takes **weeks**. It is the longest-lead item in the milestone and it is not something to discover at release. Draft is below; the Play Console form also demands a **short video** demonstrating the in-app disclosure and the feature in use.

### The declared permission

`android.permission.ACCESS_BACKGROUND_LOCATION`

### Core functionality this permission enables

> Hoppin Driver is the driver-side application for a licensed private-hire operator in Wolverhampton, United Kingdom. Drivers use it to accept and complete passenger journeys.
>
> While a driver is **on shift**, the app sends their location to our dispatch service approximately every 20 seconds. Our dispatch system matches waiting passengers to the **nearest available driver**, and it removes any driver from the dispatch pool who has not reported a location in the last **5 minutes**.
>
> A driver on shift routinely has the app off-screen: their phone is locked in a cradle, or they are using a navigation app to drive to a pickup. Without background location access, Android stops delivering location updates the moment the app leaves the screen. The driver would then be silently removed from the dispatch pool within five minutes — believing they are working, receiving no journeys, and earning nothing for the rest of their shift.
>
> Background location is therefore not an enhancement to a feature. It **is** the feature: without it the app cannot perform its single core function, which is to keep a working driver reachable by dispatch.

### Why a foreground-only alternative is not sufficient

> We considered and rejected foreground-only location. It would require a driver to keep the app open and their screen on for an entire eight-hour shift, which is not a realistic way to drive a car, drains the battery, and is unsafe. It would also make it impossible for a driver to use a navigation app — which they must do on every single journey.
>
> **We have nevertheless built the foreground-only path as a first-class, working state**, because Android's two-stage permission model means many drivers will grant only "While using the app". A driver in that state is fully dispatchable while the app is on screen, and the app **explicitly tells them what they lose** — that trips stop if they lock their phone — rather than showing them a confident "online" status it cannot honour. We do not treat a foreground-only driver as broken, and we do not block them from working.

### User-facing disclosure and control

> - Location is collected **only while the driver has explicitly gone on shift** by tapping GO. It stops immediately when they tap "Go offline". There is no collection when the driver is off shift.
> - While on shift, a **persistent, non-dismissible Android notification** is displayed for the entire duration, reading: *"On shift — You're online. Hoppin is sending your location to dispatch."* The driver can never be in a state where we are reading their location without that notification visible.
> - The foreground service is declared with `foregroundServiceType="location"`.
> - The background permission is requested only as an **explicit second stage**, from a driver-initiated tap on an in-app explanation that states plainly what the permission is for and what happens without it. It is never bundled into the initial location prompt, and it is never requested silently.
> - Location data is used solely to match the driver to nearby journeys and to display their position to the passenger during an active trip. It is **not** used for advertising, profiling, or sale to third parties.

### Data handling

> Location is transmitted over HTTPS to our own dispatch service and is retained only as long as required for operational and licensing purposes under our UK private-hire operator conditions. It is not shared with third parties for advertising or analytics.

---

## Architecture notes for the next person

- **The heartbeat runs in the app isolate, not in the foreground service.** `flutter_foreground_task` *can* run a separate `TaskHandler` isolate, and it is tempting. But that isolate cannot see the Riverpod graph or the Supabase session, and would need its own auth, its own repository, and its own copy of the *"no fix means NO PING"* rule — a second, divergent implementation of the most safety-critical loop in the app, with no test covering it. **One heartbeat. One rule.** The service exists to keep the isolate **alive**, not to duplicate it.

- **`0,0` is never posted.** The backend *accepts* an empty heartbeat body and binds it to `0,0` — the Gulf of Guinea. A "send something rather than nothing" heartbeat would hand dispatch a confident, wrong fix. **No fix → no ping →** the driver is not dispatchable, and the app *says so* (seam **#84**).

- **Plugin isolation is a machine assertion**, not a promise. `geolocator`, `flutter_foreground_task` and `firebase_*` each live in exactly one file, and `plugin_isolation_test.dart` fails if any of them reaches `packages/` or a second file in `lib/`. It is what keeps `flutter test` off a MethodChannel — **there is not one MethodChannel mock in this repository**, and there does not need to be.

- **The workspace has ONE shared lockfile.** `geolocator` is pinned to the rider's `^13.0.4` **deliberately**: `^13` and `^14` are disjoint caret ranges, so if the two apps split on the major version, `pub get` fails outright for **both**. Any bump is a single commit touching both manifests, with the rider's location tests re-run.
