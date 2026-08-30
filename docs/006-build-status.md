# Driver App — Build Status

**Last updated:** 2026-08-30
**App:** `New-driver-app/app` (Flutter) · **API:** `https://api.hoppin.tech`
**Spec:** `docs/superpowers/specs/2026-08-30-driver-app-phase1-design.md`

---

## Where we are

| Batch | Scope | Status |
|---|---|---|
| **1** | Foundation — API client, error map, `Pence`, theme, nav shell | ✅ **Done** |
| **2** | Auth — sign in, forgot, reset, expired link, session | ✅ **Done** |
| **3** | Home — online toggle, blocker list, offer card, polling | ✅ **Done** |
| 4 | Trip lifecycle — heading → waiting → in-trip → finish, chat, cancel | ⬜ Planned |
| 5 | Money — earnings, statement, trips, payouts | ⬜ Planned |
| 6 | Compliance — documents, stats, penalties, appeals | ⬜ Planned |
| 7 | Account — profile, settings, notifications, support, delete, payment | ⬜ Planned |

**121 tests passing · analyzer clean · web build succeeds.**

Plans for batches 1–3 are written in `docs/superpowers/plans/`. Batches 4–7 are scoped in the spec but not yet planned in detail.

---

## What a driver can do today

1. Sign in with operator-issued credentials; the session survives a restart and expiry returns them to sign-in.
2. Reset a forgotten password, including an honest expired-link state.
3. See why they cannot go online — one row per blocking document, deep-linking to the document at fault.
4. Go online and offline.
5. Receive an offer and accept or decline it against a live countdown.

Everything else renders a placeholder behind the four-tab shell.

---

## Deliberate gaps

**Firebase is not wired.** `PushPayload` and the wake-then-fetch path are built and tested, but `FcmService` needs `google-services.json` and `GoogleService-Info.plist`. Adding `firebase_messaging` without them breaks the build, so the seam is ready and the wiring is one file once the Firebase project credentials exist. Until then the 5-second poll is the only offer path — functional, but it costs battery and misses the sub-second delivery push would give.

**The Android notification channel is not yet created.** Batch 1 Task 9 specifies `MainActivity.kt` creating a channel with id exactly `ride_alerts`; it lands with the Firebase work, since the channel is meaningless without it.

**No trip screen.** Accepting an offer routes to `/trip/:rideId`, which has no route registered yet — Batch 4.

---

## Configuration required to run

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://buoreyyxpzvwnxvzpfea.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<the anon key>
```

Neither value is committed. The app will build without them but every call will fail.

Batch 4 additionally needs a **Google Maps API key** per platform, restricted by bundle id / SHA-1 and to the Maps SDK.

---

## Open backend dependencies

None block the batches built so far.

| Item | Blocks | Status |
|---|---|---|
| A12 — confirm the 5s poll interval | Nothing; assumption documented | Open across three rounds |
| Driver-scoped payment endpoints + charge-against-balance | Settle action (Batch 7, ships disabled) | To be raised |
| Self-signup registration endpoints | Signup wizard (Batch 7) | Backend in progress |
| Balance settlement mechanics for the weekly cycle | Nothing in Phase 1 | Product decision pending |

A13 (penalty source) and A11 (`/drivers/me/penalties`) were **closed** on 2026-08-30: the ledger is authoritative and `stats.penalties_count` was re-pointed to match.

---

## Decisions that shaped the code

- **Money is never a `double`.** A `Pence` integer type; `/drivers/me/wallet` returns float pounds and is converted at the repository boundary, nowhere else.
- **The offer card shows no rider identity before acceptance** — Equality Act 2010. Enforced twice: the model has no field for it, and a widget test asserts no avatar or rating renders.
- **A refusal to go online is a state, not an error.** `NOT_ELIGIBLE` is folded into `DriverStatus` so one list renders whether the block was learned by polling or by being refused.
- **Push wakes; the endpoint is the truth.** `PushPayload` deliberately exposes no fare, so a stale push cannot contradict `GET /drivers/me/offers`.
- **Server-owned copy renders verbatim** — `display_title`, `display_reason`, `rejection_reason`, `review_note`. Never synthesised.
- **Errors map on `code`, never on the server's message string**, which is log material.
