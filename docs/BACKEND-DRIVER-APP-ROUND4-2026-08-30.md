# Backend — DRIVER app (round 4)

**Date:** 2026-08-30 · **Service:** `Go_ride_service` (`api.hoppin.tech`). All live.
Conventions: integer `*_pence`, snake_case, nullable rates stay `null` (render "—").

---

## New / changed

### `GET /drivers/me/stats` — rich Stats screen (NEW)
```jsonc
{
  "average_rating": 4.8,        // null until at least one review
  "rating_count": 5,
  "trips_completed": 15,
  "trips_cancelled": 3,
  "online_minutes": 742,
  "penalties_count": 6,         // LEDGER-sourced — agrees with /penalties + Statement
  "balance_pence": -5000,       // signed; negative = the driver owes ("You owe")
  "earnings": { "total_pence":11307, "this_week_pence":2400,
                "this_month_pence":8600, "currency":"GBP" },
  "acceptance_rate": 0.94,      // null when no offers
  "completion_rate": 0.83       // null when no finished trips
}
```

### `GET /drivers/me/penalties` — penalty list + count (was 404)
Both the list **and** `count` come from the **ledger** (authoritative), so a Stats
badge and the Statement can't disagree. See the Ask-3 reply for the full A13 answer.
```jsonc
{ "penalties":[{ "id","created_at","amount_pence":1000,
   "display_title":"Complaint penalty","display_reason":"…",
   "ride_id":"uuid"|null,"appealable":true }], "count":6 }
```

### "You owe / We owe" — the ledger IS the owes model
`balance_pence` (in `/wallet`, `/ledger`, `/stats`) is **signed**: negative = the
driver owes the company, positive = the company owes the driver. The `/ledger`
statement itemises every earning, penalty, bonus, payout and adjustment with a
running balance and server-owned copy. No separate endpoint needed — it's one
authoritative source across all three reads.

### Human-readable ref (R-)
`GET /drivers/me/trips` now includes **`ref`** (e.g. `"R-1042"`) per trip. Drivers
(D-N) also get a ref in the DB for admin, exposed in admin views.

### Ride chat — WhatsApp receipts + reply
Same as the rider side: `reply_to_id` on send; per-message `status` (`sent`→`read`)
and a `reply_to` preview on `GET /rides/:id/messages`.

---

## Already live (confirmed)

- **Dropped/unmatched rides — fixed & running.** The dispatch engine re-queues a
  rider that matches no driver onto `RIDE_REQUESTS` for **5 min** (the no-driver
  timeout) before emitting a no-driver-found — no more silent drop on first miss.
  (Deployed; log confirms `unmatched-request retry enabled`.) ✅
- **A1–A23** from earlier rounds — ride_earnings breakdown, ledger wallet, ledger
  statement, offer payload, document types + rejection_reason, status/eligibility
  vocabulary, live ETA, road route, chat_unread, trips cursor + cancelled +
  penalty_pence, cancel-reason `pickable` + `penalty_fee_pence`. ✅

## Support-ticket chat (both apps)
`GET /me/support-tickets/:id` messages now carry the same WhatsApp `status` +
`reply_to` preview, and `POST …/reply` accepts `reply_to_id`. Opening a ticket marks
it read. (Staff read-receipts on the driver's messages need the admin ticket view to
write `support_ticket_reads` — small admin follow-up; the mechanism is in place.)

## Pagination
`/drivers/me/trips`, `/drivers/me/ledger`, `/drivers/me/penalties` (count+list) —
cursor/limit paged. Pass back `next_cursor` until `has_more:false`.
