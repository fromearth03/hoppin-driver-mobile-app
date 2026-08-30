# Hoppin Driver App — Phase 1 Design Spec

**Date:** 2026-08-30 · **Status:** approved for planning
**Platform:** Flutter (iOS · Android · Web) · **State:** Riverpod
**Backend:** `Go_ride_service` at `https://api.hoppin.tech`, routes under `/api/v1`

---

## 1. What this document is

The design authority for the driver app. There is no further Figma round — the designer's pack (`driver view Super MEGA ULTRA FINAL`, 39 frames) is a visual reference that this spec supersedes where the two disagree. Screens invented here (Trips, Statement, the blocked list) have no frame at all, so this document carries enough visual detail to build from.

Every screen below is bound to a verified endpoint. Claims about the backend were checked by reading merged handlers in `Go_ride_service`, not by trusting handover docs.

### Standing rules

1. **The backend is the source of truth.** A screen with no endpoint behind it is not built. A *row* whose field the API does not return is not rendered — it is not filled with a zero, a placeholder, or a guess.
2. **Figma values are placeholders.** £20.15, "Taimoor", 4.3 (13) are mock data to be bound to real fields. Only rows with no backing field at all are dropped.
3. **Server-owned copy is rendered verbatim.** Anything stating a charge or its reason (`display_title`, `display_reason`) is printed as received and never synthesised from `entry_type`.
4. **Money is never a `double`.** A `Pence` value type wrapping `int`, formatted only at render.
5. **Models mirror Go structs exactly.** If `PendingOffer` has no `rider_name`, the Dart class has no `riderName` — the compiler enforces rule 1.

---

## 2. Architecture

### 2.1 Folder structure

Feature-first. A feature's screen, state and data live together, so a change is local rather than spread across four layer folders.

```
lib/
├── main.dart
├── app.dart                        # MaterialApp, router, theme
│
├── core/
│   ├── api/
│   │   ├── api_client.dart         # Dio + auth interceptor + envelope parsing
│   │   ├── api_exception.dart      # {code, error} → typed failure
│   │   └── error_codes.dart        # 22 driver-reachable codes → copy
│   ├── auth/
│   │   ├── auth_repository.dart    # Supabase JWT, refresh, secure storage
│   │   └── auth_state.dart
│   ├── push/
│   │   ├── fcm_service.dart        # token registration, foreground/background
│   │   └── push_payload.dart       # typed ride_offer payload
│   ├── money.dart                  # Pence value type
│   ├── result.dart                 # Result<T> = success | failure
│   └── theme/
│       ├── colors.dart             # tokens (light only, but tokens)
│       ├── typography.dart
│       └── app_theme.dart
│
├── features/
│   ├── auth/          sign in · forgot · reset · expired link
│   ├── signup/        self-signup wizard: personal → docs → vehicle → done
│   ├── home/          online toggle · radar · offers · blocker list
│   ├── trip/          heading → waiting → started → finish · chat
│   ├── earnings/      summary · breakdown · drill-down · payouts (read-only)
│   ├── statement/     ledger · both money directions · dispute
│   ├── trips/         history (invented here)
│   ├── stats/         stats · penalties · appeals
│   ├── documents/     grid · upload · rejection reason · appeals
│   ├── profile/       personal info · settings · delete account
│   ├── payment/       saved cards (Stripe SetupIntent) · settle balance
│   ├── notifications/ list · read · dismiss
│   └── support/       FAQ · tickets
│
└── shared/
    ├── widgets/       buttons, cards, empty/error/loading states
    └── nav/           bottom nav shell, side drawer
```

Every feature holds the same three folders:

```
features/<name>/
├── data/          repository interface + live impl + models
├── logic/         Riverpod controllers/notifiers
└── ui/            screens + widgets
```

### 2.2 Data layer

`ApiClient` wraps Dio. One auth interceptor attaches the Supabase JWT and refreshes on 401. Every error response is the envelope `{"error": "...", "code": "..."}` — mapped on `code`, never on the message string, which is for logs.

Repositories are interfaces; production has exactly one implementation, which talks to the live service. Fixture implementations exist in the test target only and never ship.

### 2.3 Navigation

```
Bottom nav:  Home · Earnings · Docs · Stats
Side nav:    Personal Information · Trips · Notifications ·
             Help & Support · Settings · Logout
```

