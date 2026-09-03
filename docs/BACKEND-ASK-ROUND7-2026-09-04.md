# Backend asks — driver app (round 7)

Raised 2026-09-04. Two items. Both are backend-side; the app needs no change
for either.

**Item 1 was raised in round 6 on 2026-09-03 and is still broken.** It was
re-tested against `api.hoppin.tech` with a live driver JWT at 17:10 on
2026-09-03 and returned the same unreachable URL. It blocks a Scope Lock
Document MUST.

**Item 2 is new** and affects the rider app as well as the driver app.

Both are scored against `247-SLD-001 Scope Lock Document v1.0.1`, which the
MVP is graded on. The relevant clauses are quoted under each item.

---

# 1. STILL BROKEN — document upload presigns to an unreachable host

**Severity: blocking. No driver can complete onboarding on any real device.**
**Status: unchanged since round 6 (raised 2026-09-03).**

## Scope Lock Document clauses this violates

> §Driver App / Digital Onboarding — "Drivers **MUST** be able to register
> digitally and submit all required documents, including valid PH driver
> licence (Wolverhampton or dual), DBS verification, medical certificate,
> right-to-work proof, and vehicle registration and insurance."

> §Driver App / Digital Onboarding — "Document formats are restricted to PDF
> and image formats (JPG/PNG), including camera capture."

> §Driver App / Digital Onboarding — "The expected onboarding completion SLA
> is within 24–72 hours."

No document can be submitted at all, so the submission requirement fails
outright and the 24–72h SLA clock cannot start. Onboarding is a Must-Have
core feature, not an enhancement.

## Re-test, 2026-09-03 17:10

`POST /drivers/me/documents/upload-url`, live driver JWT
(sub `daefcfb7-9e70-4e2a-9ce6-7953e274d8d3`), HTTP 200:

```json
{
  "upload_url": "http://minio:9000/test-verifier/driver-docs/daefcfb7-9e70-4e2a-9ce6-7953e274d8d3/dvla_license/67b7b96b-80ab-42c0-8be1-45ea6e018bf6.jpg?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=minioadmin%2F20260903%2Fus-east-1%2Fs3%2Faws4_request&X-Amz-Date=20260903T171054Z&X-Amz-Expires=300&X-Amz-SignedHeaders=host&x-id=PutObject&X-Amz-Signature=3c172dc3...",
  "key": "driver-docs/daefcfb7-.../dvla_license/67b7b96b-....jpg"
}
```

For contrast, `GET /drivers/me/status` returned 200 with real data in the
same session. The service is healthy. This one URL is the fault.

## Three faults in that URL

1. **`minio` is an internal Docker hostname.** Verified from outside the
   box: `Could not resolve host: minio`. No phone, browser or emulator can
   resolve it. There is no public alias either — `storage.hoppin.tech`,
   `minio.hoppin.tech` and `s3.hoppin.tech` are all unresolvable.
2. **It is plain `http`.** Android release builds block cleartext traffic by
   default, so even a resolvable host would fail on a real handset.
3. **The bucket is `test-verifier`**, which reads as a dev leftover rather
   than the intended documents bucket.

## What the driver sees

The app requests the slot (200), PUTs the bytes (cannot connect), and shows
*"There was a problem. Please try again later."*

## The app is not at fault

Its three-step presign → PUT → confirm flow is correct — see
`app/lib/features/documents/logic/upload_controller.dart:105`. Step 2 cannot
connect. An earlier investigation wrongly concluded "no backend wired"; it
is wired, to an address no client can reach.

## Two ways to fix it. We prefer option A.

### Option A — proxy the bytes through ride-service (recommended)

The machinery already exists in your codebase:
`internal/storage/s3.go:129` has `PutTo` and `:144` has `GetFrom`. `PutTo`'s
own comment already describes this exact fix:

> "PutTo streams an object straight into an explicit bucket. This backs the
> PROXY upload path: the app posts bytes to ride-service, ride-service
> validates and stores them. Nothing about the object store is ever exposed
> to the client, so MinIO stays private — no public bucket, no tunnel, no
> presigned URL whose host the browser has to be able to resolve."

