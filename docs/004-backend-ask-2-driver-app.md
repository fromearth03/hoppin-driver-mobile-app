# Backend Ask-2 — Driver Mobile App

**To:** Backend team, Hoppin
**From:** Driver app build
**Date:** 2026-08-27
**Service:** `Go_ride_service` (`:8080`)

**Previous round:** `002-backend-asks-driver-app.md` (Ask-1, items A1–A10)
**Your reply:** `BACKEND-FOR-DRIVER-APP-2026-08-27.md`

> **Numbering:** asks roll up across rounds and never restart. Ask-1 was **A1–A10**; this round is **A11–A23**. Reference them by number in replies so we can track each to closure.

---

## 0. Thank you — and what we verified

Ask-1 came back with five endpoints merged in a day. We checked the work against the merged code on `origin/main`, not just your handover note, and it all holds up:

- **A2** — wallet now computes from the ledger at read time. The £0.00-for-everyone bug is gone.
- **A3** — `/ledger` + `/ledger/summary` exist with signed balances, per-entry running balance and cursor pagination.
- **A4** — `PendingOffer` carries `fare_pence`, both labels, category, duration and pickup ETA.
- **A5** — `document-types` returns all 8 with `uploadable` / `expires`.
- **A6** — `/status` with the `stale` presence state.

Two things we want to call out specifically, because they were the hard parts of the ask and you got them right:

**`ledgerDisplay()` / `penaltyDisplay()` is exactly the right shape.** Server-owned copy, correctable by a backend release rather than an app release, with a neutral `"Adjustment"` fallback instead of an invented cause. We will render `display_title` / `display_reason` verbatim and never synthesise from `entry_type`.

**You held the line on VAT and "deducted from your next payout."** Neither appears in the copy. That was the right call — it is the one part of this app with real legal exposure, and it stays out until the business signs wording off.

We also noted `SendRideOffer` sends a **high-priority** FCM message carrying `OfferID` and `ExpiresInSec` in the data payload. That is precisely what we need (see A12) — thank you for building it that way.

**Accepted without argument:** A1 (bind to `payout_splits`, 3-line breakdown — the surge-as-multiplier reasoning is sound), A7, A9 (Tips omitted), A10 (multi-stop Phase 2), A8.

---

## 1. This round at a glance

| # | Ask | Type | Severity |
|---|---|---|---|
| **A11** | `GET /drivers/me/penalties` — list, not just a count | New endpoint | 🟠 Medium |
| **A12** | Confirm a 5s poll of `/drivers/me/offers` is acceptable load | Confirmation | 🟠 Medium |
| **A13** | Two penalty sources disagree (`deduction_applications` vs `ledger_entries`) | 🔴 Data bug | 🔴 High |
| **A14** | Publish the error-code list (carried over from Ask-1 §9.4) | Documentation | 🟡 Low |
| **A15** | Driver never gets a live ETA — the rider does | Thin payload | 🔴 High |
| **A16** | `route` is a straight line, not a road route | Thin payload | 🟠 Medium |
| **A17** | Chat has no unread count | Thin payload | 🟠 Medium |
| **A18** | `/drivers/me/trips` has no pagination cursor | Thin payload | 🟡 Low |
| **A19** | Cancelled trips missing from driver history | Thin payload | 🟡 Low |
| **A21** | Rejected document never says why (schema gap) | Thin payload | 🔴 High |
| **A22** | Cancel reasons are raw slugs (`driver_declined`) | Inconsistency | 🟠 Medium |
| **A23** | `penalty_fee_amount` is a float, not pence | Inconsistency | 🟡 Low |
| — | Deploy timing for the Ask-1 work | Logistics | — |

---

## 2. 🔴 A13 — the two penalty sources disagree

**Raising this first because it looks like a real bug, not a design question.**

Live production, right now:

```sql
select count(*), sum(amount) from deduction_applications
 where category = 'penalty';
-- 12 rows, £59.00

select count(*), sum(abs(amount)) from ledger_entries
 where account_type = 'driver' and entry_type = 'penalty';
--  6 rows, £31.00
```

**Twice as many penalties in one table as the other, and £28 unaccounted for.**

`driver_stats_repo.go` computes `penalties_active` from `deduction_applications` (excluding any overturned via `issue_appeals`). The ledger — which is now the authority for the driver's balance, per your A2 fix — carries a different set.