Docs takes a bottom-nav slot because an expired document stops a driver earning; Trips is a record consulted occasionally. Prominence follows consequence, not frequency.

### 2.4 Theme

**Light mode only.** Colours are defined as tokens (`AppColors.surface`), never inline hex, so a future dark mode is a token file rather than 25 screens. Palette derived from the Figma pack: deep indigo primary (`#2E0B78`-family), orange accent for primary actions, green for online/positive, red for penalties and blocked states.

---

## 3. Cross-cutting behaviour

### 3.1 Offer delivery

**FCM push wakes the app; the endpoint is the truth.**

`push.SendRideOffer` sends a high-priority message carrying a data payload (`ride_id`, `offer_id`, `expiresIn`, pickup lat/lng, `deep_link: "/offer"`). The app wakes, deep-links, and **fetches `GET /drivers/me/offers`** for authoritative detail. The `fare` in the push is best-effort context and is never rendered.

- Android channel id must be exactly **`ride_alerts`** (`IMPORTANCE_HIGH`) — the backend targets it by name; a wrong id loses heads-up delivery when backgrounded, which is when it matters.
- iOS uses `content-available` + `apns-priority: 10`. Web push is configured, so Flutter Web receives offers.
- `POST /me/device-tokens` on login and on token rotation: `{fcm_token, device_os: ios|android|web}`.

**Polling is the safety net.** A 5-second poll of `/drivers/me/offers` runs *only* while online and not on a trip, with `/drivers/me/status` folded into the same tick. It stops entirely when offline, on a trip, or backgrounded beyond the OS grace period. Android OEM battery managers drop high-priority pushes often enough that push-only would silently cost drivers work.

> **Assumption pending confirmation (Ask-3 A12):** 5s is unconfirmed by the backend. At 100 drivers online it is ≈20 rps on one endpoint. If they name a different interval, it changes one constant.

### 3.2 Error handling

The 22 driver-reachable codes map to user-facing copy in `core/api/error_codes.dart`. Anything unlisted falls back to a generic message. Retryable codes (`INTERNAL`, `STORAGE_DISABLED`, `NO_DRIVER_ASSIGNED`, `POSITION_UNAVAILABLE`) retry with backoff; the rest surface their message without auto-retry.

`NO_SHOW_TOO_EARLY` carries a `seconds` field — the UI counts down rather than showing a bare refusal.

### 3.3 Money

`available_balance` and `pending_balance` come from `/drivers/me/wallet` as **`float64`** — the one endpoint that predates the pence convention. Converted to `Pence` at the repository boundary. Everything else (`*_pence`) is already integer.

A negative balance means the driver owes. It is displayed plainly, never euphemised.

### 3.4 Copy and tone

Two registers, deliberately separated:

- **App chrome** (headings, buttons, empty states, blockers) — ours. Warm, plain, action-first. *"Two things to sort before you can go online"*, never *"You are blocked"*.
- **Anything stating a charge or its reason** — the server's words, verbatim. `display_title` / `display_reason` from the ledger.

Friendly-but-vague wording about deductions increases legal exposure rather than reducing it: under UK rules on deductions from a worker's pay, whether the worker clearly understood is close to the whole question. Warm wrapper, exact core.

---

## 4. Screens

### 4.1 Auth — `features/auth`

Four screens, all backed by Supabase auth. **Sign In** (email + password; copy reads "credentials provided by the company"), **Forgot Password**, **Reset Password** (min 8 chars, confirm field), **Expired Link**.

The Figma "Expired-link" frame shows a loading spinner with "We're Almost There" — that reads as a loading state for what is a failure. Rebuilt as an explicit error state with a Try Again action.

`Sign In-1` and `Sign In` differ only in subtitle; the `-1` copy is correct and the other is dropped.

### 4.2 Home — `features/home`

The primary screen. Three states.

**Offline** — radar visualisation, Offline/Online toggle, 4-tab nav.

**Online, no offer** — same, toggle green.

**Online, offer received** — offer card over the map.

#### Offer card

Bound to `GET /drivers/me/offers` → `PendingOffer`:

```
fare_pence · pickup_label · dropoff_label · ride_category
estimated_duration_seconds · pickup_eta_seconds · expires_in_sec
```

