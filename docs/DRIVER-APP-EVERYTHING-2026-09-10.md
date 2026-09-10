# Driver app — the complete picture

**Audited: driver app `master` @ 2f31302 (8 Sep) against ride-service `main` @ b4590c4, 10 September 2026.**

Self-contained. Two earlier documents exist and were never handed over, so
nothing here refers to them — everything still true from those is repeated below.
Where anything disagrees with an older note, this file is newer.

Everything described as live is live on `api.hoppin.tech` now.

---

# Part 1 — Contract changes you need to handle

These landed today. Two of them are new error codes your app does not map yet.

## 1.1 `POST /drivers/me/location` can answer 422

```
422  { "code": "NO_DRIVER_PROFILE",
       "error": "no driver profile for this account, so the position was not stored" }
```

Before today this returned **200 while storing nothing** — the write matched no
`driver_profiles` row and the error was never checked. Your app swallows
heartbeat failures by design, which is right, so neither side could see it.

**Do:** keep swallowing it for the driver, but treat 422 as terminal, not
retryable. It will not fix itself — the account has no profile and that needs
support. Retrying every 15s just re-hides it. Log once per session.

`error_codes.dart` does not map this yet.

## 1.2 Every authenticated call can answer 403 `ACCOUNT_DELETED`

```
403  { "code": "ACCOUNT_DELETED", "error": "this account has been deleted" }
```

A GDPR-erased account now stops working immediately, everywhere. Previously it
kept full API access until the token expired.

**Do:** treat it exactly like `ACCOUNT_BANNED` / `ACCOUNT_SUSPENDED`, which you
already map — clear session, return to sign-in, do not retry. The GoTrue login is
deleted too, so re-login also fails. `error_codes.dart` maps the other two but
not this one.

## 1.3 Cancellation penalties are real numbers now

`GET /drivers/me/cancellation-rate` returns `penalised_count` and
`penalty_total_pence`. **The column behind them was never written** — the caller
passed a literal `0`, so 43 of 45 cancellations read as penalty-free and both
fields were always 0. Fixed, and the history recovered from the ledger.

**Do:** if you skipped these because they were always zero, stop. They are the
difference between "4 cancellations" and "4 cancellations, 1 charged" — the
second is the one that does not make a driver think every cancellation cost them.

## 1.4 A free ride now pays the driver, and the receipt says so

Two bugs, both fixed today:

* A ride fully covered by a promo **paid the driver nothing.** The charge path
  returned as soon as payable hit £0, before any ledger posting.
* Even once that was fixed, `GET /rides/:id/earnings` still read **£0**, because
  the per-trip breakdown was never written for those rides.

Both now behave like a paid trip: normal net, funded by the platform.

**Do:** nothing if you already render `GET /rides/:id/earnings`. If you
special-cased "£0 on a discounted trip", remove it — £0 now means £0.

**Two completed rides were backfilled**, so earnings may appear on trips that
previously read zero. Expected.

## 1.5 Promo discounts follow the FINAL fare

A promo used to be resolved once against the estimate and frozen. "100% off" on a
£12.90 quote became "£12.90 off", so a trip metering at £24 billed the rider
£11.10 for a ride the app called free. Now re-resolved against the real fare.

**Do:** nothing directly — this is rider-side money. It reaches you because the
driver's earning on a promo trip is now based on the real fare, so an overrunning
trip pays for what was actually driven.

## 1.6 `GET /app-status` carries `maps_engine`

```json
{ "maps_engine": "auto" }   // "auto" | "osm" | "google"
```

Lets us move both apps off Google Maps without a release — a failed Maps SDK
authorisation still returns a working controller and draws a grey map, so the app
cannot detect it itself.

**Do:** if you render a map, honour it. No fallback renderer? Ignore the field —
it is additive.

## 1.7 Payment state changes AFTER completion

Failed captures now retry automatically, up to 12 attempts. A transaction reading
`failed` right after a trip may be `paid` minutes later — one was today,
recovering £15.44 that would otherwise have expired uncaptured.

**Do:** do not cache payment state as final at completion. Re-read when the
driver opens the trip. Showing "payment failed" on a trip that later settles will
convince a driver they were not paid.

---

# Part 2 — Built, live, and unused

Backend endpoints that exist and work today, which the app never calls. This is
the largest category and none of it needs backend work.

## 2.1 "I'm here" / "I'm coming" — the arrival exchange

| Who | Call | Effect |
|---|---|---|
| Driver | `PATCH /rides/:id/arrive` | stamps `arrived_at`, starts free-waiting clock |
| Rider | `POST /rides/:id/coming` | stamps `rider_coming_at` |

`GET /rides/:id` serves the rider, the **assigned driver**, or an admin, and
carries:

```json
{ "rider_coming_at": "2026-09-10T12:41:07Z" }   // null until they tap it
```

