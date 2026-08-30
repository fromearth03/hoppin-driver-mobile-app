# Backend Ask-3 — Driver Mobile App

**To:** Backend team, Hoppin
**From:** Driver app build
**Date:** 2026-08-30
**Service:** `Go_ride_service` — live at `https://api.hoppin.tech`

**Previous rounds:** Ask-1 `002-backend-asks-driver-app.md` (A1–A10) · Ask-2 `004-backend-ask-2-driver-app.md` (A11–A23)
**Your replies:** `BACKEND-FOR-DRIVER-APP-2026-08-27.md` · `BACKEND-FOR-DRIVER-APP-2026-08-30 v2.md` · `BACKEND-DRIVER-ERROR-CODES-2026-08-30.md`

> **Numbering:** asks roll up across rounds and never restart. This round raises **no new numbers** — it chases three items already on the register (A11, A12, A13) plus one observation.

---

## 0. First — this round was excellent

We verified your work the same way as last time: pulled `Go_ride_service`, grepped the merged handlers, and probed the live service. **Everything you claimed is real and deployed.** Eleven items closed in one round.

Verified in source rather than taken on trust:

| Ask | Claim | Where we confirmed it |
|---|---|---|
| A1 | `ride_earnings` written at settlement | `INSERT INTO ride_earnings` — `internal/repository/payment_repo.go:52` |
| A14 | Driver-reachable error codes (~22, not 28) | `NOT_ELIGIBLE` envelope — `driver_handler.go:88-105` |
| A15 | Live OSRM driver ETA | commit `0e42e82` |
| A16 | Real road-following polyline | `rider_ride_detail.go:148-158` |
| A17 | `chat_unread` | `rider_ride_detail.go:78`, cleared in `chat_handler.go:92` |
| A18 | Cursor paging on trips | `driver_handler.go:271-277` |
| A19 | Cancelled trips + `penalty_pence` | `driver_handler.go:221-226` |
| A21 | `rejection_reason` end-to-end | `driver_document_repo.go:48` + migration 115 |
| A22 | `pickable` hides system slugs | `lookups_repo.go:38` |
| A23 | `penalty_fee_pence` | `lookups_repo.go:22` |

Two things worth calling out specifically:

**The eligibility realignment is better than what we asked for.** We asked for an error-code list. You noticed that `GET /status`'s `blocked_reason` and the `POST /online` refusal used *different* vocabularies, and unified them — 11 shared tokens plus `blocking_document_types`. That means one blocked-from-online screen, keyed off one set, whether the app learns the state by polling or by being refused. We hadn't spotted the divergence; you fixed it before it became our bug.

**You reversed two of your own earlier rulings when the reasoning changed** — A1 (was "defer, bind to `payout_splits`") and A16 (was "no road polyline is persisted anywhere"). Both reversals were right, and A1 shipping *with* a `payout_splits` fallback for historical rides is the detail that matters: no driver sees a screen of £0.00 lines for a trip they actually did.

---

## 1. 🔴 A13 — still unanswered, and it is the one that blocks us

**This was our #1 priority ask in Ask-2 and it appears in neither reply.** We think it was missed rather than declined, since everything else got answered.

Live, right now:

```sql
select count(*), sum(amount) from deduction_applications
 where category = 'penalty';
-- 12 rows, £59.00

select count(*), sum(abs(amount)) from ledger_entries
 where account_type = 'driver' and entry_type = 'penalty';
--  6 rows, £31.00
```

`driver_stats_repo.go` computes `penalties_active` from `deduction_applications` (excluding any overturned via `issue_appeals`). The ledger — now authoritative for the driver's balance per your own A2 fix — carries a different set.

**So a driver can see "2 penalties" on Stats and one on their Statement, with their balance reflecting only the one.** Two screens in the same app disagreeing about whether someone was fined is exactly the class of thing that erodes trust in the whole product.

### What we need
1. **Which source is authoritative for penalties?** Our assumption after A2 is the ledger — but Stats reads the other table.
2. **Is the £28 gap legacy/test data?** We did see `rule_name` values of `test` and `tse5`.
3. **If it is drift, should `penalties_active` be re-pointed at `ledger_entries`?**

We are **not** asking for a backfill of test data. We are asking which source the app should trust, and whether the write path is sound going forward.

**This blocks the Stats screen.** We would rather wait than wire it to the wrong table.

---

## 2. 🟠 A11 — `GET /drivers/me/penalties`, confirmed absent

We probed the deployed service. Unregistered routes 404 before the auth check, registered ones 401, so the two are distinguishable without credentials:

