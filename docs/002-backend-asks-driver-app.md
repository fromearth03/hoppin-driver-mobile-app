# Backend Asks — Driver Mobile App (Flutter, fresh build)

**To:** Backend team, Hoppin
**From:** Driver app build
**Date:** 2026-08-27
**Service:** `Go_ride_service` (`:8080`) — the only service the driver app talks to

---

## 0. How this document was produced

Every claim below is verified against the **live production database**, not against migration files or docs.

- Connected to Supabase Postgres **17.6** (`aws-1-ap-southeast-1` pooler) on 2026-08-27.
- Route table extracted from `Go_ride_service/internal/handler/ride_handler.go` → `RegisterRoutes`.
- Schema and row counts read from `information_schema` and the live tables.

Where I say "0 rows" or "live value", that is what the production database contained on that date.

> ⚠️ **`docs/420-figma-correction-pack.md` (2026-07-13) is stale.** It reports driver earnings, stats, appeals, waiting-policy and cancel-reasons as non-existent. All of them shipped since. Please don't use it as the gap register — this document supersedes it for the driver app.

**Standing rule for this app:** the driver app renders **no figure the server did not send**. For a rider an indicative estimate is a courtesy; for a driver an indicative *debt* is a liability. Everything below is either bound to a real endpoint or explicitly deferred.

---

## 1. Priority summary

| # | Ask | Severity | Why |
|---|---|---|---|
| **A1** | Populate `ride_earnings` (0 rows live) | 🔴 **Blocker** | Every per-trip fare breakdown renders £0.00 today |
| **A2** | Fix `driver_wallets` (all zeros; ledger is authoritative) | 🔴 **Blocker** | `GET /drivers/me/wallet` shows every driver £0.00 |
| **A3** | `GET /drivers/me/ledger` — statement + balance, with driver-safe reason copy | 🔴 High | Unblocks the "You Owe / We Owe" screens |
| **A4** | Widen `PendingOffer` payload | 🟠 High | Offer cards currently cannot show addresses |
| **A5** | Driver-facing `document_type` mismatch (8 in DB, 7 allowed in code) | 🟠 Medium | Uploading `nr3s_background_check` 400s |
| **A6** | Expose `GET /drivers/me/status` (presence/relaunch) | 🟠 Medium | App cannot confirm online state after restart |
| **A7** | Penalty appeals (currently document-scoped only) | 🟡 Medium | Stats shows penalties with no way to contest |
| **A8** | Apply migration 113 | 🟡 Low | Unapplied in production |
| **A9** | Tips exposure | 🟡 Low | Table exists, never populated or surfaced |
| **A10** | Multi-stop read path | ⚪ Phase 2 | Deferred by product |

---

## 2. 🔴 A1 — `ride_earnings` is empty in production

**Verified live:**
```sql
select count(*) from rides where status='completed';   -- 36
select count(*) from ride_earnings;                    -- 0
```
36 completed rides, **zero** breakdown rows.

The table is correctly shaped (`base_pence`, `distance_pence`, `time_pence`, `surge_pence`, `waiting_pence`, `commission_pence`, `tax_pence`, `penalty_pence`, `net_pence`) and `GET /rides/:id/earnings` reads it — but nothing writes it. The handler falls back to `payout_splits`, which carries only three figures:

| `payout_splits` has | `ride_earnings` promises |
|---|---|
| `driver_earnings_amount` | base / distance / time / surge / waiting |
| `hopin_commission_amount` | commission |
| `municipal_tax_amount` | tax |
| — | penalty, net |

**Impact:** the Finish Ride summary and the Earnings breakdown are the two screens a driver checks most. Both would render a correct total with **every component line at £0.00**. That is worse than showing nothing.

### Ask
Write a `ride_earnings` row at ride settlement, populated from the same `hoppin_pricing` `Quote` used for the final charge. Backfill the 36 existing completed rides if the inputs are still recoverable.

**Please confirm** whether `ride_earnings` is intended as the canonical per-trip breakdown. If it has been superseded, say so and we will bind the UI to `payout_splits` and design a 3-line breakdown instead of a 9-line one. **We need one of the two to be true — right now neither is.**

---

## 3. 🔴 A2 — `driver_wallets` is all zeros; the ledger is authoritative