The rider only gets the button once the driver has announced arrival, so non-null
always means "your rider has seen it and is on the way".

**App references: 0.** Poll `GET /rides/:id` while the ride is in `arrived` and
surface it when it flips.

**Caveat, mine not yours:** there is no push. The driver only learns by polling.
The commit that added this said the problem was "the driver sat at the kerb
guessing whether anyone was coming" — without a push that is still true. I am
adding it; the field will not change shape, so build against it now.

## 2.2 Scheduled rides — fully built, driver side included

I previously implied this needed designing. It does not. It is all live:

```
GET    /drivers/me/scheduled-offers     the open board
GET    /drivers/me/scheduled-rides      work this driver has committed to
POST   /scheduled-rides/:id/claim       short exclusive hold
DELETE /scheduled-rides/:id/claim       release the hold
POST   /scheduled-rides/:id/accept      commit
POST   /scheduled-rides/:id/driver-cancel
```

**App references: 0.** Every "scheduled" string in the app is incidental —
comments and unrelated text.

This also makes `offline_hero.dart:187` a false promise today: it says *"Go
online to see ride requests and scheduled bookings here"* and no scheduled
booking can ever appear.

## 2.3 Destination filter

```
PUT    /drivers/me/destination-filter
GET    /drivers/me/destination-filter
DELETE /drivers/me/destination-filter
```

**App references: 0.** Live and unused.

On the design question you raised: show it on the home screen. A filter that
silently narrows offers with nowhere to see it is exactly the support ticket you
described — the driver has no other way to discover why work dried up.

## 2.4 The dedicated cancellation-rate endpoint

`GET /drivers/me/cancellation-rate` — windowed rate plus the cancellations behind
it, and now `penalised_count` / `penalty_total_pence` (§1.3).

Your stats screen reads `cancellation_rate` off `/drivers/me/stats`, which is
correct and correctly attributed — only the driver's own cancellations count, and
your comment at `stats_screen.dart:139-145` describes the backend accurately.
This endpoint is the richer version, showing which cancellations were actually
charged.

## 2.5 Emergency contacts

```
POST   /me/emergency-contacts
GET    /me/emergency-contacts
DELETE /me/emergency-contacts/:id
```

**App references: 0.** You were right that platform support lines and next-of-kin
are different things — my earlier note conflated them. The API takes either field
spelling, so you are unblocked whenever you scope it.

## 2.6 Cancellation quote

`GET /rides/:id/cancellation-quote` — the actual event and fee for that specific
ride, so the cancel sheet does not have to guess.

**App references: 0.** Your `_freeCancelWindow` takes the narrowest
`free_cancel_seconds` across all reasons, which is a sound guess and correctly
reasoned at `trip_controller.dart:122-125` — "under-promising costs them nothing;
over-promising costs them money." It is still a guess, and the state-derived
events cannot be represented per-reason at all. This endpoint removes both
problems and lets you delete that helper.

---

# Part 3 — Open on my side

* **No push on "I'm coming"** (§2.1). Building it.
* **`payout_batches.tax_amount` is never populated** — nothing writes it. Any tax
  figure would read £0, so do not surface one yet.
* **Driver location arriving:** heartbeats stopped between 7 Sep and today. Both
  causes on my side are fixed (a 200-that-stored-nothing, and no request logging
  anywhere in ride-service). Locations are arriving again as of this afternoon.
  If you see anything odd, tell me the time window and I can read it off the log
  now — I could not before.

---

# Part 4 — Open on your side

* **Everything in Part 2** — six live features with zero app references.
* **`error_codes.dart`** — add `ACCOUNT_DELETED` and `NO_DRIVER_PROFILE` (§1.1,
  §1.2).
* **`offline_hero.dart:187`** — either wire scheduled rides or stop promising
  them.
* **Web push** — `push_service.dart:40` returns early on web, so a web build
  registers no token. Real, but only matters if drivers actually use the web
  build; my instinct is it is a demo surface and not worth a VAPID key yet. Your
  call.

---

# What is confirmed working

So this reads as an audit and not a list of complaints — all verified on `master`
today:

* Push notifications: `firebase_core ^4.14.0`, `firebase_messaging ^16.6.0`,
  token registered at `push_service.dart:73`
* Location reporting: `location_reporter.dart:211`
* SOS: `sos_repository.dart` + `emergency_sheet.dart`
* Cancellation fees shown per reason: `cancel_sheet.dart:299`
* Cancellation rate on the stats screen: `stats_screen.dart:136`
* Device check-in: `auth_repository.dart:129`
* `cancel_sheet.dart:225-232` refuses to copy the design's "won't affect your
  rating" footer, because `free_cancel_seconds` waives the **fee** only. The
  design was wrong and not shipping it was the right call — that is a
  money-and-trust bug that would have been very hard to trace later.

---

Ask me rather than the code. Several things here behaved differently as recently
as this morning, and the code cannot tell you which half you are reading.