So a driver could see **"2 penalties"** on the Stats screen while their Statement lists **one**, and their balance reflects only that one. Two screens in the same app disagreeing about whether someone was fined is exactly the class of thing that erodes trust in the whole product.

### What we need
1. **Which is authoritative for penalties?** Our assumption after A2 is the ledger — but Stats currently reads the other table.
2. **Is the £28 gap** legacy/test data (we did see `rule_name` values of `test` and `tse5`), or are penalties genuinely being written to one table and not the other?
3. If it is drift, should `penalties_active` be re-pointed at `ledger_entries`?

We are **not** asking for a backfill of test data. We are asking which source the app should trust, and whether the write path is sound going forward.

---

## 3. 🟠 A11 — `GET /drivers/me/penalties`

You confirmed there is no penalty-appeal endpoint and that "Dispute" routes to a support ticket. Understood and accepted.

The remaining gap is **visibility**. `GET /drivers/me/stats` returns `penalties_active` as a bare integer. A driver sees *"1 penalty currently affecting your account"* with no way to learn **which** penalty, **what it cost**, or **when**.

We considered deriving this client-side by filtering the ledger for `entry_type = "penalty"` — no backend work needed. We are **not** doing that, for two reasons:
- Per A13, the two sources currently disagree, so a client-side derivation could contradict the count on the same screen.
- The count excludes appeals upheld via `issue_appeals`; the ledger has no equivalent filter. Reimplementing that exclusion in Dart would duplicate business logic that belongs on the server.

### Proposed contract
```
GET /api/v1/drivers/me/penalties?period=week|month|all&tz=Europe/London
```
```jsonc
{
  "penalties": [{
    "id": "uuid",
    "created_at": "2026-08-26T09:12:00Z",
    "amount_pence": 300,                       // positive magnitude; it's a charge
    "display_title": "Late arrival penalty",   // reuse ledgerDisplay/penaltyDisplay
    "display_reason": "A penalty for arriving late to a pickup.",
    "ride_id": "uuid|null",
    "status": "active" | "appealed" | "overturned",
    "ledger_entry_id": "uuid|null"             // so Dispute can cite it
  }],
  "active_count": 2,      // must equal stats.penalties_active
  "currency": "GBP"
}
```

Notes:
- **Please reuse `penaltyDisplay()`.** It already produces the right copy; no new wording needed.
- `active_count` should be computed the **same way** as `stats.penalties_active`, so the two screens can never disagree.
- `ledger_entry_id` lets the Dispute button cite the exact charge in the support ticket, per your A3 guidance.
- `status: "overturned"` matters — a driver who successfully appealed should see that outcome, not silence.

**Not a Phase-1 blocker.** Until it lands, Stats shows the count as a plain non-tappable stat with no penalty list. That is honest but unhelpful, so we would like it reasonably soon.

---

## 4. 🟠 A12 — confirm offer polling load

**This is a confirmation, not a request to build anything.**

Verified from live data: the offer acceptance window is **60 seconds** (55 offers sampled: 47–60s). Since there is no WebSocket/SSE for the driver app, an offer that arrives late is a lost job — and 3 of those 55 timed out.

### What we intend to do
- **FCM push is the primary path.** `SendRideOffer` already sends high-priority with `OfferID` and `ExpiresInSec` in the data payload; the app wakes, fetches `/drivers/me/offers` immediately, and starts the countdown.
- **A 5-second poll runs as a safety net**, only while the driver is **online and not on a trip**. Android OEM battery managers drop high-priority pushes often enough that push-only would silently cost drivers work.
- Polling **stops entirely** when offline, on a trip, or backgrounded beyond the OS grace period.

### What we need from you
1. **Is a 5s poll acceptable?** With N drivers online that is roughly **N/5 requests per second** — 100 online drivers ≈ 20 rps on that one endpoint. If that is too hot, tell us the number you want and we will use it (10s and 15s are both fine).
2. **Should we poll `/drivers/me/status` too**, or is it cheap enough to fold into the same 5s tick? It backs the "your location is stale" warning, which is time-sensitive for the same reason.

**Rate limiting is understood to be out of scope for v1** — we are not asking for it, and we will not build 429 back-off handling now. We will wire it when the rate-limit doc lands. This ask is only about agreeing a sensible default interval so we do not pick one blindly.

---

## 5. 🟡 A14 — the error-code list (carried from Ask-1 §9.4)

