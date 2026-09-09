# Driver app — outstanding front-end work

**10 September 2026.** One doc, replacing the earlier dated notes.

I audited the driver app against the backend: **113 driver-reachable endpoints
exist, the app references 69.** Some of that gap is rider-only endpoints that
will never apply. The rest is below, ordered by what it costs you today.

Backend work is all on `main` in `Go_ride_service`, `hoppin_admin` and
`Go_Database`. Nothing here is blocked on me — every endpoint listed is live.

---

## The short version

| # | What | Impact | Effort |
|---|---|---|---|
| 1 | No push — the app polls for offers every 5 s | **Offer latency, battery, server load** | M |
| 2 | Location reporting has no caller | **Live-Ops blind, all drivers read Offline** | S |
| 3 | Scheduled rides — feature not in the app at all | Drivers cannot see or take booked work | L |
| 4 | No SOS / panic button | Safety surface missing | M |
| 5 | Cancellation fees not shown before confirming | Drivers charged without warning | S |
| 6 | Driver cannot see their own cancellation rate | They get penalised by a number they can't see | S |
| 7 | Destination filter unused | Feature exists, nobody can reach it | S |
| 8 | No device check-in | Blacklist enforcement is toothless | XS |
| 9 | Free-cancel countdown — re-test, backend was broken | May already work now | XS |
| 10 | Compression — do not break it | Nothing to do | — |

---

## 1. No push notifications — the app polls every 5 seconds

**This is almost certainly what "slow" feels like.**

There is no `firebase_messaging` dependency, nothing calls
`POST /me/device-tokens`, and `home_controller.dart:190` runs:

```dart
_timer = Timer.periodic(ref.read(pollIntervalProvider), (_) => _tick());
// pollIntervalProvider = Duration(seconds: 5)
```

So every online driver hits `GET /drivers/me/offers` **twelve times a minute,
forever**, and a ride offer can sit up to 5 seconds before the driver sees it.
On a dispatch that gives each driver a limited window, that latency comes
straight out of your acceptance rate.

### What to build

1. Add `firebase_messaging`. The backend already sends FCM pushes — the sender is
   live and used by the admin service.
2. Register the token on login and on refresh:
   ```dart
   POST /me/device-tokens   { "fcm_token": "<token>", "platform": "android" }
   ```
3. Wake on the push and fetch the offer, rather than polling for it.
4. **Keep a slow poll as a backstop** — every 30–60 s, not 5. Push is
   best-effort; a dropped notification must not mean a missed ride. But it should
   be a safety net, not the primary path.

Notification categories are `trip`, `compliance`, `payout`, `system`. All four
are now correctly populated (they were not until 8 Sep — everything was filed as
`system`, so a category filter would have returned nothing).

---

## 2. Location reporting — `updateLocation()` has no caller

The method exists and is correct:

```dart
// app/lib/features/home/data/driver_status_repository.dart:45
Future<Result<void>> updateLocation(double lat, double lng) async {
  final r = await _api.post<dynamic>('/drivers/me/location',
      body: {'lat': lat, 'lng': lng});
  ...
}
```

**Nothing calls it.** Grepped again today: one reference, its own definition.

### What that costs

- **Live-Ops is an empty map.** Ops cannot see any driver.
- **Every driver reads Offline** in the admin panel. The pill is
  `last_location_at > NOW() - 5 min`. No heartbeat, no Active — whatever they are
  actually doing. It is also why "Active drivers" on the Dashboard never matches
  reality.
- **Stuck-ride detection has no input.**
- **Mid-trip cancellation is mispriced** — the partial fare uses the driver's live
  position to work out distance actually covered.
- **Cancellation fees go against the driver.** The free-distance waiver checks how
  far they are from pickup; a missing position fails safe, meaning *no waiver*.
  Drivers are paying fees they should not.

### What to build

A `DriverLocationSender`, modelled on the rider app's
`features/trip/data/rider_location_sender.dart` — that one is written, reviewed
and in production.