**Verified live:**
```sql
select count(*), count(*) filter (where available_balance <> 0) from driver_wallets;
-- 20 drivers, 0 with a non-zero balance

select count(*), count(*) filter (where net < 0) from
  (select account_id, sum(amount) net from ledger_entries
    where account_type='driver' group by account_id) t;
-- 10 accounts, 2 currently in debt (most negative: -£50.00)
```

`driver_wallets.available_balance` is **0.00 for all 20 drivers**, while `ledger_entries` holds real money and **two drivers are genuinely in debt**. Migration 046 asserts the invariant `driver_wallets.available_balance == SUM(ledger entries)`. **That invariant is currently violated for every driver.**

`GET /drivers/me/wallet` reads `driver_wallets`. So it returns £0.00 to everyone, including the two drivers who owe money.

### Ask
Either (a) restore the invariant by having every ledger write update `driver_wallets`, or (b) retire `driver_wallets` and compute balance as `SUM(ledger_entries)` at read time. **We do not mind which — we need to know which one is the source of truth**, because the driver app will bind to it and show a person their own money.

---

## 4. 🔴 A3 — `GET /drivers/me/ledger` (new endpoint)

This is the ask that unblocks the "You Owe the Company" / "What the Company Owes You" screens.

### What already exists (please don't rebuild it)
`ledger_entries` is a proper immutable double-entry ledger and it is **live and in use**:
- Signed `numeric(12,2)`; `(+)` credits, `(-)` debits
- `account_type` ∈ `driver | rider | platform`
- UNIQUE `idempotency_key` — replays never double-post
- **12 entry types observed live:** `earning`, `commission`, `payout`, `payout_reversal`, `rider_charge`, `bonus`, `penalty`, `adjustment`, `opening_balance`, `refund`, `rider_fee`, `driver_credit`
- **`notified_at` already exists** (migration 079) — built to mark whether the driver was told about a charge. There is already an admin money-notifier sweeping unnotified rows.
- **Every live row has a non-null `reason`.**

The gap is narrow: the driver-facing earnings query joins the ledger only `WHERE ride_id = r.id AND entry_type = 'penalty'`, and is scoped **per completed ride**. A standalone entry (`ride_id IS NULL`) — a weekly levy, an admin adjustment, a payout reversal — is **invisible to the driver**. Live, that is 74 of the entries.

### Proposed contract
```
GET /api/v1/drivers/me/ledger?from=YYYY-MM-DD&to=YYYY-MM-DD&cursor=&limit=50
```
```jsonc
{
  "balance_pence": -5000,          // signed; NEGATIVE means the driver owes
  "currency": "GBP",
  "as_of": "2026-08-27T18:50:00Z",
  "entries": [
    {
      "id": "uuid",
      "created_at": "2026-08-26T09:12:00Z",
      "amount_pence": -300,        // signed, pence, int64
      "entry_type": "penalty",
      "display_title": "Late arrival penalty",
      "display_reason": "You arrived more than 10 minutes after the quoted ETA.",
      "ride_id": "uuid|null",
      "running_balance_pence": -5000
    }
  ],
  "next_cursor": "opaque|null"
}
```

### 🔴 The critical part: `display_title` and `display_reason`

**The owner's explicit requirement: a driver must be told *why* they were charged, for every single deduction.**

The existing `reason` column is **internal shorthand and cannot be shown to a driver**. Real values live today:

| Live `reason` | Live `rule_name` |
|---|---|
| `manual payout` | `Driver Late Penalty` |
| `transfer failed refund` | `Cancellation penalty` |
| `trip earnings` | `cancellation` |
| `mid-trip cancel: fare + compensation` | **`test`** |
| `driver bonus: TESTDRIVE` | **`tse5`** |

Two of the live `rule_name` values are literally test junk (`test`, `tse5`), and `driver bonus: TESTDRIVE` leaks an internal promo code.

**So please return two separate server-owned fields:**
- `display_title` — short label, e.g. *"Late arrival penalty"*
- `display_reason` — one plain-English sentence a driver can act on

Both must be **server-owned**, so wording can be corrected without an app release. The app will render them verbatim and will **never** synthesise copy from `entry_type` or `rule_name`. If a row has no display copy, we render the amount with a neutral "Adjustment" label rather than inventing a cause.

### Two things we will NOT encode without a written business decision
1. **VAT treatment (principal vs agent).** The ledger has no VAT entry type. We will not label any line "VAT" unless the server sends that label.
2. **"Auto-deducted from your next payout."** The mechanism exists (`settlement_schedules.min_payout`, `auto_retry`), but this is a statement about deductions from a **self-employed worker's pay** — live UK legal exposure. We will only show wording the business has signed off. Please send it as `display_reason` rather than have us hardcode it.