Still outstanding, and it turns out to be bigger than we assumed. We map server codes to user-facing copy; an unlisted code degrades to a generic error message, which is a worse experience than a specific one.

Grepping `ride_handler.go` on `origin/main` turns up **28 distinct codes**:

`ACCOUNT_BANNED` · `ACCOUNT_NOT_ELIGIBLE` · `ACCOUNT_SUSPENDED` · `ACTIVE_TRIP_EXISTS` · `DELETION_BLOCKED` · `DEVICE_BLACKLISTED` · `FORBIDDEN` · `IDEMPOTENT_REPLAY` · `ILLEGAL_TRANSITION` · `INTERNAL` · `NO_PAYMENT_METHOD` · `NO_TARIFF` · `NO_ZONE` · `NOT_FOUND` · `OFFER_EXPIRED` · `OFFER_NOT_FOUND` · `OUTSIDE_SERVICE_AREA` · `PAYOUT_NOT_READY` · `RIDE_NOT_FOUND` · `SCHEDULED_RIDE_NOT_CANCELLABLE` · `SCHEDULED_RIDE_NOT_FOUND` · `SHARE_LINK_INVALID` · `VALIDATION_FAILED` · `VEHICLE_CATEGORY_MISMATCH`

…plus `NO_SHOW_TOO_EARLY`, `STORAGE_DISABLED`, `PHONE_TAKEN` and `USER_NOT_FOUND` from other files. Several are clearly rider-only (`NO_PAYMENT_METHOD`, `VEHICLE_CATEGORY_MISMATCH`).

**What would help most: which of these can a driver actually hit?** We do not want to write copy for 28 codes when perhaps 12 are reachable from the driver app. A short table — code → driver-facing meaning → retryable? — for the driver-reachable subset is all we need.

Specifically for `POST /drivers/me/online`: are `PAYOUT_NOT_READY` and `DEVICE_BLACKLISTED` the only refusals, or can it also fail for expired documents or suspension? Your A6 `blocked_reason` enum lists `suspended | document_expired | payout_not_ready`, which suggests three — we want the online-toggle error path to match.

---

## 5b. Thin payloads found while binding screens

These came out of walking each Phase-1 screen against the endpoint that feeds it. None is a blocker; all are places where the app can render *something* but less than the screen needs. Ordered by impact.

### 🔴 A15 — the driver never gets a live ETA (the rider does)

`RideRiderContextView.pickup_eta_seconds` and `DriverTodayView.pickup_eta_seconds` are **both hardcoded `null`**, commented *"Null until the live-map decision lands."*

Meanwhile `GET /rides/:id/driver-info` — the **rider-facing** endpoint — calls OSRM live and computes a real ETA to the next waypoint, switching target from pickup to dropoff once the ride starts.

So today: **the rider sees "arriving in 6 min"; the driver navigating to them sees nothing.** The same OSRM call, from the same driver position, would serve both.

**Ask:** populate `pickup_eta_seconds` for the driver using the logic already in `GetRideDriverInfo`. The `Heading to Pickup` and `Waiting for Passengers` screens both have an ETA slot in the design.

### 🟠 A16 — `route` is a straight line, not a road route

`RideGeoView.route` is documented honestly: *"NO road-following polyline is persisted anywhere in the platform."* Dispatch calls OSRM with `overview=false` and keeps only distance/duration; `rides` and `fare_estimates` store Points, no LineString.

Every trip frame in the design shows a **road-following route**. A straight line between two pins across Wolverhampton will look broken to a driver, not minimal.

**Ask — one of:**
- **(a)** persist the OSRM geometry at dispatch (`overview=full`, store the encoded polyline on `rides`), **or**
- **(b)** confirm we should draw no route line at all and rely on handoff to Apple/Google Maps for navigation.

We can ship (b) for Phase 1, but we need it confirmed rather than assumed — the current straight line reads as a bug to anyone using it.

`approach` is documented as always null (the driver's position at assignment isn't recorded). We've accepted that and won't draw an approach leg.

### 🟠 A17 — chat has no read state or delivery status

`RideMessage` is `{id, ride_id, sender_id, sender_role, body, created_at}`.

No read receipts, no delivery status, no unread count. The `Conversation` frame is a normal chat UI, and on a polled transport a driver can't tell whether a rider has seen "I'm outside" — which is precisely when it matters.