| | Rider (exists) | Driver (to build) |
|---|---|---|
| When | Between accept and trip start | The whole time they are **online** |
| Endpoint | `POST /me/location` | `POST /drivers/me/location` |
| Body | `{lat, lng, accuracy_m}` | `{lat, lng}` |
| `distanceFilter` | 5 m | **25 m** — road speed; 5 m streams constantly |

Start on Go Online succeeding, stop on Go Offline and logout. Do not tie it to a
screen — drivers lock their phone while driving. Swallow failures; the next fix
supersedes a dropped one.

**Verify:** go online, then check Live-Ops shows your marker (~10 s) and the
Drivers row flips to Active.

---

## 3. Scheduled rides — the app has none of it

The backend has a full scheduled-ride offer board. The driver app has **zero**
support — the only mention anywhere is a string in `offline_hero.dart` telling
drivers they will see "scheduled bookings", which they never will.

Live endpoints:

```
GET  /drivers/me/scheduled-offers        the open board — work available to claim
GET  /drivers/me/scheduled-rides         what this driver has committed to
POST /scheduled-rides/:id/claim          take it (soft hold)
POST /scheduled-rides/:id/accept         commit
POST /scheduled-rides/:id/driver-cancel  drop out
GET  /scheduled-rides/:id                detail
```

The claim/accept split exists so two drivers cannot take the same booking:
claiming places a short hold, accepting commits. Dropping out after accepting
notifies the rider and returns the ride to the board.

This is the largest single piece of work on the list, and the only one that is a
genuinely new screen rather than wiring.

---

## 4. No SOS / panic button

`grep -rn "sos\|panic"` over the driver app returns nothing. The rider app has
one; the driver does not.

```
POST /me/sos    { lat, lng, ride_id?, note? }    raise an alert
GET  /me/sos                                     the driver's own alerts
```

An alert lands in the admin SOS console, which pages ops. Two related things
worth doing at the same time:

```
GET/POST/DELETE /me/emergency-contacts
```

Next of kin, so an SOS has somebody to call. **Note:** until 8 Sep every attempt
to save one returned 400 — the apps sent `{name, phone}` and the API demanded
`{contact_name, phone_number}`. The API now accepts **either** spelling and
returns both, so this works on your current build with no coordination needed.

---

## 5. Cancellation fees — show the cost before confirming

Today every option in the picker reads as free and the server then charges. This
is **not fixable in the picker**, and the reason matters:

The fee-bearing events — cancelling after committing, or mid-trip — are **derived
by the server from ride state**, not from the reason picked. They are deliberately
absent from `GET /cancellation-reasons` because they are not things you choose. So
no per-reason hint can describe them.

```
GET /rides/:id/cancellation-quote?actor=driver
```

```json
{ "fee_pence": 500, "free": false, "free_until": "2026-09-10T14:32:00Z",
  "event": "driver_cancel", "explain": "Cancelling now costs £5.00." }
```

Same derivation the charge uses, so it is the real number. **Show `explain`
verbatim at the top of the cancel sheet, before any reason is picked** — that is
what the rider app does now (`features/trip/presentation/live_trip_screen.dart`).

Two rules:
- **A failed quote means free, not blocked.** A driver must always be able to
  escape a ride.
- **`free: false` with no amount → treat as free.** Warning about a charge whose
  size you do not have is worse than saying nothing.

---

## 6. Driver cannot see their own cancellation rate

```
GET /drivers/me/cancellation-rate
```

Returns the windowed rate and the cancellations behind it. There is a configurable
threshold above which penalties apply — so drivers are being judged on a number
the app never shows them. The rider app gained the equivalent screen; the driver
app should have it too, ideally near the profile or earnings area.

---

## 7. Destination filter — built, unreachable

```
GET /drivers/me/destination-filter
PUT /drivers/me/destination-filter
```

Lets a driver say where they are heading so dispatch prefers offers that way —
the classic "going home" filter. Fully implemented server-side, no UI.