### Also useful
`GET /drivers/me/ledger/summary?period=week|month` → `{opening_pence, credits_pence, debits_pence, closing_pence}` so the screen can show a period statement without paging the whole list.

### Disputes
There is **no dispute endpoint** for a ledger entry. Unless you want to add one, we will wire the Figma "Dispute Charge" button to `POST /me/support-tickets` with the `ledger_entry_id` in the body. **Please confirm that is acceptable**, or add a `POST /drivers/me/ledger/:id/dispute`.

---

## 5. 🟠 A4 — Widen the offer payload

**Current `PendingOffer` (verified in `ride_repo.go`):**
```
offer_id, ride_id, pickup_lat, pickup_lng, dropoff_lat, dropoff_lng,
fare, estimated_miles, expires_at, offered_at
```

Coordinates only — **no address text**. A driver deciding whether to accept a job sees two lat/lng pairs.

We can reverse-geocode client-side via `GET /geocode/reverse`, but that means N round-trips per offer list, on mobile data, inside a countdown the driver is racing. It also burns geocode quota on offers that are declined.

Note `rides.pickup_label` / `dropoff_label` exist — but they are populated on only **29 of 66 rides** live, and in any case are not on the offer.

### Ask — please add to `PendingOffer`
| Field | Type | Why |
|---|---|---|
| `pickup_label` | string | Show where the job starts |
| `dropoff_label` | string | Show where it ends |
| `ride_category` | string | standard / xl / accessibility — affects the vehicle needed |
| `estimated_duration_seconds` | int | "£20 for 45 min" is the real accept/decline decision |
| `pickup_eta_seconds` | int | How far away the pickup is |

`fare` should also be `fare_pence` (int64) — see §9 on money types.

### Deliberately NOT requested: rider identity
The Figma offer cards show rider **name, photo, star rating and comments** pre-acceptance. We are **not** asking for these, for two reasons:
1. It enables cherry-picking by rider rating.
2. Rider name/photo pre-acceptance carries discrimination risk under UK equality law.

`GET /rides/:id/rider-context` already provides all of it **after** acceptance, which is the right moment. We will bind there. Flagging it so the design change is understood as deliberate, not an oversight.

---

## 6. 🟠 A5 — `document_type` mismatch: 8 in the DB, 7 in the code

**Verified live:**
```sql
select unnest(enum_range(null::document_type));
-- dvla_license, wolverhampton_taxi_badge, nr3s_background_check, right_to_work,
-- mot_certificate, insurance_policy, v5c_logbook, caz_compliance_proof   (8 values)

select document_type, count(*) from driver_documents group by 1;
-- includes nr3s_background_check | approved | 1
```

The Postgres enum has **8** values. `document_service.go` `allowedDocumentTypes` permits **7** — it omits `nr3s_background_check`. But a real, approved `nr3s_background_check` document **exists in production**.

So: a driver whose NR3S check needs re-upload gets `400 VALIDATION_FAILED`, and the onboarding checklist from `GET /document-types` will never list it.

### Ask
Confirm which is correct and align them:
- If NR3S is a driver-uploadable document → add it to `allowedDocumentTypes` and `documentTypeCatalog`.
- If it is admin-only (a background check the operator runs) → keep it out of the upload allowlist, but **still return it in `GET /document-types`** flagged `"uploadable": false`, so the driver can see its status without being offered a broken upload.

**Also please add to `GET /document-types`:** an `expires` boolean. The upload form collects an expiry date for every type, but MOT and insurance genuinely expire while a taxi badge behaves differently. Right now the client has to guess.

---

## 7. 🟠 A6 — `GET /drivers/me/status`

There is no endpoint that answers "am I online right now?".

`GET /drivers/me/today` returns `online` and `active_ride_id`, which partly covers relaunch — we will use it. But it is a dashboard aggregate (earnings, trip count, online seconds); polling it purely for a presence check is heavy.

The deeper problem: a driver whose GPS has gone stale is **silently dropped from dispatch**. Telemetry stops writing `hex:available:{cell}`, the dispatch K-ring stops finding them, and no error is raised anywhere. The driver sits there believing they are online, receiving nothing.