```
/api/v1/definitely-not-a-real-route    404   (unknown route)
/api/v1/drivers/me/ledger              401   (exists — A3)
/api/v1/rides/:id/earnings             401   (exists — A1)
/api/v1/drivers/me/penalties           404   (never built)
```

So A11 was not built — this is not an omission in the write-up.

That is fine if it was deprioritised; we did mark it non-blocking. We flag it only because the v2 doc says "nothing left flagged", and we would rather correct the register than let an item quietly disappear.

**Same underlying question as A13:** until one source is authoritative, a penalty *list* cannot agree with the penalty *count* on the same screen. Answering A13 may well be the whole answer here.

Proposed contract unchanged from Ask-2 §3. Until it lands, Stats shows a bare, non-tappable count — honest but unhelpful.

---

## 3. 🟡 A12 — poll interval, still unconfirmed

Asked in Ask-2, not answered. **We are proceeding on an assumption and would like it corrected if it is wrong:**

- **FCM push is the primary path.** `SendRideOffer` already sends high-priority with `OfferID` and `ExpiresInSec` in the data payload; the app wakes, fetches `/drivers/me/offers`, and starts the countdown.
- **A 5-second poll runs as the safety net**, only while the driver is online and not on a trip. It stops entirely when offline, on a trip, or backgrounded beyond the OS grace period.
- **`/drivers/me/status` is folded into the same tick** rather than running a second timer.

At 100 drivers online that is roughly **20 rps** on the offers endpoint.

If that is too hot, name a number — 10s and 15s are both fine and we will use whatever you say. Rate limiting stays out of scope for v1 as agreed; this is only about agreeing a sensible default rather than picking one blindly.

---

## 4. What we need back

| Priority | Item | Blocks |
|---|---|---|
| 1 | **A13** — which penalty source is authoritative | Stats screen wiring |
| 2 | **A12** — confirm or correct the 5s poll | Data layer (proceeding on assumption) |
| 3 | **A11** — confirm deprioritised or queued | Stats penalty list (degraded, not blocked) |

**A13 is a 2-minute call if that is easier than writing.**

Everything else is unblocked and we are building.

---

## 5. Running ask register

| # | Ask | Round | Status |
|---|---|---|---|
| A1 | `ride_earnings` per-trip breakdown | Ask-1 | ✅ **Done** — 9-line breakdown at settlement, `payout_splits` fallback for historical rides |
| A2 | Wallet reads real balance | Ask-1 | ✅ **Done** |
| A3 | `GET /drivers/me/ledger` | Ask-1 | ✅ **Done** |
| A4 | Widen `PendingOffer` | Ask-1 | ✅ **Done** |
| A5 | `document_type` 8 values + flags | Ask-1 | ✅ **Done** |
| A6 | `GET /drivers/me/status` | Ask-1 | ✅ **Done** — vocabulary later unified with the online refusal |
| A7 | Penalty appeals | Ask-1 | ✅ **Closed** — no endpoint; Dispute → support ticket |
| A8 | Migration 113 | Ask-1 | ✅ **Applied** |
| A9 | Tipping | Ask-1 | ✅ **Closed** — not live; row omitted |
| A10 | Multi-stop read path | Ask-1 | ⏸ **Closed for Phase 1** — app is single-stop by product decision (2026-08-29) |
| A11 | `GET /drivers/me/penalties` | Ask-2 | 🔴 **Open** — confirmed 404 on live; not built |
| A12 | Confirm 5s poll load | Ask-2 | 🟡 **Open** — proceeding on assumption |
| A13 | Penalty source disagreement | Ask-2 | 🔴 **Open — unanswered, blocks Stats** |
| A14 | Error-code list | Ask-2 | ✅ **Done** — separate reference doc |
| A15 | Driver live ETA | Ask-2 | ✅ **Done** |
| A16 | Road route vs straight line | Ask-2 | ✅ **Done** — real OSRM polyline |
| A17 | Chat unread count | Ask-2 | ✅ **Done** |
| A18 | Trips pagination cursor | Ask-2 | ✅ **Done** |
| A19 | Cancelled trips in history | Ask-2 | ✅ **Done** — with `penalty_pence` |
| A20 | Stale `PickupLabel` comment | Ask-2 | ℹ️ No action |
| A21 | Rejected-document reason | Ask-2 | ✅ **Done** — end-to-end, admin writes it |
| A22 | Cancel reasons are raw slugs | Ask-2 | ✅ **Done** — `pickable` flag |
| A23 | `penalty_fee_amount` float | Ask-2 | ✅ **Done** — `penalty_fee_pence` |

**Open: 3 of 23.** Two of those three are the same question.