---

## 8. Device check-in — one call

```
POST /me/device   { device_id, platform, model, ... }
```

Records the device fingerprint. The blacklist gate reads the driver's **most
recent** device — so a driver whose app never checks in has no fingerprint, and
the blacklist cannot touch them. One call at launch closes that.

---

## 9. Free-cancel countdown — re-test before changing anything

`rides.accepted_at` was empty on **every ride**. The accept path drivers actually
use (the offer board) never stamped it; only the older direct-accept path did.
Everything anchored to accept silently fell back to `created_at`, which folds in
the whole matching wait.

Fixed 8 Sep — both paths stamp it, and migration 141 recovered 62 rides of
history. If your countdown was showing wrong values or not appearing, this was
probably why. **Test against the current backend before touching app code.** Same
applies to the late-arrival grace: it was measuring from ride creation, so drivers
looked later than they were.

---

## 10. Compression — nothing to do, but do not break it

As of 9 Sep the API gzips responses over 1 KB, and the driver web build's
`main.dart.js` went 4.1 MB → 1.2 MB (71%).

Your app already benefits: Dart's `HttpClient` sends `Accept-Encoding: gzip` and
decompresses transparently. I checked `api_client.dart` — no override.

**Three ways it gets switched back off:**

1. **Setting `Accept-Encoding` by hand.** Dart only auto-decompresses when *it*
   added the header. Set it yourself and you get a gzip stream as raw bytes, and
   JSON parsing fails on binary. If you ever see "unexpected character" on a
   response that works in a browser, check this first.
2. Disabling `autoUncompress` on a custom adapter.
3. A response interceptor that assumes `response.data` is text — breaks only once
   a response crosses 1 KB, so it looks intermittent.

**Deliberately not compressed**, so none of it reads as a bug: bodies under 1 KB
(gzip framing makes them *bigger* — the 18-byte health check measures 45 bytes),
event streams, already-encoded bodies, and request bodies (your multipart uploads
are unaffected).

If you serve your own web build, use `Hoppin/deploy/nginx-mobile-web.conf`.
`gzip_vary on` is the line people leave out — without it a cache can hand gzip to
a client that cannot read it.

---

## Already working — no action

Worth knowing so you do not spend time on them:

- **Document rejection reasons.** `onboarding_status.dart:25` reads
  `rejection_reason` and `onboarding_screen.dart:213` shows it. Admin approve and
  reject were only wired on 8 Sep — before that no document was ever rejected, so
  that path is about to get its first real traffic. Worth an eyeball with a real
  sentence in it.
- **Notification categories** — all four now populated correctly.
- **Accept timestamps, penalty/earning notifications, appeals, earnings
  breakdown** — all live and already called by the app.

---

## Smaller things, if you want them

Live endpoints the app does not use, roughly by value:

| Endpoint | What it gives the driver |
|---|---|
| `GET /demand-heatmap` | Where demand is, so they can reposition |
| `GET /ride-rules` | The pickup rules the server enforces, instead of hardcoding a copy that drifts |
| `GET /drivers/me/avatar-upload-url` | Profile photo |
| `GET /me/rating` | Their own rating |
| `GET /rides/:id/geo` | Route polyline for the map |
| `GET /faqs` | FAQ content, editable by ops |
| `GET /cancellation-policy` | Policy text, editable by ops |
| `GET /me/activity` | Money timeline (charges, credits, penalties) |
| `GET /rides/:id/receipt` | Trip receipt |
| `GET /service-areas/check` | Pre-check whether a point is in service |

---

## One ask

If a response shape is not what you expect, tell me rather than working around
it. Two of this week's fixes were field-name mismatches between the apps and the
API, each silently breaking a whole feature for months — emergency contacts could
never be saved because the app sent `{name, phone}` and the API required
`{contact_name, phone_number}`, so every single save returned 400. I would much
rather fix that at the origin than have you code around it.