Avatars already upload through that proxy path, so the pattern is proven in
production. The helper was written for this; it is just not wired to
documents.

Add `POST /drivers/me/documents/upload` accepting multipart form data:

| Field | Type | Notes |
|---|---|---|
| `document_type` | text | same values as the presign route accepts |
| `file` | file | JPG/PNG/PDF, per the SLD format restriction |

Returns the same shape the confirm step already returns, so the app collapses
three calls into one.

Why we prefer it:
- MinIO stays private. No tunnel, no public bucket, no CORS config.
- The MinIO credential never leaves the server.
- No DNS or TLS work.
- Fixes every client at once.

### Option B — presign against a public HTTPS base

Set `S3_PUBLIC_ENDPOINT` to a public HTTPS host, expose MinIO at it, and add
bucket CORS for `PUT`. No app change needed, but it needs DNS, a certificate,
and a bucket policy, and it puts MinIO on the public internet.

**Either is acceptable. Please pick one and say which.** Option A is roughly
40 lines against helpers that already exist.

## Also please confirm

- The intended production bucket name. `test-verifier` looks wrong.
- Whether uploaded documents are retained per the SLD's audit clause: "All
  document submissions and re-submissions MUST be logged and retained for
  audit and legal compliance."

---

# 2. NEW — `GET /rides/:id/geo` routes past intermediate stops

**Severity: high. Affects the rider app as well as the driver app.**

## Scope Lock Document clause this violates

> §Driver App / Navigation — "The app **MUST** provide in-app navigation
> using an integrated GPS/map provider (e.g., Google Maps or equivalent)."

> §Driver App / Navigation — "Route deviations are logged automatically. Fare
> recalculation applies where route length or duration materially changes."

## The fault

For a multi-stop ride, the endpoint makes **one** OSRM call from pickup
straight to dropoff, ignoring every intermediate stop. It returns a real,
road-legal polyline — which is what makes it dangerous. It looks
authoritative while telling the driver to drive past the stop the passenger
is waiting at.

A straight line would be visibly wrong and therefore safer. This is worse
than no route.

Knock-on effects:
- Route length is understated, so any distance-derived fare or deviation
  check computes against the wrong baseline — directly against the fare
  recalculation clause above.
- The driver's map disagrees with the stop list on the same screen.

## What we need

Route the polyline **leg by leg** through the stops in order:

```
pickup -> stop 1 -> stop 2 -> ... -> dropoff
```

and have any failing leg fall back to a threaded straight line for that leg
only, rather than discarding the whole route.

Also add waypoints to the response so the client can render the stops:

```json
{
  "polyline": "...",
  "waypoints": [
    { "lat": 52.586, "lng": -2.128, "label": "Queen Square" }
  ]
}
```

`waypoints` should always be an array, never `null`. **Labels must be
preserved** — the rider detail parser currently drops them, but on a driver's
screen the label is the whole point. The data is already in
`rides.waypoints`; booking stores the rider-picked labels as of `fa712b9`.

## A reference implementation exists

Commit **`7be6895`** in a local `Go_ride_service` clone does exactly this:
`RideGeoView` gains `Waypoints []WaypointView`, and the geo handler routes
leg by leg with a per-leg straight-line fallback. Types were hand-checked
against `osrmRouteGeometry`'s signature.

**It has never been compiled** — Go is not installed on the machine it was
written on — and it is unpushed. Treat it as a sketch of the intended shape,
not as a patch to merge. Take it, rewrite it, or ignore it; the requirement
is what matters. Say the word if you want it pushed to a branch.

---

# Summary

| # | Item | Status | Severity | SLD clause |
|---|---|---|---|---|
| 1 | Document upload URL unreachable | Raised round 6, still broken | Blocking | Digital Onboarding (MUST) |
| 2 | Geo route skips intermediate stops | New | High | Navigation (MUST) |

Item 1 has blocked driver onboarding for two days and is a config-or-40-lines
fix. It is the one we need a decision on today: **option A or option B?**