**No rider identity is shown before acceptance** — no name, photo, rating or comment. The payload does not carry them, and this is a deliberate compliance position, not a data limitation. See §6.1.

Card renders: fare prominent · pickup distance and ETA · trip distance and duration · category badge · a countdown ring driven by `expires_in_sec` (the offer window is 60s, verified live at 47–60s across 55 offers).

Accept → `POST /offers/:id/accept`. `OFFER_EXPIRED` (409) and `OFFER_NOT_FOUND` (404) resolve back to the waiting state with a brief message.

#### Blocked-from-online list

When `GET /drivers/me/status` returns `blocked_reason != null`, or `POST /drivers/me/online` refuses (403), Home renders a resolution list above the map and disables the toggle. **This is not a separate screen** — a driver who cannot work should not have to navigate to find out why.

```
Two things to sort before you can go online

┌────────────────────────────────┐
│ 🔴 Vehicle Insurance           │
│    Expired 15 Jan · Renew   →  │   → deep-links to that document
└────────────────────────────────┘
┌────────────────────────────────┐
│ 🕐 Medical Certificate         │
│    Under review · no action    │   ← no chevron, not tappable
└────────────────────────────────┘

           Contact support
```

One row per entry in `blocking_document_types` — the field is an array, and a driver blocked by three documents needs to see all three, not discover them one re-upload at a time.

The 11 tokens are shared between `/status` and the online refusal, so one implementation serves both paths:

| `blocked_reason` | Row copy | Action |
|---|---|---|
| `DOCS_MISSING` | Not uploaded | → that document |
| `DOCS_EXPIRED` | Expired *date* | → that document |
| `DOCS_REJECTED` | *`rejection_reason` verbatim* | → that document |
| `DOCS_PENDING_REVIEW` | Under review · no action | none |
| `NO_VEHICLE` | No vehicle registered | → vehicle registration |
| `SUSPENDED` · `RESTRICTED` · `DELETION_REQUESTED` | plain reason | Contact support |
| `PAYOUT_NOT_READY` | Payment setup incomplete | Contact support (admin-run) |
| `DEVICE_BLACKLISTED` · `UNKNOWN` | plain reason | Contact support |

Rows that cannot be actioned get no chevron and no tap target.

### 4.3 Trip lifecycle — `features/trip`

**Single-stop only: pickup → dropoff.** No waypoints, no A/B/C, no "Mid point" badge. `ride_waypoints` is empty live, `models.Ride` has no waypoints field, and the product decision is that the app is single-stop. The Figma `Ride Accept` frame showing three stops is built as two.

Four sequential states, each with the same chrome — state banner, map, bottom action bar:

| State | Endpoint | Primary action |
|---|---|---|
| Heading to Pickup | `PATCH /rides/:id/arrive` | Arrived at Pickup |
| Waiting for Passengers | `PATCH /rides/:id/start` | Start Trip |
| In Trip | `PATCH /rides/:id/complete` | Finish Trip |
| Finish / Summary | `GET /rides/:id/earnings` | Ready for Next Request |

**Map** is `google_maps_flutter`, drawing `geo.route` from `GET /rides/:id` — a real OSRM road-following polyline (straight-line fallback) rendered as a `Polyline`. The route comes from our backend, not from the Directions API, so the driver sees the same geometry dispatch priced. The Maps API key ships per-platform via `--dart-define` and must be restricted by bundle id / SHA-1 and to the Maps SDK only. **ETA** comes from `pickup_eta_seconds` (live OSRM, targets pickup while approaching and dropoff once on-road).

**Rider identity is fully shown from acceptance onward** — name, photo, rating, call and chat, via `GET /rides/:id/rider-context`. A driver collecting a stranger needs to know who they are and how to reach them.

**Chat** badges from `chat_unread` on `GET /rides/:id`; opening `GET /rides/:id/messages` clears it. Messages carry WhatsApp-style receipts — a per-message `status` (`sent` → `read`), `reply_to_id` on send, and a `reply_to` preview on read. So the thread renders read state and quoted replies, not just a flat list.

**Waiting timer** must show the free period explicitly. Live config: 3 free minutes, then £0.30/min. A bare count-up does not tell a driver when charging starts.

