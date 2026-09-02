# Backend asks — driver app

What the driver app needs and cannot build against today. Raised 2026-09-02
while working the UI/UX list.

Each item says what the app would render, what it needs from the service, and
what the app does in the meantime. Nothing here is blocking a release; every
one of them is a screen currently showing less than it should.

---

## 1. Cancellation rate — the figure and its definition

**What the app shows now:** nothing. The stats screen has no cancellation
rate at all.

**Agreed definition (from the product owner, 2026-09-02):**

> The percentage of rides the driver cancelled — declined offers plus rides
> cancelled within two minutes of the ride starting — over total
> cancellations.

**Needed:** a field on `GET /drivers/me/stats` carrying the rate the service
computed, plus the counts it came from. The app must not derive it: a
percentage the app calculates will disagree with the one operations use to
penalise, and the driver will be told two different numbers for the same
thing.

```
"cancellation_rate": 0.08,          // the service's own figure
"cancellations": 4,                 // numerator, as counted server-side
"cancellation_window_seconds": 120  // so the app can state the rule honestly
```

**Note on the window:** the two-minute rule is backend logic. The app will
state it in the UI ("cancelled within 2 minutes of accepting"), so the number
has to come from the service rather than be hard-coded here — otherwise a
policy change silently makes the app lie.

---

## 2. Payment schedule and next payment date

**What the app shows now:** the Payouts screen (being renamed Payment
Methods) lists where money goes, but never when.

**Needed:** on `GET /drivers/me/payouts` or a sibling endpoint —

```
"schedule": "weekly" | "monthly" | "custom",
"next_payment_date": "2026-09-08",
"schedule_description": "Every Monday"   // for "custom", which the app cannot phrase
```

**Why the app cannot guess:** the balance panel already refuses to state a
deduction policy for exactly this reason — the app must not assert on the
business's behalf when money moves.

---

## 3. Maintenance window times

**What exists:** `GET /api/v1/app-status` returns `maintenance_mode` as a
bare boolean. The app now gates on it — a maintenance screen replaces the
whole app while it is set.

**Needed:** the window, so the screen can say when work ends.

```
"maintenance_started_at": "2026-09-02T02:00:00Z",
"maintenance_ends_at":    "2026-09-02T04:00:00Z",
"maintenance_message":    "Planned upgrade to dispatch"   // optional
```

**Meanwhile:** the screen promises no window and says the app will clear
itself when the service returns. A made-up "back at 3pm" is worse than an
honest "we are checking", so nothing is invented.

---

## 4. Booking notes

**Status:** the product owner has said a backend for this is coming.

**Needed:** whatever field carries the rider's note, on the ride payload the
driver already reads (`GET /rides/:id`), so the trip screen can show it
without a second call on the hot path.

---

## 5. JSON compression

**Status:** the product owner has said a document is coming.

**Needed:** the document. The client will implement whatever it specifies —
most likely `Accept-Encoding: gzip` handling, which Dio does natively, in
which case this may need no client work at all beyond confirming the service
sets `Content-Encoding`.

---

## 6. Heatmap

**Needed:** demand data the driver app can draw — a grid of cells with a
demand weight, scoped to a city or a radius around the driver.

```
"cells": [ { "lat": 51.51, "lng": -0.13, "weight": 0.82 }, ... ],
"generated_at": "2026-09-02T14:00:00Z"
```

Cell size and weighting are the service's to decide; the app will render
whatever scale it is given rather than bucketing raw ride counts itself.

---

## 7. Notification severity

**What exists:** FCM sends `type: "alert"` with a title and body, and
`type: "ride_update"` with a status.

**The gap:** nothing says how much a notification matters. The app now shows
critical alerts as a toast that stays until dismissed and ordinary ones for
four seconds — and decides which is which by **pattern-matching the copy**
for words like "penalty", "suspended", "expired". That works, and it is
guessing.

**Needed:** `"severity": "info" | "critical"` in the FCM data payload.

---

## 8. Session replaced — what the app should tell the driver

**What exists:** the backend allows one live session and answers
`SESSION_REPLACED` to the loser.

**The gap:** the app cannot distinguish "you signed in on your other phone"
from "someone else has your password". Both are the same error code, and the
second is a security incident the driver needs to act on.

**Needed:** enough context to say which — a device label, a timestamp, or a
coarse location for the session that took over.

```
"replaced_by": { "device": "iPhone 14", "at": "2026-09-02T09:12:00Z" }
```

**Meanwhile:** the app will say a session was taken over, offer to sign in
again, and point at a password change — without claiming to know which of the
two happened.

---

## Already answered — no longer asks

Recorded so nobody re-raises them:

- **Document upload.** Exists:
  `POST /drivers/me/documents/upload-url` (presigned), then
  `POST /drivers/me/documents` to confirm, and `GET /drivers/me/documents`
  to list. The client will be wired to it.
- **Maintenance flag.** Exists on `GET /api/v1/app-status`, along with
  `force_update_required`, `update_available`, `minimum_required_version` and
  `latest_version`. Now gated on in the app.
- **Driver stale window.** `driverStaleAfterSeconds = 90`. The GPS beat is
  set at 15s against it, with a 1s burst until the first fix lands.
