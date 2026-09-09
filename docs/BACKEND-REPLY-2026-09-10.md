# Driver app — reply to the 10 September handoff

Answering `DRIVER_APP_BACKEND_HANDOFF.md`. Every claim below was checked
against the code in this repo today, with file and line references you can
open yourself.

**Please re-run your audit against a fresh checkout before we act on it.**
Five of the ten numbered items describe work that shipped weeks ago, including
both items you ranked highest. Two more are substantially built. The line
numbers and grep results quoted in the doc do not match this repository —
`home_controller.dart:190` is error handling here, not a poll timer, and
`driver_status_repository.dart:45` is not the definition you quote.

We are not disputing this to score a point. Three of your items are real and we
want to build them. But we cannot tell which of the remaining seven are stale
observations and which are genuine regressions on our side, and guessing wrong
means either rebuilding working features or leaving a real gap open.

---

## Summary

| # | Your claim | Verdict |
|---|---|---|
| 1 | No push — app polls every 5 s | ❌ **False** — FCM shipped and wired |
| 2 | Location reporting has no caller | ❌ **False** — 5 call sites plus tests |
| 3 | Scheduled rides absent | ✅ **True** — genuinely not built |
| 4 | No SOS / panic button | ❌ **False** — `POST /me/sos` live on the trip screen |
| 5 | Cancellation fees not shown | ⚠️ **Mostly false** — fees are shown; the quote endpoint is not used |
| 6 | Cancellation rate not shown | ❌ **False** — on the stats screen, and *you told us it was queued* |
| 7 | Destination filter unused | ✅ **True** — genuinely not built |
| 8 | No device check-in | ❌ **False** — `POST /me/device` on every session claim |
| 9 | Free-cancel countdown | ✅ **True** dependency — no app change needed |
| 10 | Compression — do not break it | ✅ **True** — no override present |

**Actionable: 3, 7, and a per-ride cancellation quote.** That is the whole list.

---

## 1. Push notifications — shipped

> "There is no `firebase_messaging` dependency, nothing calls
> `POST /me/device-tokens`, and `home_controller.dart:190` runs a 5 s timer."

All three parts are wrong.

- `app/pubspec.yaml:30-31` — `firebase_core: ^4.14.0`, `firebase_messaging: ^16.6.0`.
- `app/lib/core/push/push_service.dart:73` — posts `/me/device-tokens` with
  `{fcm_token, device_os}`, on first registration and on every token refresh.
- `app/lib/features/home/logic/home_controller.dart:157` —
  `push.onRideOffer = () => onPushWake()`. The wake refetches
  `GET /drivers/me/offers` (`:386`) and emits the offer.

A second channel routes penalty, compliance and ride-update pushes to a toast
(`home_controller.dart:161`, `shared/widgets/push_alert_listener.dart`).

**The 5-second poll is real and deliberate.** It is at
`home_controller.dart:90`, not `:190`. It is a backstop beside push, not a
substitute for it — the reasoning is written at `push_service.dart:8-14`: FCM
is the wake-up half, the payload is a trigger only, and the authoritative
offer always comes from the endpoint. A push that arrives stale must never
contradict `/drivers/me/offers`.

**Where we agree:** 5 s is tighter than a backstop needs to be now that push
carries the primary path. We will raise it, but we want your answer to one
question first — see "What we need from you" below.

**One real gap:** push is skipped on web (`push_service.dart:40`, `kIsWeb`), which needs
a VAPID key and a service worker the app does not carry. If the web build
matters for drivers, that is a genuine item; it was not on your list.

---

## 2. Location reporting — shipped

> "`updateLocation()` has no caller. Grepped again today: one reference, its
> own definition."

There are two references, and the second is a live caller.

- Defined at `driver_status_repository.dart:50` (not `:45`).
- Called at `features/home/logic/location_reporter.dart:211`.

`LocationReporter` is 246 lines and does what your spec asks for, including the
parts you flagged:

| Your spec | What is built |
|---|---|
| Start on Go Online | `home_controller.dart:278` |
| Stop on Go Offline | `home_controller.dart:249` |
| Stop on logout | `home_controller.dart:344` |
| Not tied to a screen | Android foreground service, `core/device/shift_service.dart` |
| Swallow failures | Best-effort; the next fix supersedes a dropped one |

Also resumes on a mid-shift relaunch when `/status` says the driver is already
online (`home_controller.dart:180`), and is covered by
`test/features/home/shift_service_wiring_test.dart`.

Beat intervals (`location_reporter.dart:37-57`): **1 s** until the first fix
posts, then **15 s** steady, with a 10 m `distanceFilter` so a parked driver
stops waking the GPS radio. Going online lands a position in about a second.

**This is the claim we would most like explained.** If Live-Ops is showing an
empty map, the cause is not a missing caller — it is somewhere between our
`POST /drivers/me/location` and your map. Can you check whether the writes are
arriving? If they are, the problem is downstream of us and we cannot see it.
If they are not, we need to know what the endpoint is rejecting, because the
app swallows failures by design and would not surface it.

