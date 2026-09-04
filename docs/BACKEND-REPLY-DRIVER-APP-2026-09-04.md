# Backend reply — driver app (rounds 6 & 7)

Answering `BACKEND-ASK-ROUND6-2026-09-03.md` and
`BACKEND-ASK-ROUND7-2026-09-04.md`. Every item below was checked against the
code and against `api.hoppin.tech` today.

**Two blockers are fixed and deployed.** Three items were already built or
already work — details below, because two of them are marked NOT BUILT in your
list and you can use them today. The rest are queued with what each needs.

| # | Item | Status |
|---|---|---|
| R7-1 / R6-1 | Document upload unreachable | ✅ **FIXED — deployed** |
| R7-2 | Geo route skips stops | ✅ **FIXED — deployed** |
| R6-8 | Heatmap | ✅ **ALREADY BUILT** — endpoint below |
| R6-9 | JSON compression | ✅ **ALREADY ON** — no client work |
| R6-2 | Cancellation rate | ⏳ Queued |
| R6-3 | Payment schedule | ⏳ Queued |
| R6-4 | Maintenance window | ⏳ Queued |
| R6-5 | Notification severity | ⏳ Queued |
| R6-6 | SESSION_REPLACED context | ⏳ Queued |
| R6-7 | Booking notes | ⏳ Queued — needs rider app too |

---

# 1. ✅ FIXED — document upload. We took **Option A**.

You were right on all three faults, and right about the fix. `PutTo` was
written for exactly this and was simply never wired to documents.

**New endpoint, live now:**

```
POST /api/v1/drivers/me/documents/upload
Authorization: Bearer <driver JWT>
Content-Type: multipart/form-data

  document_type: dvla_license
  file:          <bytes>          JPG | PNG | PDF, max 10 MB

→ 201 {
    "id": "871a79c2-...",
    "document_type": "dvla_license",
    "verification_status": "pending_review",
    "uploaded_at": "2026-09-04T10:12:03Z",
    "expires_at": null
  }
```

Errors use the existing envelope: `413 FILE_TOO_LARGE`,
`415 UNSUPPORTED_TYPE` / `VALIDATION_FAILED` for a bad type,
`503 STORAGE_DISABLED`.

Three calls collapse to one. MinIO stays private — no tunnel, no public
bucket, no CORS, and the presigned credential never leaves the server.

**Verify it:**

```sh
curl -X POST https://api.hoppin.tech/api/v1/drivers/me/documents/upload \
  -H "User-Agent: Mozilla/5.0 (Linux; Android 13) Chrome/120 Mobile Safari/537.36" \
  -H "Authorization: Bearer $TOKEN" \
  -F "document_type=dvla_license" \
  -F "file=@licence.jpg;type=image/jpeg"
```

Confirmed live: a rider JWT gets `403` (correctly driver-gated) and an unknown
path gets `404`, so the route is registered and reachable.

**Notes**

- If the part carries no `Content-Type`, we sniff the bytes — a handset that omits it still works.
- `POST /drivers/me/documents/upload-url` still exists and is unchanged, so nothing breaks if you ship the new path later. Both write through the same code, so they cannot drift.
- **Bucket name:** `test-verifier` is the configured bucket and holds live data. It is only a name — nothing is broken by it — but we agree it reads wrong. Renaming means a bucket migration; it is on our list, not urgent, and no app change either way.
- **Audit retention:** every upload replaces the previous document of that type and the old object is deleted, while the row history is retained. If the SLD requires the superseded *file* to be kept as well, say so — that is a deliberate change, not an oversight.

---

# 2. ✅ FIXED — `GET /rides/:id/geo` now routes through every stop

Agreed, and a fair characterisation: a plausible wrong route is worse than an
obviously wrong one.

Now routed **leg by leg** — `pickup → stop 1 → … → dropoff` — with a per-leg
straight-line fallback so one failing leg no longer discards the whole route.

`waypoints` is returned and **labels are preserved** end to end. The rider's
chosen labels are stored at booking, and the detail parser no longer drops
them.

```json
{
  "pickup_lat": 52.5857, "pickup_lng": -2.1241,
  "dropoff_lat": 52.5903, "dropoff_lng": -2.1304,
  "waypoints": [ { "lat": 52.586, "lng": -2.128, "label": "Queen Square" } ],
  "route": [ { "lat": 52.5857, "lng": -2.1241 }, ... ]
}
```

`waypoints` is always an array, never `null`.

Thanks for the reference sketch — we did not merge it, but the shape you
described is the shape that shipped. No need to push the branch.

---

# 3. ✅ ALREADY BUILT — heatmap (you have it marked NOT BUILT)

`GET /api/v1/demand-heatmap` has been live for some time and returns almost
exactly the shape you specified.