**Ask (Phase 1, small):** an **unread count** for the active ride, so the trip screen can badge the chat button. Without it the driver must open the thread to discover there's a message.

**Ask (later, optional):** `read_at` per message.

### 🟡 A18 — `GET /drivers/me/trips` has no pagination cursor

Takes `limit` (default 50, max 200) and a `from`/`to` window, but returns a bare array with no cursor — unlike `/ledger`, which does it properly.

A working driver passes 200 trips within a few months, at which point the Trips tab silently truncates with no way to page further.

**Ask:** add the same `cursor` / `next_cursor` pattern used in `/ledger`.

**Also thin:** `DriverTripSummary` is `{id, completed_at, status, pickup_label, dropoff_label, distance_miles, driver_earnings_pence}`. The Trips list would benefit from **trip duration** and the **rating the driver received** — both already in the database (`pickup_time`/`dropoff_time`, `reviews.rating_score`). Low priority.

### 🟡 A19 — no cancelled trips in the driver's history

`GetDriverTrips` filters to **completed** rides only. Live, there are **24 cancelled rides against 36 completed** — a third of all activity is invisible to the driver.

That matters because cancellations drive the cancellation-rate stat *and* can carry a penalty. A driver disputing a penalty (per A3/A11) has no record of the trip it came from.

**Ask:** include cancelled rides, with the cancellation reason and who cancelled, or add a `?status=` filter so the app can request them explicitly.

### 🔴 A21 — a rejected document never tells the driver why

`DriverDocumentRow` is `{id, document_type, verification_status, uploaded_at, expires_at}`.

When `verification_status = "rejected"`, there is **no reason field** — and checking the live schema, `driver_documents` has no rejection-reason column at all (`id, driver_id, document_type, bucket_file_url, verification_status, uploaded_at, expires_at, name, description`). So this is a **schema gap, not just a payload gap**.

A driver whose insurance certificate is rejected sees a red badge and nothing else. They cannot know whether the photo was blurry, the document expired, or the wrong page was uploaded — so they re-upload the same file and get rejected again.

This also undercuts A7/the appeals flow: `compliance_appeals` asks the driver for a `reason`, but they are appealing a decision whose grounds were never given to them.

**Ask:** add a rejection reason (`review_note` or similar) to `driver_documents`, set when an admin rejects, and return it on `GET /drivers/me/documents`. Server-owned copy, same principle as `display_reason` in A3.

**Impact if not fixed:** documents is one of the few screens that can block a driver from earning at all, and the loop is currently unresolvable without a support ticket.

### 🟠 A22 — `cancellation_reasons.reason_text` is a raw slug

Live values for `actor_type = 'driver'`:

| `reason_text` | Driver-facing? |
|---|---|
| `driver_declined` | ❌ slug |
| `offer_timeout` | ❌ slug |
| `Rider did not show up` | ✅ prose |

Two of the three active driver reasons are **snake_case identifiers**. `GET /cancellation-reasons?actor=driver` feeds the cancel reason-picker (§6.1 of the design spec) — so a driver would be choosing between "driver_declined" and "offer_timeout".

We will not prettify slugs client-side: capitalising and de-underscoring is guesswork that breaks the moment a reason is added, and it is the same class of mistake as synthesising ledger copy from `entry_type`.

