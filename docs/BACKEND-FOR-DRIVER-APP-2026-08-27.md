# Backend — implemented (handover to the DRIVER app dev)

**Date:** 2026-08-27 · **Service:** `Go_ride_service` (`:8080`)

Covers the driver-app asks in `002-backend-asks-driver-app.md`. Everything below
is **merged to `main`** and **takes effect once the ride-service is redeployed** —
build against these shapes now; they are stable.

Conventions: **money is integer `*_pence` (int64)**, **snake_case**, **nullable
rates stay `null`** (render "—", never `0%`).

---

## ✅ Implemented

### A2 · `GET /api/v1/drivers/me/wallet` — real balance
`available_balance` is now computed from the **ledger** (the source of truth) at
read time, not the stale `driver_wallets` (which read £0.00 for everyone). It can
be **negative** — a driver genuinely in debt. Same JSON shape as before; just real
numbers now.

### A3 · `GET /api/v1/drivers/me/ledger` — statement (NEW)
Params: `from`/`to` (`YYYY-MM-DD`), `cursor`, `limit` (default 50, max 100).

```jsonc
{
  "balance_pence": -5000,      // signed; NEGATIVE = the driver owes
  "currency": "GBP",
  "as_of": "2026-08-27T18:50:00Z",
  "entries": [{
    "id":"uuid","created_at":"…",
    "amount_pence": -300,       // signed, int64
    "entry_type": "penalty",
    "display_title": "Late arrival penalty",           // SERVER-OWNED — render verbatim
    "display_reason": "A penalty for arriving late to a pickup.",
    "ride_id": "uuid",          // nullable (standalone entries have none)
    "running_balance_pence": -5000
  }],
  "next_cursor": "opaque|null"
}
```
**Render `display_title` / `display_reason` verbatim.** Never synthesise copy from
`entry_type` (or `reason`/`rule_name` — those are internal, some are test junk). An
unmapped row comes back titled `"Adjustment"` with an empty reason — show the
amount under a neutral label, don't invent a cause. The copy deliberately makes
**no** VAT or "deducted from your next payout" claim (pending business/legal
sign-off) — do not add either client-side.

`GET /api/v1/drivers/me/ledger/summary?period=week|month` →
`{ period, opening_pence, credits_pence, debits_pence, closing_pence, currency }`.

**Disputes:** there is no ledger-dispute endpoint — wire the "Dispute Charge"
button to `POST /me/support-tickets` with the `ledger_entry_id` in the body (the
path you proposed — confirmed acceptable).

### A6 · `GET /api/v1/drivers/me/status` — presence (NEW)
```jsonc
{
  "presence": "online"|"stale"|"offline",   // stale = online but GPS >90s old
  "last_location_at": "…"|null,
  "stale_after_seconds": 90,
  "dispatchable": true,
  "blocked_reason": null,                    // suspended|document_expired|payout_not_ready
  "active_ride_id": "uuid"|null
}
```
Show the **`stale`** state loudly — "You're online but your location hasn't
updated — you are not receiving offers." It's the silent drop-from-dispatch case.
`blocked_reason` explains a state the driver **can't self-fix in-app** (payouts are
admin-run): show an honest explainer telling them to contact ops, not a dead
button.

### A4 · `PendingOffer` widened — `GET /api/v1/drivers/me/offers`
Added fields: **`fare_pence`** (int64 — use this), `pickup_label`, `dropoff_label`,
`ride_category`, `estimated_duration_seconds`, `pickup_eta_seconds`. `fare` (float)
kept for compat but **deprecated**. Labels / ETA / duration may be null.

Rider identity is **not** on the offer, by design (cherry-picking + UK equality-law
risk). Bind `GET /rides/:id/rider-context` **after** acceptance for name/photo/rating.

### A5 · `GET /api/v1/document-types` — fixed + widened
Now returns **all 8** enum values (was 7). Each item gains `uploadable` and
`expires`:
```jsonc
{ "code":"nr3s_background_check","label":"NR3S Background Check",
  "required":true,"uploadable":false,"expires":false }
```
- `uploadable:false` = operator-run (e.g. NR3S background check). Show its status;
  do **not** offer an upload — that would `400`. (NR3S is kept out of the upload
  allowlist.)
- `expires:true` = collect an expiry date (MOT, insurance, licence, taxi badge,
  CAZ); `false` = don't (logbook, right-to-work, NR3S).

---

## ⏳ Needs a decision / config (NOT built yet)

- **A1 · `ride_earnings` (per-trip breakdown)** — still empty (0 rows). The 9-line
  table needs the fare **decomposition** confirmed before it can be populated
  safely: the pricing engine models **surge as a multiplier**, not a per-line
  amount, so mapping it to `surge_pence` is ambiguous, and VAT/tax treatment is
  undecided. **For now, bind the breakdown to `payout_splits`** — 3 real,
  populated lines (driver earnings / commission / tax) — and design a 3-line
  breakdown. The 9-line `ride_earnings` will be populated the moment the
  decomposition is signed off. (Same "which is canonical" question your doc
  raised — this is the answer: payout_splits now, ride_earnings later.)

- **A8 · migration 113** (`support_ticket_fault_party`) — not yet applied to prod;
  will go in via the `Go_Database` migrator on the next DB deploy. `fault_party`
  won't exist until then.

## Confirmed as-is (per your doc)
- **A7 penalty appeals** — no penalty-appeal endpoints; route "Dispute" to a
  support ticket (see A3). Keep the appeals UI on the Documents screen.
- **A9 tips** — `driver_tips` exists but is empty; tipping isn't live. **Omit the
  Tips line** rather than showing a permanent £0.00.
- **A10 multi-stop** — Phase 2. `rides.waypoints` is now readable via
  `GET /rides/:id` (`geo.waypoints`) when you get there.

## Cross-cutting (kept, per §9)
Money is integer pence everywhere new. Nullable rates stay null (render "—"). No
WebSocket/SSE for the driver app — FCM push + polling. Ledger balance is signed
(negative = owes).