**Cancel flow** (invented — no Figma frame): reason picker from `GET /cancellation-reasons?actor=driver`, showing **only `pickable: true`** entries so system outcomes (`driver_declined`, `offer_timeout`) never appear as choosable reasons. A reason carrying `penalty_fee_pence` shows a confirmation stating the exact charge before proceeding. `rider_no_show` has `free_cancel_seconds: 300`; `NO_SHOW_TOO_EARLY` returns the remaining `seconds` and the UI counts down.

**Finish summary** renders the earnings breakdown per §4.4 plus the passenger rating block (5 stars, tags, optional feedback).

### 4.4 Earnings — `features/earnings`

`GET /drivers/me/earnings/summary` for period totals (Today / This Week / This Month / All Time), `GET /drivers/me/earnings/report` for CSV export.

#### Breakdown: 7 lines, not 9

`GET /rides/:id/earnings` returns nine fields, but settlement writes `tax_pence` and `penalty_pence` as literal `0` (`payment_repo.go` — `VALUES (?, ?, ?, ?, ?, ?, ?, 0, 0, ?)`). VAT is not modelled and penalties are separate ledger entries.

**Rendered:** Base · Distance · Time · Surge · Waiting · Commission · **Net**.

**Rule: render a line only if its value is non-zero, or if it is Net.** Historical rides (settled before A1) fall back to `payout_splits` and render Net + Commission only — the sub-splits are genuinely 0 there, not merely unknown.

The Figma "This Week Breakdown" showing `Commission (15%)` and `Tax (VAT 20%)` is wrong twice: live commission is **20%**, and the VAT line asserts a treatment nobody has signed off. Neither is built.

#### Payouts — read-only

`GET /drivers/me/wallet` returns `available_balance`, `pending_balance`, `last_payout_at`, `recent_payouts[]`, `recent_bonuses[]` (note: **`float64`, not pence** — converted at the boundary).

Payouts are administered by the operator on a weekly or monthly cycle. The driver can do nothing. Next payout and history are **displayed read-only; there is no Retry button** and no payout-method capture — the driver never enters a destination.

### 4.5 Statement — `features/statement` *(invented)*

Both money directions, from `GET /drivers/me/ledger`.

```
Balance  −£50.00                       ← wallet.available_balance, signed

  Late arrival penalty        −£3.00   ← display_title      (server, verbatim)
  A penalty for arriving late…         ← display_reason     (server, verbatim)
  15 Jan · Running balance −£50.00
  [ Dispute ]                          → POST /me/support-tickets + ledger_entry_id

  Insurance levy              −£0.45
  …
```

Cursor-paginated (`next_cursor`), signed running balance per entry. Unmapped entry types return titled `"Adjustment"` with an empty reason — rendered as-is, never guessed at.

**"What you owe the company"** is a negative balance; **"what the company owes you"** is a positive one. Both are this screen. The Figma modals are superseded: their copy asserted *"auto-deducted from your next payout"* (which the backend deliberately refused to write) and invented `VAT 20%` and `Cancellation Penalty` rows the API does not return.

**Dispute is a per-row action**, not a separate screen — a driver disputing a specific charge should not navigate away and re-select which charge they meant. The standalone "Raise a Dispute" frame is dropped for that reason, not because the function is unbacked.

Backend is extending this area; rows bound to fields that return null are hidden rather than zero-filled.

### 4.6 Trips — `features/trips` *(invented)*

`GET /drivers/me/trips` → `id`, **`ref`** ("R-1042"), `status`, both labels, `distance_miles`, `driver_earnings_pence`, `penalty_pence`, **`cancelled_by`** (`driver|rider|admin|system`, null when completed), **`cancel_reason`** (human-readable, null if none recorded). Cursor paged.

```
[ All ]  [ Completed ]  [ Cancelled ]     ← server-side ?status=

Today
┌──────────────────────────────────┐
│ City Centre                      │
│ → Railway Station                │
│ R-1042 · 09:30 · 3.2 mi  +£8.30  │
└──────────────────────────────────┘

Yesterday
┌──────────────────────────────────┐
│ ⊘ Bilston Road                   │   ← cancelled: muted, ⊘,
│   → City Centre                  │     strikethrough destination
│   R-1038 · 14:22                 │
│   Cancelled by rider     −£59.00 │   ← cancelled_by + penalty, red
└──────────────────────────────────┘
```