The consequences you list — mispriced mid-trip cancellations, drivers paying
fees the free-distance waiver should have waived — are serious enough that we
would rather chase this together than have either side assume it is fixed.

---

## 3. Scheduled rides — correct, not built

Confirmed. The only mention is the marketing string at
`features/home/ui/widgets/offline_hero.dart:187`, which promises drivers
scheduled bookings they cannot see. No model, no repository, no screen.

We will build it. Before we do, we want the response shapes for all six
endpoints from you directly rather than inferring them — two field-name
mismatches this month each silently broke a whole feature, which is the same
point you make in your closing ask.

Specifically: what does the claim hold expire after, and does the board return
the remaining hold time so a driver can see their claim slipping away?

---

## 4. SOS — shipped

> "`grep -rn "sos\|panic"` over the driver app returns nothing."

It returns 16 lines. The feature is live:

- `features/trip/data/sos_repository.dart:15` — `POST /me/sos` with
  `{lat, lng, ride_id, note}`.
- `features/trip/ui/widgets/emergency_sheet.dart` — the sheet, with a
  sent-confirmation state and error display.
- `features/trip/ui/trip_screen.dart:153` — an `Icons.sos` action on the trip
  screen, tooltip "Emergency".

Emergency contacts are wired too, though from `/contacts` rather than
`/me/emergency-contacts`: the sheet offers the emergency line, support, and
WhatsApp, each shown only when the number is non-blank
(`emergency_sheet.dart:94-124`).

**Worth confirming:** if `/me/emergency-contacts` is the intended source for
next-of-kin — a different thing from the platform's own support numbers — then
we have a real gap, because we store no next-of-kin at all. Your doc conflates
the two. Which did you mean?

---

## 5. Cancellation fees — the picker does not read as free

> "Today every option in the picker reads as free and the server then charges."

This is not what the sheet does. `features/trip/ui/widgets/cancel_sheet.dart`:

- **The charge is named on each row**, before anything is picked —
  `:298` renders `"£X.XX charge may apply"` under any reason carrying a fee.
- **The free-window banner appears only when it is genuinely free** (`:233`),
  and says out loud that it still counts toward the cancellation rate (`:239`)
  — the fee is waived, nothing else is.
- **A separate confirmation step** for any reason carrying a charge (`:366`),
  with distinct copy for "Other reason" so an unpriced reason does not read as
  the free option.
- **A live countdown** anchored to `accepted_at + free_cancel_seconds`
  (`trip_controller.dart:70`).

**Your underlying point is still right, and we accept it.** We show the
admin-configured per-reason `penalty_fee`, and for the free window we take the
*narrowest* `free_cancel_seconds` across all reasons
(`trip_controller.dart:121-145`) because the driver has not picked a reason
yet. The reasoning is at `:127` — under-promising costs them nothing,
over-promising costs them money.

A per-ride server-derived quote is strictly better than that, and your point
about state-derived events being unrepresentable per-reason is well made. We
will wire `GET /rides/:id/cancellation-quote?actor=driver` and show `explain`
verbatim above the picker.

We will honour both of your rules: a failed quote means free and never blocks
cancelling, and `free: false` with no amount is treated as free.

---

## 6. Cancellation rate — shown, and you told us it was queued

> "Drivers are being judged on a number the app never shows them."

The app shows it: `features/stats/ui/stats_screen.dart:136`, a "Cancellation
Rate" tile, parsed from `cancellation_rate` on `GET /drivers/me/stats`
(`driver_stats.dart:102`). It is nullable-parsed, so it displays "—" until you
populate the field and lights up on its own when you do.

**This one needs resolving, because your two documents disagree.**

On 4 September (`BACKEND-REPLY-DRIVER-APP-2026-09-04.md`, section 5) you wrote
that cancellation rate was **queued on your side**, and gave a reason we
thought was the right call:

> "Driver cancellations are currently recorded without the penalty amount being
> written to the cancellation record, and no-show claims are not yet checked
> against ride state — so a raw cancellation count today would include events
> the driver is not fairly accountable for… we would rather fix the recording
> before publishing a number operations penalise against."

You said it would ship together with round-5 item 2, "fair stats".

Today's doc presents `GET /drivers/me/cancellation-rate` as live and the gap as
ours. So:

1. Did the recording fix ship? If not, we should not display the number, for
   exactly the reason you gave.
2. Is the rate on `/drivers/me/stats` populated, or only on the separate
   `/drivers/me/cancellation-rate` endpoint? We read the former.

If the fairness problem is still open, we would rather keep showing "—" than
show drivers a number that penalises them for cancellations that were not
their fault.

---

## 7. Destination filter — correct, not built

Confirmed, zero references. We will build it.