**Ask:** add a `display_text` column (server-owned, same pattern as A3's `display_title`), or correct the `reason_text` values to prose. Also worth confirming whether `driver_declined` and `offer_timeout` should be **hidden from the picker entirely** — they look like system-generated outcomes rather than reasons a driver would ever pick.

### 🟡 A23 — `penalty_fee_amount` is a float, not pence

`CancellationReason.PenaltyFeeAmount` is `*float64` (£59.00 live). Your own Ask-1 convention — and the new `/ledger` work — is integer `*_pence`.

This is the amount shown in the cancel-confirmation dialog immediately before a driver accepts a charge, so it is exactly where float drift is least acceptable.

**Ask:** expose `penalty_fee_pence` (int64) alongside or instead. Same for `ride_categories.waiting_per_minute` and `deduction_rules.amount` if they are ever surfaced to the app.

### ⚪ A20 — stale comment, no action

`RideRiderContextView.PickupLabel` carries the comment *"Null: no address-text column exists"*, but the query does read `rides.pickup_label` and the field is populated. The comment is stale — flagging only so it doesn't mislead the next reader. **No change needed.**

---

## 6. Deploy timing

Your note says the work is merged and takes effect **once the ride-service is redeployed**. We confirmed the commits are on `origin/main` (`b457303`, `9780018`) but the running `:8080` is still on the previous build, so `/ledger`, `/status` and the widened offer fields 404 today.

We are building **against the live service** rather than mocks, so this is our gating dependency.

**When is the redeploy?** If there is a staging environment already running the new build, we would happily point at that in the meantime — just send the base URL and whether our Supabase JWTs work against it.

---

## 7. One observation, no action needed

We noticed commit `c75ab3f` adds an **SSE driver-location stream**, which on the face of it sits oddly with "no WebSocket/SSE for the driver app."

We read it: it streams a **driver's location to the rider**, replacing the rider's 1 Hz poll. It is rider-facing, so your guidance to us is correct and unchanged — the driver app stays on FCM push + polling.

Flagging it only so nobody later reads that commit and concludes the driver app should have been using SSE all along. **No action required.**

---

## 8. What we need back

| Priority | Item | Why |
|---|---|---|
| 1 | **A13** — which penalty source is authoritative | Two screens will contradict each other about a driver's fines |
| 2 | **Deploy timing** (§6) | Gates all app development |
| 3 | **A12** — confirm the poll interval | Needed before we finalise the data layer |
| 4 | **A14** — error-code list | Blocks honest error copy |
| 5 | **A21** — rejected-document reason | Blocks a driver from earning, with no way to self-resolve |
| 6 | **A15** — driver live ETA | Rider sees an ETA the driver doesn't; same OSRM call |
| 7 | **A16** — road route or no route | Straight line reads as a bug; we need the ruling either way |
| 8 | **A11** — `/drivers/me/penalties` | Not blocking; ship when convenient |
| 9 | **A17–A19, A22, A23** — chat unread, trips paging, cancelled trips | Polish; ship when convenient |

A13 and A12 are both quick calls if that is easier than writing — happy to jump on one.

---

## 9. Running ask register

| # | Ask | Round | Status |
|---|---|---|---|
| A1 | `ride_earnings` per-trip breakdown | Ask-1 | ⏳ **Deferred** — bind to `payout_splits`, 3 lines, pending decomposition sign-off |
| A2 | Wallet reads real balance | Ask-1 | ✅ **Done** |
| A3 | `GET /drivers/me/ledger` | Ask-1 | ✅ **Done** |
| A4 | Widen `PendingOffer` | Ask-1 | ✅ **Done** |
| A5 | `document_type` 8 values + flags | Ask-1 | ✅ **Done** |
| A6 | `GET /drivers/me/status` | Ask-1 | ✅ **Done** |
| A7 | Penalty appeals | Ask-1 | ✅ **Closed** — no endpoint; Dispute → support ticket |
| A8 | Migration 113 | Ask-1 | ⏳ Pending next DB deploy |
| A9 | Tips | Ask-1 | ✅ **Closed** — not live; row omitted |
| A10 | Multi-stop read path | Ask-1 | ⏸ **Phase 2** — `geo.waypoints` ready when needed |
| **A11** | `GET /drivers/me/penalties` | **Ask-2** | 🆕 Open |
| **A12** | Confirm 5s poll load | **Ask-2** | 🆕 Open |
| **A13** | Penalty source disagreement | **Ask-2** | 🆕 Open — 🔴 data bug |
| **A14** | Error-code list | **Ask-2** | 🆕 Open (carried from Ask-1 §9.4) |
| **A15** | Driver never gets a live ETA (rider does) | **Ask-2** | 🆕 Open |
| **A16** | `route` is a straight line, not a road route | **Ask-2** | 🆕 Open |
| **A17** | Chat has no unread count / read state | **Ask-2** | 🆕 Open |
| **A18** | `/drivers/me/trips` has no pagination cursor | **Ask-2** | 🆕 Open |
| **A19** | Cancelled trips missing from driver history | **Ask-2** | 🆕 Open |
| **A20** | Stale comment on `PickupLabel` | **Ask-2** | ℹ️ No action |
| **A21** | Rejected document has no reason (schema gap) | **Ask-2** | 🆕 Open |
| **A22** | `cancellation_reasons.reason_text` is a raw slug | **Ask-2** | 🆕 Open |
| **A23** | `penalty_fee_amount` is a float, not pence | **Ask-2** | 🆕 Open |
