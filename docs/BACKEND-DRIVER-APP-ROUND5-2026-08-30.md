# Backend — DRIVER app (round 5)

**Date:** 2026-08-30 · **Service:** `Go_ride_service` (`api.hoppin.tech`). Live.
Money is integer `*_pence`; nullable rates stay `null` (render "—").

---

## 1. Cancellation history — who cancelled, and why

`GET /drivers/me/trips` now tells the driver **what they cancelled vs what was
cancelled ON them**. Two new fields per trip (null on completed trips):
```jsonc
{ "id","ref","status","pickup_label","dropoff_label","distance_miles",
  "driver_earnings_pence","penalty_pence",
  "cancelled_by": "driver" | "rider" | "admin" | "system",
  "cancel_reason": "Rider didn't show up"   // human-readable, null if none recorded
}
```
- **New filter**: `?cancelled_by=driver` (only cancels the driver made) or
  `?cancelled_by=others` (cancelled on them). Combine with the existing
  `?status=cancelled`, `?from`/`?to`, `?cursor`, `?limit`.
- `"system"` = an automatic cancel (e.g. the matching-timeout watchdog), not the
  driver's fault — label it as such in the UI.

## 2. Fair Stats — cancels that aren't yours don't count

`GET /drivers/me/stats` `trips_cancelled` and `completion_rate` now count **only the
cancels the driver actually made**. A ride cancelled by the rider, an admin
force-cancel, or a watchdog timeout no longer drags down the driver's completion
rate. (Rating was already correct — it's the average of received reviews and is
unaffected by any cancellation.)

## 3. Appeals — the decision now reaches the app, with a reason

Every appeal decision now **carries the reviewer's reason** and is **pushed to the
driver app**:
- Admins must supply a note on **both** approve and reject (a rejection can no longer
  land with no explanation).
- On decision the driver gets a **notification** (`GET /me/notifications`,
  `type:"compliance"`, deep-link `hoppin://appeals`) **and** an FCM push
  (`data.type = "compliance_appeal"`, `decision`, `appeal_id`).
- The full record stays on `GET /drivers/me/compliance-appeals` — each item has
  `reason` (the driver's), `status`, **`review_note`** (the admin's reason),
  `reviewed_at`, `document_type`. Render `review_note` as the outcome explanation.

## 4. Cancellation notifications carry the reason

When a ride is cancelled, the counterparty's push/notification now includes the
reason, e.g. *"Your driver cancelled this ride. Reason: Vehicle issue. Please request
another ride."* — no app change needed, the copy arrives server-side.

---

## GDPR delete button (same as rider)

`POST /me/delete-account` executes the erasure when eligible (200
`{status:"deleted"}`) or returns `409 DELETION_BLOCKED` with `blockers`. Driver-only
blocker codes: `active_trip`, `unresolved_dispute`, **`outstanding_balance`** (settle
the wallet first), **`compliance_investigation`** (documents pending review). Show a
confirm dialog first — irreversible. Backend scrubs all PII and detaches the driver's
documents; ride/payment/ledger history is retained de-identified.

## Already live (confirmed this round — no app change needed)

- **Live pickup ETA to the driver**: the driver context/today payload carries
  `pickup_eta_seconds` (live OSRM ETA to the rider) for the trip-screen countdown. ✅
- **Dropped/unmatched rides**: dispatch re-queues an unmatched request for 5 min
  before giving up. ✅

_Round-4 items (Stats, ledger wallet + "you owe/we owe", R- refs, penalties list,
ride-chat receipts + reply) remain as delivered._
