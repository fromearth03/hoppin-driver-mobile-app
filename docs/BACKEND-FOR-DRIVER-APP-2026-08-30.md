# Backend — DRIVER app handover (complete)

**Date:** 2026-08-30 · **Service:** `Go_ride_service` (`:8080`) · Supersedes the 08-27 driver doc.

Everything below is **merged and deployed live** unless marked ⏳/⚠️. Conventions:
**money is integer `*_pence` (int64)**, **snake_case**, **nullable rates stay `null`**
(render "—", never `0%`). Full error-code reference:
`BACKEND-DRIVER-ERROR-CODES-2026-08-30.md`.

---

## Money

### `GET /api/v1/drivers/me/wallet`
`available_balance` is computed from the **ledger** (source of truth), can be
**negative** (driver owes). Same shape as before, real numbers now.

### `GET /api/v1/drivers/me/ledger` — statement
Params: `from`/`to` (`YYYY-MM-DD`) · `cursor` · `limit` (default 50, max 100).
```jsonc
{ "balance_pence":-5000,"currency":"GBP","as_of":"…",
  "entries":[{ "id","created_at","amount_pence":-300,"entry_type":"penalty",
     "display_title":"Late arrival penalty",           // SERVER-OWNED — render verbatim
     "display_reason":"A penalty for arriving late to a pickup.",
     "ride_id":"uuid"|null,"running_balance_pence":-5000 }],
  "next_cursor":"opaque"|null }
```
Never synthesise copy from `entry_type`/`reason`. Unmapped rows come back titled
`"Adjustment"`. Copy makes **no** VAT / "deducted from your payout" claim (legal).
`GET …/ledger/summary?period=week|month` → `{period,opening_pence,credits_pence,debits_pence,closing_pence,currency}`.
Dispute a charge → `POST /me/support-tickets` with `ledger_entry_id`.

## Presence & going online

### `GET /api/v1/drivers/me/status`
```jsonc
{ "presence":"online"|"stale"|"offline",  // stale = online but GPS >90s old
  "last_location_at":"…"|null,"stale_after_seconds":90,"dispatchable":true,
  "blocked_reason":null,               // see tokens below; null when clear
  "blocking_document_types":["…"],     // present only for DOCS_* reasons
  "active_ride_id":"uuid"|null }
```
`blocked_reason` uses the **same vocabulary as a `POST /drivers/me/online` refusal**:
`SUSPENDED·RESTRICTED·DELETION_REQUESTED·DOCS_MISSING·DOCS_PENDING_REVIEW·DOCS_REJECTED·
DOCS_EXPIRED·NO_VEHICLE·DEVICE_BLACKLISTED·PAYOUT_NOT_READY·UNKNOWN`. So the blocked-
from-online screen keys off one set whether it learns the state here or from the toggle.

### `POST /api/v1/drivers/me/online` — refuses 3 ways
`NOT_ELIGIBLE` (403, with `reason` from the set above + `blocking_document_types`) ·
`DEVICE_BLACKLISTED` (403) · `PAYOUT_NOT_READY` (403). Full table in the error-code doc.

## Offers — `GET /api/v1/drivers/me/offers`
`PendingOffer` widened: `fare_pence` (int64 — use this; `fare` float deprecated),
`pickup_label`, `dropoff_label`, `ride_category`, `estimated_duration_seconds`,
`pickup_eta_seconds`. Rider identity is deliberately NOT on the offer — bind
`/rides/:id/rider-context` after acceptance.

## Trips — `GET /api/v1/drivers/me/trips`
Params: `limit` (max 200) · `cursor` · `status` (`completed`|`cancelled`) · `from`/`to`.
```jsonc
{ "trips":[{ "id","completed_at","status","pickup_label","dropoff_label",
     "distance_miles":3.2,"driver_earnings_pence":830,"penalty_pence":0 }],
  "next_cursor":"…"|null,"has_more":true }
```
- **A18** cursor paging (was limit-only → silent truncation past 200).
- **A19** cancelled trips now included (was hardcoded `completed`), with
  `penalty_pence`, so a driver has a record to dispute.

## Live ETA — **A15 (done)**
`pickup_eta_seconds` is now populated on both `GET /rides/:id/rider-context` and
`GET /drivers/me/today` — a live OSRM ETA from the driver's position (pickup while
approaching, dropoff once on-road). The driver sees their own ETA, same as the rider.

## Chat unread — **A17**
`GET /rides/:id` returns **`chat_unread`** (messages from the rider since the driver
last opened the thread) — badge the chat button. Opening `GET /rides/:id/messages`
clears it.

## Documents — `GET /api/v1/document-types` + `GET /api/v1/drivers/me/documents`
- `/document-types` returns all 8 enum values; each has `uploadable` (false =
  operator-run, e.g. `nr3s_background_check` — show status, no upload) and `expires`.
- **A21 (done end-to-end)** `/drivers/me/documents` returns **`rejection_reason`**
  (nullable), and the **admin reject flow now writes it** (cleared on approve) — a
  rejected doc tells the driver WHY instead of a blind re-upload.

## Earnings breakdown — **A1 (done)**
`ride_earnings` is now **populated at settlement** from the same pricing engine as
the charge — the full 9-line breakdown (`base/distance/time/surge/waiting/commission/
tax/penalty/net`, integer pence). `GET /rides/:id/earnings` serves it. Historical
rides (pre-this-change) keep the existing 3-line `payout_splits` fallback, so both
render — no `£0.00` lines. (tax stays 0 until VAT is modelled; penalties are
separate ledger entries.)

## Cancel reasons — `GET /api/v1/cancellation-reasons`
- **A23** adds `penalty_fee_pence` (int64; the float `penalty_fee_amount` is deprecated).
- **A22** adds `pickable` — **false** for system outcomes (`driver_declined`,
  `offer_timeout`). Show only `pickable:true` in the picker, so it never lists a raw
  slug and you never prettify one client-side.

---

## ✅ Also done this round
- **A16 · road route** — `GET /rides/:id` `geo.route` is now the ACTUAL OSRM
  road-following polyline (best-effort; straight-line fallback). The map draws the
  real route.
- **A15 · driver ETA** — live OSRM `pickup_eta_seconds` on rider-context + today.

## ⚠️ The one genuine gap left (needs the payment service)
- **Transactions card brand/last4** ("Visa ••8901") — not stored anywhere. Place
  labels are served; the card details need the **Java payment service** to capture
  the PaymentMethod brand/last4 from Stripe at charge time and store them. Until
  then, render the payment method generically (e.g. "Card"). Scoped follow-up, not
  a ride-service change.
- **A20** — stale comment only; no action.

## Cross-cutting
Money integer pence throughout the new work. Nullable rates stay null. No WebSocket/
SSE on the driver app — FCM push + polling. Ledger balance signed (negative = owes).