One design question: should a driver with an active filter see that it is on
from the home screen? A filter silently narrowing their offers is a support
ticket waiting to happen — "why did the work dry up".

---

## 8. Device check-in — shipped

> "`POST /me/device` records the device fingerprint… One call at launch closes
> that."

It is called on every session claim, not just at launch:
`features/auth/data/auth_repository.dart:129`, sending
`device_hardware_id`, `operating_system`, `app_version`, `is_emulator`.

The id is a stable 32-hex-char value minted with `Random.secure()` and
persisted (`core/device/device_identity.dart`), and it also rides on **every**
API request as `X-Hoppin-Device-ID` (`core/api/api_client.dart:45`,
origin-guarded so it never follows a URL to another host).

Note your doc treats `/me/device` and `/me/device-tokens` as the same item.
They are different calls with different purposes, and both are implemented.

**If the blacklist still cannot see our devices**, the fingerprints are
arriving and not being read, or being rejected silently — the call is
best-effort so a failed ingest cannot cost a driver their login. Same ask as
item 2: can you check whether the writes land?

---

## 9. Free-cancel countdown — no app change needed

Correct that we depend on `accepted_at` (`ride.dart:217`,
`trip_controller.dart:71`).

**There is no fallback, deliberately.** `trip_controller.dart:65`: both the
timestamp and the window must be known — null means we cannot say, and the UI
shows nothing rather than a guess. It also returns null once the window closes,
so a countdown never sits at 00:00 implying free.

So while `accepted_at` was empty, drivers saw *no countdown* rather than a
wrong one. If your 8 September fix is live, it now appears with no change from
us. We will confirm against the current backend.

Thank you for finding that one — it is exactly the kind of thing we would have
spent a day chasing on our side.

---

## 10. Compression — nothing to break

Confirmed against `core/api/api_client.dart` in full:

- No `Accept-Encoding` header is set anywhere. The only headers we add are
  `Authorization` (`:41`) and `X-Hoppin-Device-ID` (`:45`).
- `autoUncompress` is never touched; the adapter is a bare `Dio()` (`:189`).
- The single interceptor is `onRequest`-only, so no response handler assumes
  text. Binary has its own path — `getBytes()` (`:69`) sets
  `ResponseType.bytes` explicitly.

We will keep it that way, and thank you for writing down the three ways it
breaks. The "unexpected character on a response that works in a browser"
symptom is worth having on record.

---

## Smaller things

| Endpoint | Status |
|---|---|
| `GET /demand-heatmap` | **Data layer built, no UI.** `features/heatmap/` with models and repository, tested. The home screen has no map, so a UI is a new screen plus a nav entry — a real feature, deliberately deferred rather than missed. |
| `GET /ride-rules` | Not used. Agreed this is better than a hardcoded copy that drifts. |
| `GET /me/rating` | Not called — we read `rating` off `/me/profile` and `/drivers/me/stats` instead. No gap unless those go away. |
| `GET /rides/:id/geo` | Not called, deliberately. We read the nested `geo` on `GET /rides/:id`, which carries labels and waypoints. The flat shape on the standalone endpoint is the rider app's concern. |
| `GET /faqs` | Not used — FAQs are a hardcoded list (`support_screen.dart:59`). Ops-editable content is a fair improvement. |
| `GET /cancellation-policy` | Not used. |
| `GET /me/activity` | Not used. |
| `GET /rides/:id/receipt` | Not used. |
| `GET /service-areas/check` | Not used. |
| `GET /drivers/me/avatar-upload-url` | **Please do not.** We use multipart `POST /me/avatar/upload` (`profile_repository.dart:55`). Presign-and-PUT is the pattern that took document upload down for two days when the presign returned `http://minio:9000/…` — an internal Docker hostname a handset cannot reach. You fixed that by shipping a multipart proxy. Reintroducing presign for avatars walks back into the same failure. |

---

## What we need from you

Five questions, in the order they block us:

1. **Re-run the audit against a current checkout** and tell us which of items
   1, 2, 4, 6 and 8 survive. We cannot tell stale observations from real
   regressions, and the difference decides whether we rebuild working code.

2. **Are our location writes arriving?** If Live-Ops is empty while
   `POST /drivers/me/location` fires every 15 s from every online driver, the
   break is downstream of us and invisible from here. Same question for
   `POST /me/device` and the blacklist.

3. **Cancellation rate — which document is current?** If the fairness fix has
   not shipped, we will keep showing "—" for the reason you gave in September.

4. **Emergency contacts — next-of-kin, or platform support numbers?** We have
   the second and none of the first.

5. **Scheduled rides: the six response shapes**, plus how long a claim hold
   lasts and whether the board returns the time remaining on it.

On your closing ask — yes, and we would extend it in both directions. Tell us
when a shape changes, and we will tell you when one does not match. The three
field-name mismatches this month all cost more to find than to fix.