### Ask
```
GET /api/v1/drivers/me/status
```
```jsonc
{
  "presence": "online" | "stale" | "offline",
  "last_location_at": "2026-08-27T18:49:12Z",
  "stale_after_seconds": 90,
  "dispatchable": true,
  "blocked_reason": null,          // "payout_not_ready" | "document_expired" | "suspended"
  "active_ride_id": "uuid|null"
}
```

`presence: "stale"` is the important one — it lets us show *"You're online but your location hasn't updated — you are not receiving offers"*. **Better a driver who knows they are offline than one who thinks they are online.**

`blocked_reason` also matters: `POST /drivers/me/online` already returns `PAYOUT_NOT_READY` and `DEVICE_BLACKLISTED`. Since **driver payouts are administered in the admin panel, not this app**, a driver hitting `PAYOUT_NOT_READY` has no in-app remedy. We need the reason so we can show an honest explainer telling them to contact ops — not a dead button.

---

## 8. 🟡 A7 — Penalty appeals

`POST /drivers/me/compliance-appeals` takes `{document_type, reason}` — it appeals a **document**, not a penalty. 8 rows live.

`GET /drivers/me/stats` returns `penalties_active` (a bare count). There is **no endpoint to list those penalties and no way to contest one**. The admin API has full appeal-review machinery (list/approve/reject with a driver-authored reason), so admins can decide appeals that no driver can file for a penalty.

**Product decision taken:** we are moving the appeals UI onto the **Documents** screen, where it is genuinely backed. Stats will show `penalties_active` as a plain count with no appeal affordance.

### Ask (not blocking Phase 1)
If penalty appeals are wanted, we need:
- `GET /drivers/me/penalties` → list with `id`, `amount_pence`, `display_title`, `display_reason`, `created_at`, `appealable`, `appeal_status`
- `POST /drivers/me/penalties/:id/appeal` → `{reason}`

Until then the driver's only route to contest a charge is a support ticket. **Please confirm that is the intended path** so we can word the UI accordingly.

---

## 9. Cross-cutting requests

### 9.1 Money must be integer pence everywhere
`ride_earnings` correctly uses `bigint` pence. But `ledger_entries.amount`, `driver_wallets.*`, `deduction_rules.amount` and `PendingOffer.fare` are `numeric`/float. Dart has no decimal type; `double` will introduce rounding drift on a screen showing someone their pay.

**Ask:** every money field crossing the API as `*_pence` (int64), or documented as a decimal string. Never a JSON float.

### 9.2 Nullable rates must stay nullable
`GET /drivers/me/stats` already does this correctly — omitting a rate whose denominator is zero rather than sending `0.0`. **Please keep that.** A driver with no offers this week has no acceptance rate, and `0%` reads as a catastrophic week. We render "—".

### 9.3 Realtime transport
There is no WebSocket or SSE endpoint (`gin-contrib/sse` is an indirect dependency only). The app will use **FCM push + polling**.

**Please confirm acceptable poll intervals** for `/drivers/me/offers`, `/rides/:id`, and `/rides/:id/messages`, and whether we should back off when the app is backgrounded. If a push-first design is preferred for offers, tell us which FCM payloads to expect. We would rather agree this than discover a rate limit in production.

### 9.4 Error envelope
Handlers use `errEnvelope(code, message)` with codes like `VALIDATION_FAILED`, `NO_SHOW_TOO_EARLY`, `PAYOUT_NOT_READY`, `DEVICE_BLACKLISTED`, `ILLEGAL_TRANSITION`. **Please publish the full code list.** We map codes to user-facing copy; an unlisted code becomes a generic error, which is a worse experience.

### 9.5 Migration 113 unapplied
`schema_migrations` has 117 rows, latest `112_ride_categories_waiting_defaults.sql`. **`113_support_ticket_fault_party.sql` is not applied** and `support_tickets.fault_party` does not exist live. Intentional or missed?

### 9.6 Tips (`driver_tips`)
Table exists (8 columns) but has **0 rows**, and no tips field is exposed in `RideEarnings` or `EarningsSummary`. The Figma earnings breakdown shows a Tips line.

**Ask:** confirm whether tipping is live. If yes, add `tips_pence` to the per-ride and summary payloads. If no, we omit the row entirely rather than showing a permanent £0.00.

---

## 10. ⚪ A10 — Multi-stop (Phase 2, not now)

**Deferred by product decision.** Recorded so it isn't lost.

