# Backend asks — driver app (round 6)

Raised 2026-09-03 after testing every driver endpoint against
`api.hoppin.tech` with a live driver JWT
(`aliakbarsukhera05@gmail.com`, sub `daefcfb7-9e70-4e2a-9ce6-7953e274d8d3`).

**Item 1 is a live outage: no driver can upload a document on any real
device.** It is a five-minute config change. Everything after it is a screen
showing less than it should.

Each item states whether it is **BUILT**, **PARTLY BUILT** or **NOT BUILT**,
what the app needs, the exact payload, and what the app does meanwhile.

---

## How to read the status column

| Status | Meaning |
|---|---|
| ✅ BUILT | Endpoint exists and returns what the app needs. Nothing to do. |
| ⚠️ PARTLY BUILT | Endpoint exists; a field is missing or wrong. |
| ❌ NOT BUILT | No endpoint. Needs building. |

---

# 1. ❌ BROKEN IN PRODUCTION — presigned upload URL is unreachable

**Severity: blocking. A new driver cannot complete onboarding.**

`POST /drivers/me/documents/upload-url` returns 200 with a URL the client
can never reach:

```json
{
  "upload_url": "http://minio:9000/test-verifier/driver-docs/daefcfb7-.../dvla_license/d9b90be7-....jpg?X-Amz-Algorithm=AWS4-HMAC-SHA256&...",
  "key": "driver-docs/daefcfb7-.../dvla_license/d9b90be7-....jpg"
}
```

Three separate problems in that one URL:

1. **`minio` is an internal Docker hostname.** Verified from outside the
   box: `Could not resolve host: minio`. No phone, browser or emulator can
   resolve it. There is no public alias either — `storage.hoppin.tech`,
   `minio.hoppin.tech` and `s3.hoppin.tech` are all unresolvable.
2. **It is plain `http`.** Android release builds block cleartext traffic by
   default, so even a resolvable host would fail on a real handset.
3. **The bucket is `test-verifier`**, which looks like a dev leftover rather
   than the intended documents bucket.

**What the driver sees:** the app asks for the slot (200), PUTs the bytes
(fails to connect), and shows *"There was a problem. Please try again
later."* The app's three-step flow — presign → PUT → confirm — is correct;
step 2 cannot succeed.

## Two ways to fix it. **We would prefer option A.**

### Option A — proxy the bytes through ride-service (recommended)

**This already exists in your codebase.** `internal/storage/s3.go` has
`PutTo`/`GetFrom`, and the comment on `PutTo` describes exactly this problem:

> *"Nothing about the object store is ever exposed to the client, so MinIO
> stays private — no public bucket, no tunnel, no presigned URL whose host
> the browser has to be able to resolve."*

The avatar upload already works this way. Documents can use the same path:

```
POST /drivers/me/documents/upload
Content-Type: multipart/form-data
Authorization: Bearer <driver JWT>

  document_type: "dvla_license"
  file:          <bytes>

→ 201 {
    "id": "871a79c2-...",
    "document_type": "dvla_license",
    "verification_status": "pending_review",
    "uploaded_at": "2026-09-03T16:07:21Z",
    "expires_at": null
  }
```

Errors (existing envelope): `413 FILE_TOO_LARGE`, `415 UNSUPPORTED_TYPE`,
`503 STORAGE_DISABLED`.

Why we prefer it: MinIO never needs a public hostname, a tunnel, or CORS.
One round trip instead of three. And the presigned URL — a five-minute
write credential to our bucket — never leaves the server.

### Option B — make the presigned URL publicly resolvable

Keep the current three-step flow, but presign against a public base:

- Set a public endpoint for presigning (`S3_PUBLIC_ENDPOINT`, distinct from
  the internal `S3_ENDPOINT` the SDK talks to), e.g.
  `https://storage.hoppin.tech`.
- Put MinIO behind the same cloudflared tunnel as `api.hoppin.tech`, over
  **https**.
- Add CORS on the bucket for `PUT` from the app origins (the web build needs
  this; native does not).
- Confirm the intended bucket name — `test-verifier` reads as a leftover.

If you take B, the app needs no change at all. **Please tell us which.**

---

# 2. ⚠️ PARTLY BUILT — cancellation rate on `GET /drivers/me/stats`

`/drivers/me/stats` is live and returns `acceptance_rate`, `average_rating`,
`completion_rate`, `earnings`, `online_minutes`, `penalties`. **No
cancellation rate.**

Definition agreed with the product owner 2026-09-02:

> The percentage of rides the driver cancelled — declined offers plus rides
> cancelled within two minutes of the ride starting — over total
> cancellations.

**Add to the same response:**

```json
"cancellation_rate": 0.08,
"cancellations": 4,
"cancellation_window_seconds": 120
```

**The app must not compute this.** A percentage we derive will disagree with
the one operations use to penalise, and the driver gets told two different
numbers for the same thing. The window comes from you too: the app states
the rule in the UI ("cancelled within 2 minutes of accepting"), so a policy
change must not silently make the app lie.

**Meanwhile:** the stats screen shows no cancellation figure at all.

---

# 3. ❌ NOT BUILT — payment schedule and next payment date

`GET /drivers/me/wallet` is live and returns `available_balance`,
`pending_balance`, `currency`, `last_payout_at`, `recent_payouts[]`. It says
where money went and how much. **It never says when the next one lands.**