```sh
GET /api/v1/demand-heatmap?hours=24
GET /api/v1/demand-heatmap?hours=2&bbox=minLng,minLat,maxLng,maxLat
```

```json
{
  "cells": [ { "lat": 52.586, "lng": -2.126, "weight": 1 } ],
  "cell_count": 1,
  "max_weight": 1,
  "window_hours": 24
}
```

- `hours` defaults to 2, capped at 168.
- `bbox` clips to the visible viewport.
- **`max_weight` is there so you can normalise** — `weight / max_weight` gives 0–1 for the colour scale, so you are not bucketing raw counts.
- Cells are ~110 m grid squares derived from real pickup requests.

The only difference from your spec is the field name: we return
`window_hours` rather than `generated_at`. If you need a generation timestamp,
that is a one-line add — say the word.

---

# 4. ✅ ALREADY ON — JSON compression

Confirmed today against production:

```
$ curl -sI -H "Accept-Encoding: gzip" https://api.hoppin.tech/api/v1/app-status?...
content-encoding: gzip
```

It is already negotiated end to end, so **there is no client work and no
document needed**. Dio sends `Accept-Encoding` and decompresses transparently.
Nothing to do on either side.

---

# 5. ⏳ Cancellation rate on `/drivers/me/stats`

Agreed the app must not compute it, and agreed the window has to come from us
for the reason you gave.

We will add to the same response:

```json
"cancellation_rate": 0.08,
"cancellations": 4,
"cancellation_window_seconds": 120
```

**One thing to flag before we ship it.** Driver cancellations are currently
recorded without the penalty amount being written to the cancellation record,
and no-show claims are not yet checked against ride state — so a raw
cancellation count today would include events the driver is not fairly
accountable for. That is the same concern as your round-5 item 2 ("fair
stats"), and we would rather fix the recording before publishing a number
operations penalise against. Expect this and round-5 item 2 together.

---

# 6. ⏳ Payment schedule and next payment date

Feasible now — the settlement schedule already stores the interval and the
last run, so the next date is derivable rather than invented.

Planned shape, on the wallet response:

```json
"schedule": "weekly",
"next_payment_date": "2026-09-08",
"schedule_description": "Every Monday"
```

Caveat we will honour: the stored schedule has a run-time and timezone that
nothing currently reads — the scheduler fires purely on the interval since the
last run. So `next_payment_date` will be a **date**, not a time, until that is
fixed. We will not send you a time we cannot keep.

---

# 7. ⏳ Maintenance window on `/app-status`

Confirmed: the response carries `maintenance_mode` only. The three fields you
asked for need new columns on the config table plus admin controls to set
them, so this is a migration and a panel change rather than a field add.

```json
"maintenance_started_at": "...", "maintenance_ends_at": "...", "maintenance_message": "..."
```

Agreed that an invented window is worse than none — keep the honest screen
until these are real.

---

# 8. ⏳ Notification severity

Agreed, and the pattern-matching risk is real. We will add `severity` to the
FCM data payload, `info | critical`.

Related, so you are not surprised: two notification categories the platform
declares are currently never emitted — money alerts are filed as `system`
rather than `payout`, and compliance notices as `system` rather than
`compliance`. If you build a category filter today it will be empty for those.
We are fixing the category mapping in the same change as `severity`.

---

# 9. ⏳ SESSION_REPLACED context

Agreed — the two cases are genuinely different and the app cannot tell them
apart. We will add:

```json
{ "code": "SESSION_REPLACED", "error": "session taken over",
  "replaced_by": { "device": "iPhone 14", "at": "2026-09-02T09:12:00Z" } }
```

Device labels come from the device check-in the apps already send, so the data
exists. Your interim wording is the right call meanwhile.

---

# 10. ⏳ Booking notes

Not built, and it needs the **rider** app as well — the rider writes the note,
the driver reads it. We will add it to the booking request and surface
`rider_note` on the ride payload you already read, so there is no extra call
on the hot path. See the rider-app reply for the write side.

---

# Round 5 carry-overs — honest status

| # | Item | Status |
|---|---|---|
| 1 | Cancellation history — who cancelled and why | ❌ Still not built |
| 2 | Fair stats — cancels not the driver's fault | ❌ Not built; bundled with item 5 above |
| 3 | Appeal decisions reaching the app with a reason | ⚠️ Decisions are stored with a reason; delivery to the app is not wired |
| 4 | Cancellation notifications carrying the reason | ❌ Not built |
| 5 | GDPR delete (same as rider) | ❌ Not built for driver |

No progress on these since round 5. Not going to dress that up.

---

# On your curl note

Confirmed and appreciated — Cloudflare's `error code: 1010` on a default curl
user-agent is a bot block, not a backend 403. Your browser-UA workaround is
the right one and we have used it throughout this reply.