Live state: `rides.waypoints` (jsonb) and the `ride_waypoints` table both exist — the latter with `waypoint_type` (`pickup`/`dropoff`/`mid_route_stop`), `sequence_order`, PostGIS `geom`, and estimated/actual arrival times. **Both are empty: 0 rows.** Bookings accept a `waypoints[]` array and write it, but `models.Ride` has no waypoints field and `RideGeoView` returns only pickup/dropoff, so **no driver endpoint can read them back**.

Phase 1 ships a 2-stop UI. For Phase 2 we will need `waypoints[]` exposed on `GET /rides/:id` or `/rides/:id/geo`, with `sequence_order` and per-stop arrival timestamps. We are keeping the client's stop list a collection internally so this is a data change, not a rewrite.

---

## 11. What we are NOT asking for

To keep the register honest and avoid handing you false priorities:

| Not asked | Why |
|---|---|
| **Driver payout setup / bank details** | Owner ruling: payouts are administered in the **admin panel**. `driver_bank_accounts` and `payment_methods` are both **dropped** from the live schema, confirming this. We need only the `PAYOUT_NOT_READY` reason (§7). |
| **Voice calling / masked numbers** | Phase 2. No VoIP provider exists in the mesh. Phase 1 is chat-only via `/rides/:id/messages`. |
| **Rider identity on offers** | Deliberately declined — see §5. |
| **Referrals** | `referral_tracking` was created in migration 001 and **dropped in 002**. Not in the live schema. Not wanted. |
| **A driver-side i18n endpoint** | `preferences.language` exists and validates, but the app has no i18n. We are hiding the row rather than persisting a setting that does nothing. |

---

## 12. Reference — verified live values

Useful for anyone reasoning about the driver app. All read from production on 2026-08-27.

**Fare config (`ride_categories`, active):**

| Category | Base | Per mile | Per min | Minimum | Platform fee |
|---|---|---|---|---|---|
| standard | £2.50 | £1.25 | £0.20 | £4.00 | 20% |
| accessibility | £2.50 | £1.25 | £0.20 | £4.00 | 20% |
| xl | £3.50 | £1.75 | £0.30 | £6.00 | 20% |

**Waiting:** 3 free minutes, then **£0.30/min** (all categories).

**Driver cancellation reasons (active):** `driver_declined` (no penalty) · `offer_timeout` (no penalty) · "Rider did not show up" / `rider_no_show` (**penalty £59.00**, `free_cancel_seconds` 300).

**Deduction rules (active, target=driver):**

| Rule | Amount | Frequency | Event |
|---|---|---|---|
| Insurance Levy | £0.45 | per_ride | — |
| Driver Late Penalty | £3.00 | per_event | `driver_late` |
| Low Rating Penalty | £2.00 | per_event | `low_rating` |
| Passenger Complaint Penalty | £10.00 | per_event | `passenger_complaint` |

**Enums:** `verification_status` = `pending_review, approved, rejected, expired` · `ride_status` = `requested, matching, assigned, accepted, arriving, started, completed, cancelled, failed` · `waypoint_type` = `pickup, dropoff, mid_route_stop`

**Row counts:** rides 66 (36 completed, 24 cancelled) · `ride_earnings` **0** · `ledger_entries` 161 · `deduction_applications` 56 · `compliance_appeals` 8 · `driver_online_sessions` 31 · `payout_splits` 26 · `settlement_runs` 6 · `ride_messages` 2 · `driver_tips` **0** · `ride_waypoints` **0** · `issue_appeals` **0**

---

## 13. What we need back

Ordered by what blocks us soonest.

1. **A1** — is `ride_earnings` canonical? If yes, populate it. If no, tell us to bind to `payout_splits`. *(Blocks the two most-used screens.)*
2. **A2** — is `driver_wallets` or the ledger the source of truth for balance? *(Blocks any balance display.)*
3. **A3** — agreement on `GET /drivers/me/ledger`, especially **server-owned `display_title` / `display_reason`**. *(Blocks the You-Owe screens; deferred until it lands.)*
4. **A4** — offer payload widening. *(We can ship without it using reverse-geocode, but it is a worse product.)*
5. **A5** — the `nr3s_background_check` mismatch. *(Small fix, real 400 today.)*
6. **§9.3** — acceptable poll intervals + FCM payload shapes. *(Needed before we finalise the data layer.)*
7. **§9.4** — the full error-code list.

Items A6, A7, A9 and A10 are not Phase-1 blockers. We will ship honest degraded states for each and bind them when they land.

Happy to jump on a call for A1–A3 — they are all "which of these two is the truth" questions and would take ten minutes to settle.
