# Backend Ask 4 — two data issues found in live screen testing (2026-08-31)

Both found driving the built app against production with a real driver
account. Neither blocks the app — it renders what it is sent honestly —
but both make a screen tell the driver something untrue.

## 1. `GET /drivers/me/today` — `online_seconds` counts the whole of an open session, not today's share

Observed: the home screen's "Today's Summary" showed **Online Time
106h 13m** for a driver whose day had barely started.

Cause (`ride_context_repo.go`, the today query):

```sql
SELECT COALESCE(FLOOR(SUM(EXTRACT(EPOCH FROM (COALESCE(offline_at, NOW()) - online_at)))), 0)::bigint
FROM driver_online_sessions
WHERE driver_id = ?
  AND (COALESCE(offline_at, NOW()) AT TIME ZONE 'Europe/London')::date = <today>
```

A session with `offline_at IS NULL` is clamped to `NOW()`, so it always
*ends* today and is always selected — but `online_at` is not clamped, so a
session opened four days ago and never closed contributes four whole days
to "today". The test driver has exactly such a session.

Suggested fix: clamp the start to the day boundary as well —
`GREATEST(online_at, <today's start>)` inside the subtraction — so only
the portion that actually falls today is summed. (A session left open for
days may also be worth closing server-side, but the query should be
correct regardless.)

## 2. `GET /drivers/me/stats` — `cancellation_rate` is null while `trips_cancelled` is 2 (period: month)

Observed: the Stats screen shows "—" for Cancellation Rate with the
subtitle "2 you cancelled" directly beneath it.

`rate()` returns nil when the denominator (`accepted_trips`) is 0 for the
period, while `trips_cancelled` still counts driver-fault cancellations in
the same window. So the driver reads "no rate, but 2 cancels" — which
looks broken even though each number is individually defensible.

Question rather than a fix: for a month with cancels but no accepted
trips, what should the rate be? Options: (a) leave null and we hide the
count when the rate is null, (b) count the cancelled trips in the
denominator too, (c) something else you prefer. We will follow whichever
you rule.

— Driver app