**Needed** — on the wallet response or a sibling:

```json
"schedule": "weekly",
"next_payment_date": "2026-09-08",
"schedule_description": "Every Monday"
```

`schedule` ∈ `weekly | monthly | custom`. `schedule_description` is required
for `custom`, which the app cannot phrase on its own.

**Meanwhile:** the screen shows balances and past payouts and states no
policy. The app must not assert on the business's behalf when money moves.

---

# 4. ⚠️ PARTLY BUILT — maintenance window on `GET /app-status`

Live and correct: `{"platform","minimum_required_version","latest_version",
"maintenance_mode","update_available","force_update_required"}`. The app
gates on `maintenance_mode` — a maintenance screen replaces the whole app.

**Needed:** the window, so the screen can say when work ends.

```json
"maintenance_started_at": "2026-09-02T02:00:00Z",
"maintenance_ends_at":    "2026-09-02T04:00:00Z",
"maintenance_message":    "Planned upgrade to dispatch"
```

**Meanwhile:** the screen promises no window. A made-up "back at 3pm" is
worse than an honest "we are checking", so nothing is invented.

---

# 5. ❌ NOT BUILT — notification severity

FCM sends `type: "alert"` (title + body) and `type: "ride_update"` (status).
Nothing says how much a notification matters.

The app currently shows critical alerts as a toast that stays until
dismissed, ordinary ones for four seconds — and **decides which by
pattern-matching the copy** for "penalty", "suspended", "expired". That
works, and it is guessing. A reworded message silently downgrades an alert
the driver needed to act on.

**Needed** in the FCM data payload:

```json
"severity": "critical"
```

`severity` ∈ `info | critical`.

---

# 6. ⚠️ PARTLY BUILT — SESSION_REPLACED needs context

The service allows one live session and answers `SESSION_REPLACED` to the
loser. The app now has a dedicated screen for it (shipped 2026-09-03).

**The gap:** the app cannot tell *"you signed in on your other phone"* from
*"someone else has your password"*. Same code; the second is a security
incident the driver must act on.

**Needed** in the error envelope:

```json
{
  "code": "SESSION_REPLACED",
  "error": "session taken over",
  "replaced_by": { "device": "iPhone 14", "at": "2026-09-02T09:12:00Z" }
}
```

A device label, a timestamp, or a coarse location — any one helps.

**Meanwhile:** the app says a session was taken over, offers to sign in
again, and points at a password change, without claiming to know which.

---

# 7. ❌ NOT BUILT — booking notes

The product owner has said a backend is coming.

**Needed:** the rider's note on the ride payload the driver already reads
(`GET /rides/:id`), so the trip screen shows it without a second call on the
hot path.

```json
"rider_note": "Flat 3, buzzer is broken — please call"
```

---

# 8. ❌ NOT BUILT — heatmap

**Needed:** demand data the app can draw — cells with a weight, scoped to a
city or a radius around the driver.

```json
{
  "cells": [ { "lat": 52.58, "lng": -2.12, "weight": 0.82 } ],
  "generated_at": "2026-09-03T14:00:00Z"
}
```

Cell size and weighting are yours to decide. The app renders the scale it is
given rather than bucketing raw ride counts itself.

---

# 9. ❌ NOT BUILT — JSON compression

The product owner has said a document is coming. **Needed: the document.**

Most likely this is `Accept-Encoding: gzip`, which Dio handles natively — in
which case there may be no client work at all beyond confirming the service
sets `Content-Encoding`. Please confirm.

---

# Round 5 items — still open

Carried from `BACKEND-DRIVER-APP-ROUND5-2026-08-30.md`:

| # | Item | Status |
|---|---|---|
| 1 | Cancellation history — who cancelled, and why | ❌ NOT BUILT |
| 2 | Fair stats — cancels that aren't the driver's shouldn't count | ❌ NOT BUILT |
| 3 | Appeal decisions reaching the app with a reason | ⚠️ check |
| 4 | Cancellation notifications carrying the reason | ❌ NOT BUILT |
| 5 | GDPR delete button (same as rider) | ❌ NOT BUILT |

---

# Confirmed working — no action needed

Tested 2026-09-03 with a live driver JWT. All 200, all with real data:

| Endpoint | Returns |
|---|---|
| `GET /drivers/me/status` | presence, dispatchable, last_location_at, stale_after_seconds |
| `GET /drivers/me/today` | online, earnings_pence, trip_count, online_seconds, active_ride_id |
| `GET /drivers/me/documents` | documents[] with verification_status, expires_at, rejection_reason |
| `GET /document-types` | codes, labels, required, uploadable, expires |
| `GET /drivers/me/wallet` | balances, currency, last_payout_at, recent_payouts[] |
| `GET /drivers/me/stats` | acceptance_rate, average_rating, completion_rate, earnings, online_minutes, penalties |
| `GET /drivers/me/offers` | 200 |

---

# One note for whoever tests the API next

`curl` with its default user-agent gets **`error code: 1010`** from
Cloudflare — a bot block that looks exactly like a backend 403 and sent us
down the wrong path for twenty minutes. Send a browser user-agent:

```sh
curl -H "User-Agent: Mozilla/5.0 (Linux; Android 13) Chrome/120 Mobile Safari/537.36" \
     -H "Authorization: Bearer $TOKEN" \
     https://api.hoppin.tech/api/v1/drivers/me/status
```