**`ref` is shown on every row.** It is the reference a driver quotes to Support, so it must be visible without opening anything.

**`cancelled_by` is stated in words**, because "who cancelled this" is the first question a driver has about a cancelled trip: *"You cancelled"* · *"Cancelled by rider"* · *"Cancelled by Hoppin"* (admin) · *"Cancelled automatically"* (system — a matching timeout, explicitly not the driver's fault). `cancel_reason` renders beneath when present.

**Rows do not drill down.** There is no trip-detail screen in Phase 1 — a row states everything the endpoint returns.

- **Filters are server-side.** Client-side filtering would page 50 rows and display 12. A secondary filter `?cancelled_by=driver|others` separates "cancels I made" from "cancels made on me" — the distinction that drives the fair-stats rule in §4.7.
- **Grouped by day with sticky headers** — Today / Yesterday / *Tue 26 Aug*.
- **Cancelled trips are visible but demoted.** They are a third of live activity (24 cancelled against 36 completed) and drive the cancellation-rate stat, but should not compete with earned trips.
- **Penalties inline, red.** `penalty_pence: 0` renders an em dash, never "£0.00". A driver disputing a £59 no-show penalty needs the trip it came from.
- **No totals header** — that is Earnings' job; duplicating invites two screens disagreeing.
- Empty states are per-filter: *"No trips yet"* / *"No cancelled trips"*.

### 4.7 Stats — `features/stats`

`GET /drivers/me/stats` (rewritten in round 4):

```jsonc
{ "average_rating": 4.8,          // null until at least one review
  "rating_count": 5,
  "trips_completed": 15,
  "trips_cancelled": 3,           // ONLY cancels the driver made
  "online_minutes": 742,
  "penalties_count": 6,           // ledger-sourced
  "balance_pence": -5000,         // signed
  "earnings": { "total_pence", "this_week_pence", "this_month_pence", "currency" },
  "acceptance_rate": 0.94,        // null when no offers
  "completion_rate": 0.83 }       // null when no finished trips
```

Nullable rates render **"—", never "0%"**. A driver with no offers yet has an unknown acceptance rate, not a 0% one.

**Fair-stats rule (round 5):** `trips_cancelled` and `completion_rate` count only cancels the *driver* made. Rider cancels, admin force-cancels and watchdog timeouts no longer drag the driver's numbers down. The UI states this, because a driver who sees a cancellation count needs to know it is theirs.

**Penalties list — `GET /drivers/me/penalties`** (built in round 4, was 404):

```jsonc
{ "penalties":[{ "id","created_at","amount_pence":1000,
    "display_title","display_reason","ride_id"|null,"appealable":true }],
  "count":6 }
```

**A13 is resolved: the ledger is authoritative.** Both the list and `count` are ledger-sourced, and `stats.penalties_count` was re-pointed to match, so Stats, the penalty list and the Statement cannot disagree. The count is tappable and opens the list; `appealable` gates the appeal action per entry.

Penalties/Appeals accordion with four states (collapsed · Active · Under review · Resolved), backed by `GET/POST /drivers/me/compliance-appeals`. Each appeal carries `reason` (the driver's), `status`, **`review_note`** (the admin's reason — mandatory on both approve and reject), `reviewed_at`, `document_type`. **`review_note` is rendered as the outcome explanation**; an appeal decision that arrives without one is a backend bug, not a blank state to design around.

An appeal decision also arrives as a notification (`type: "compliance"`, deep-link `hoppin://appeals`) and an FCM push (`data.type = "compliance_appeal"`).

**Two corrections to the Figma:** "Total Trips **£**1247.00" carries a currency symbol on a count; and a *rising* cancellation rate is shown in green, which colours a bad trend as good.

### 4.8 Documents — `features/documents`

`GET /document-types` returns all 8 enum values with `uploadable` and `expires` flags. `nr3s_background_check` is `uploadable: false` — operator-run, so it shows status with no upload affordance.

`GET /drivers/me/documents` returns `verification_status` and **`rejection_reason`** (nullable). A rejected document shows the reason verbatim — server-owned copy, same principle as the ledger. Without it a driver re-uploads the same file and is rejected again.

Grid of document cards with expiry dates, plus the Document Appeal tile. Upload via `POST /drivers/me/documents/upload-url` then `POST /drivers/me/documents`. `STORAGE_DISABLED` (503) is retryable and surfaces as a temporary message.

Compliance appeals live here, per the standing decision.

### 4.9 Profile & settings — `features/profile`

**Personal Information** — first/last name, email, phone, avatar. Name and photo are verified; the screen says so and points to Support rather than offering an edit that will fail.

**Settings** — Notification toggle, Ride Request Sound, Do not lock screen, Appearance, Navigation (Google/Apple Maps), Distance Units (Miles/Kilometers). **No Language row** — single locale, and a row that does nothing is worse than none.

**Delete Account** — built whole, against `POST /me/delete-account`. UK GDPR right to erasure. Returns 200 `{status:"deleted"}` when eligible, or **409 `DELETION_BLOCKED` with `blockers[]`**: `active_trip`, `unresolved_dispute`, `outstanding_balance`, `compliance_investigation`. Each blocker renders as its own row explaining what must be resolved — the same list-not-a-message principle as the blocked-from-online state (§4.2).

Irreversible, so a confirm dialog precedes the call. Both paths build: Temporary Deactivation and Permanent Deletion. Backend scrubs PII and detaches documents; ride, payment and ledger history is retained de-identified.

> The `outstanding_balance` blocker routes to **Settle balance** (§4.12) once that endpoint exists. Until then the action is **disabled with a line directing the driver to Support** — an active-looking button that silently does nothing is worse than one that explains itself.

### 4.12 Payments — `features/payment`

**Purpose: settling a negative balance.** A driver who takes a large penalty can end up owing more than their earnings cover; a saved card lets them clear it. This is not "add a payment method" — a driver is paid, not charged, and a card form with no stated purpose would baffle them. The screen is **"Settle your balance"**; card management is supporting furniture.

**Card capture is Stripe SetupIntent only.** Mirrors the rider flow exactly (`POST /me/payment-methods/setup-intent` → `StartAddCard` returns a client secret → Stripe's own sheet collects the card). **The app never touches a PAN or CVV**, which keeps PCI scope at SAQ-A. The Figma `Add Payment Methods` frame draws a hand-rolled form with Card Number and CVV fields — that form is **never built**; a custom card form would pull the product into SAQ-D (annual on-site audit, quarterly scans, formal penetration testing).

Screens: saved-card list (brand + last4, set default, remove) and a Settle action on the Statement when `balance_pence` is negative, with a confirmation stating the exact amount before charging.

> **Backend dependency.** The four payment-method endpoints are currently `riderOnly()` — a driver JWT gets 403. The ask is to mirror them for drivers plus a charge-against-balance call; the handlers already exist, so it is a scoping change rather than new design. Until it lands the UI builds against the known contract and the Settle action ships disabled.
>
> **Open decision for the weekly cycle:** auto-charging a saved card for a debt is the sharpest form of the deduction-consent problem in §6.2. A driver-initiated "Settle now" is clean; an automatic weekly charge needs explicit recorded agreement captured when the card is saved, or it is a disputed transaction waiting to happen. To be settled before the backend builds the cycle.

### 4.10 Notifications — `features/notifications`

Fully backed, and built as drawn:

```
GET    /me/notifications           list — cursor paging, soft delete
PATCH  /me/notifications/:id/read
POST   /me/notifications/read-all
DELETE /me/notifications           clear all
DELETE /me/notifications/:id       dismiss one
```

Payload: `{id, type, title, body, ride_id, deep_link, read_at, read, created_at}`. `deep_link` routes the tap. All/Read/Unread tabs map to the `read` boolean.

**The endpoint is the history; push is an enhancement.** The list is never assembled from received pushes — the backend's own comment states this, and it is the only way the screen survives a dropped notification.

### 4.11 Support — `features/support`

**Help & Support** — FAQ accordion, Open Ticket, Email, legal links. *(The Figma FAQ states a £5 cancellation penalty; live config is £59.00 for `rider_no_show`. Copy is bound to real values, not hardcoded.)*

**Support tickets** — `POST /me/support-tickets` with issue category, description, preferred resolution; recent issues list with resolved/pending/rejected states. Also the destination for a ledger Dispute, carrying `ledger_entry_id`.

---

## 5. Not built in Phase 1

| Screen / feature | Reason |
|---|---|
| The hand-rolled card form (`Add Payment Methods` as drawn) | Raw PAN + CVV in our own form pulls the product into PCI-DSS SAQ-D. Payment **is** built (§4.12) via Stripe's SetupIntent sheet, mirroring the rider app. The frame is superseded, not the feature. |
| Settings → Language | Single locale. |
| Multi-stop A/B/C | Product decision: the app is single-stop. `ride_waypoints` is empty and `models.Ride` has no waypoints field. |
| Tips | No concept of tipping in the product. `driver_tips` has 0 rows and no endpoint serves them. The row is omitted entirely, not shown as £0.00. |
| Trip detail screen | Trips rows are terminal — a row states everything `/trips` returns, including `ref`, `cancelled_by` and `cancel_reason`. |
| Standalone "Raise a Dispute" | Function retained as a per-row action on the Statement. |
| Payout retry / payout method capture | Payouts are administered by the operator on a weekly or monthly cycle; the driver has no action to take. |

---

## 6. Decisions with reasoning

### 6.1 No rider identity before acceptance

The offer card shows fare, distances, ETA, category and countdown — **no name, photo, rating or comment**. Full identity appears from acceptance onward.

`PendingOffer` does not carry identity, but the reason we would not *ask* for it is the substantive one. If a driver sees a name and photo before choosing accept-or-decline, every decline becomes a data point tied to a protected characteristic, and the platform holds the evidence — a table showing a driver declining certain names at several times their baseline rate. In an Equality Act 2010 claim or a TfL licensing review that is the claimant's disclosure bundle, not a defence. The mirror risk is a disabled or accessibility-booking rider watching offers time out with no way for the operator to rebut a discrimination claim.

Withholding identity until acceptance means a refusal genuinely cannot have been about who the rider was. Cherry-picking is a secondary concern; evidence generation is the primary one.

If drivers need help judging a job, the fix is better *job* data — surge, airport/station flag, luggage, accessibility requirement. Discriminating between rides is legitimate; between riders is not.

### 6.2 Debt is shown plainly

Two drivers are genuinely in debt, most around −£50. The balance is displayed as a signed figure with every charge itemised in the server's own words.

What is not built is the Figma's *"This amount will be auto-deducted from your next payout"* — the backend deliberately declined to write that sentence, and the app should not assert a deduction mechanism the business has not signed off.

### 6.3 The blocked list is on Home, not a screen

A driver who cannot work should not have to navigate to learn why, and `blocking_document_types` is an array — a list surfaces every blocker at once instead of revealing them one re-upload at a time.

---

## 7. Open dependencies

| # | Item | Blocks | Status |
|---|---|---|---|
| A13 | Which penalty source is authoritative | — | ✅ **Closed** — ledger is authoritative; `stats.penalties_count` re-pointed to match |
| A11 | `GET /drivers/me/penalties` | — | ✅ **Closed** — built and deployed (was 404 this morning) |
| A12 | Confirm 5s poll interval | Nothing — assumption documented in §3.1 | Open across three rounds |
| — | Driver-scoped payment-method endpoints + charge-against-balance | Settle action (ships disabled) | To be raised — handlers exist, currently `riderOnly()` |
| — | Self-signup registration endpoints | Wizard submits nothing until they land | Backend in progress |
| — | Weekly settlement cycle mechanics | Nothing in Phase 1 | Product decision pending — see §4.12 |

**Nothing blocks Phase 1.** Every screen either has its endpoint or ships a disabled action with an explanation.

**Verification method.** Deployment claims are checked, not trusted: an unregistered route returns **404 before the auth check** while a registered one returns **401**, so probing `/api/v1/definitely-not-a-real-route` against a real path distinguishes a current build from a stale one without credentials. This caught a two-day gap between "merged" and "deployed" in an earlier round, and confirmed A11 going live.

---

## 8. Verification

Each screen is done when: it binds to its real endpoint against `api.hoppin.tech`; its error codes render mapped copy; its empty and failure states exist; no value on it is hardcoded from the Figma; and no row renders a field the API does not return.
