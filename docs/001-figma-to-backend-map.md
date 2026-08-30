# Driver App — Figma ↔ Backend Map

**Figma set:** `figma/driver view Super FINAL/` (40 frames, 430×932)
**Backend of record:** `hoppin/Go_ride_service` @ `:8080`, verified from source 2026-08-27
**Rule:** the backend is the authoritative source of truth. A screen with no endpoint is **dropped**, not faked.

> Note: `docs/420-figma-correction-pack.md` (2026-07-13) declared earnings, stats, appeals, waiting policy and cancel-reasons non-existent. **That doc is stale.** All of those shipped since. This map is re-derived from the current route table, not from that doc.

---

## 1. Verified route table (driver-relevant)

Base: `/api/v1`. Auth: Supabase JWT bearer, fail-closed. Driver group `drv := /api/v1/drivers/me` is role-gated.

### Driver-only group — `/api/v1/drivers/me`
| Method | Path | Serves |
|---|---|---|
| POST | `/location` | GPS ping (dispatchability heartbeat) |
| POST | `/online` · `/offline` | Presence toggle |
| GET | `/today` | `online`, `earnings_pence`, `trip_count`, `online_seconds`, `active_ride_id` |
| GET | `/offers` | Pending offers |
| POST | `/offers/:id/accept` · `/decline` | *(on `/api/v1`, not the drv group)* |
| GET | `/wallet` | `available_balance`, `pending_balance`, `recent_payouts`, `recent_bonuses` |
| GET | `/earnings/summary` | `?period=today\|week\|month\|all&tz=` |
| GET | `/earnings/report` | CSV, `?from&to`, ≤366 days |
| GET | `/stats` | `?period=week\|month\|all` |
| GET | `/trips` | Driver's own completed trips |
| GET/POST | `/documents` · `/documents/upload-url` | Compliance docs |
| POST/GET | `/compliance-appeals` | Appeal a **document**, track outcome |
| PUT/GET/DELETE | `/destination-filter` | Destination filter |
| POST/GET | `/vehicle` | Vehicle details |
| POST | `/avatar-upload-url` · `/avatar` | Profile photo |
| GET | `/promotions` | Driver promos |

### Shared `/api/v1`
`PATCH /rides/:id/{accept,arrive,start,complete,cancel}` · `GET /rides/:id` · `GET /rides/:id/rider-context` · `GET /rides/:id/earnings` · `GET /rides/:id/geo` · `GET /rides/:id/waiting-policy` · `POST|GET /rides/:id/messages` · `POST /rides/:id/rating` · `GET /rides` · `GET|PATCH /me/profile` · `GET|PATCH /me/preferences` · `GET /me/notifications` (+read/read-all/delete) · `POST|GET /me/sos` · `POST|GET /me/support-tickets` · `GET|POST /me/payout-account` · `GET /cancellation-reasons?actor=driver` · `GET /cancellation-policy` · `GET /document-types` · `GET /demand-heatmap` · `GET /service-areas` · `POST /me/device-tokens` · `POST /me/session` · `POST /me/delete-account`

### Transport
**No WebSocket, no SSE.** (`gin-contrib/sse` is an indirect dep only, no stream endpoint.) Realtime = **FCM push + polling**. Every live surface is a poller.

---

## 2. Screen-by-screen verdict

Legend: **BUILD** = fully backed · **ADAPT** = backed, but Figma must change · **DROP** = no backend

### Auth (6 frames)
| Frame | Verdict | Notes |
|---|---|---|
| Sign In | **BUILD** | Supabase Auth (email+password). Not a ride-service route. |
| OTP Screen | **ADAPT** | Supabase OTP. Confirm whether email or SMS OTP is enabled — design assumes one. |
| Forgot / Reset Password, Expired-link | **BUILD** | Supabase recovery flow. |
| — | add | `POST /me/session` (single-session claim) must fire post-login. No frame. |

### Onboarding / compliance (3)
| Frame | Verdict | Notes |
|---|---|---|
| Select and Upload Document | **ADAPT** | Flow is `POST /documents/upload-url` → PUT to storage → `POST /documents`. Figma's single "Upload" is a **2-step** upload. |
| Uploaded Multiple Document List | **ADAPT** | Badges must render the real enum: `pending_review`, `approved`, `rejected`, `expired`. |
| Vehicle Registration | **BUILD** | `POST /drivers/me/vehicle`. |

**Document types — exactly 7, all required.** Fetch from `GET /document-types`, never hardcode:
`dvla_license`, `wolverhampton_taxi_badge`, `right_to_work`, `mot_certificate`, `insurance_policy`, `v5c_logbook`, `caz_compliance_proof`.
The 4-step wizard (1-2-3-4) does not match 7 types — **re-spec as a checklist**, not a fixed 4-step.

### Ride lifecycle (8)
| Frame | Verdict | Notes |
|---|---|---|
| Ride Request Off (offline radar) | **BUILD** | `POST /offline`. |
| Ride Request On (offer list) | **ADAPT** 🔴 | See §3.1 — offers carry **coords + fare only**. |
| Ride Accept | **ADAPT** 🔴 | Same. A/B/C multi-stop: see §3.2. |
| Heading to Pickup | **BUILD** | `PATCH /rides/:id/arrive`, `GET /rides/:id/geo`. |
| Waiting for Passengers | **BUILD** ✅ | `GET /rides/:id/waiting-policy` gives `free_wait_seconds` + `per_minute_pence`. Countdown is now honest. |
| Start Ride | **BUILD** | `PATCH /rides/:id/start`. |
| Finish Ride (×2) | **ADAPT** | Fare breakdown maps 1:1 (§3.3). Rating chips do not (§3.4). |

### Money (5)
| Frame | Verdict | Notes |
|---|---|---|
| Earnings | **ADAPT** | Summary + breakdown are real (§3.3). |
| What company owes you | **ADAPT** | Map to `wallet.available_balance` / `pending_balance`. |
| Earning – You Owe (×3) | **BUILD, blocked on API** | Concept exists (ledger, §3.5). Needs `GET /drivers/me/ledger`. Design now, bind when it ships. |
| Payment Methods (×2) | **DROP** 🔴 | **Owner ruling: payouts are administered in the admin panel, not the driver app.** Drop both frames outright — no payout onboarding in this app either. Note `POST /drivers/me/online` still returns `PAYOUT_NOT_READY`, so the driver needs a **read-only explainer state** ("payout setup pending — contact ops"), not a setup flow. |

### Performance (5)
| Frame | Verdict | Notes |
|---|---|---|
| Stats | **ADAPT** | `GET /drivers/me/stats` — rating, acceptance/completion/cancellation, all with raw counts. Rates are **nullable**: render "—", never 0%. |
| Stats Active / Under Review / Resolved | **ADAPT** 🔴 | Appeals exist but are **document-scoped**, not penalty-scoped (§3.6). |

### Comms (4)
| Frame | Verdict | Notes |
|---|---|---|
| Conversation | **BUILD** | `POST|GET /rides/:id/messages`, poll. |
| Incoming Call ×2, During Call | **DROP** 🔴 | No voice/VoIP anywhere in the backend. No masked-number provider (no Twilio/Vonage). Replace with a native `tel:` handoff **only if** a masked number exists — it does not today. |

### Account (7)
| Frame | Verdict | Notes |
|---|---|---|
| Side Nav Bar | **BUILD** | Drop "Payment Methods" → "Payouts". |
| Personal Information (×2) | **ADAPT** | `PATCH /me/profile` accepts **`full_name` + `phone_number` only**. Email read-only. No city field — drop it. Avatar via `/drivers/me/avatar-upload-url`. |
| Notifications | **BUILD** | `GET /me/notifications`, read / read-all / delete. |
| Setting | **ADAPT** | See §3.7 — most toggles unbacked. |

### Bottom nav
Figma shows **Home · Earnings · Records · Stats · Wallet** on every screen.
- **Records** — no frame, no obvious endpoint. Map to `GET /drivers/me/trips` (trip history) and **rename to Trips**.
- **Wallet** vs **Earnings** — two tabs, overlapping. `GET /wallet` (balance/payouts) vs `GET /earnings/summary` (period totals). Recommend merging into one **Earnings** tab with a Payouts sub-view → **4 tabs**.

---

## 3. The hard conflicts

### 3.1 🔴 Offer cards show data the offer does not carry
`PendingOffer` is exactly:
```
offer_id, ride_id, pickup_lat, pickup_lng, dropoff_lat, dropoff_lng,
fare, estimated_miles, expires_at, offered_at
```
Figma offer cards show **rider photo, name, star rating, rating count, and a "Comment:" line**. None of it is in the payload.

`GET /rides/:id/rider-context` **does** carry `name`, `photo_url`, `rating`, `rating_count`, `recent_comments` — but a pending offer is pre-acceptance, and that endpoint is ride-scoped and ownership-gated.

**Decision needed.** Options:
- **(a) Ship offers coords-only** — address text via reverse-geocode, no rider identity until accepted. Zero backend work. *Recommended.*
- **(b) Ask backend to widen `PendingOffer`** with rider name/rating. Business call: showing rider identity pre-acceptance enables cherry-picking and carries discrimination risk.

Also: the offer has **no address text**. Figma shows "Wolverhampton City Center". Use `GET /geocode/reverse` per offer, and design a loading state for it.

`expires_at` is in the payload but **no frame shows an offer countdown** — offers expire silently in the design. Needs a timer.

### 3.2 🔴 A/B/C multi-stop — the driver cannot read the stops
Figma shows A → B ("Mid point") → C on Ride Accept, Heading to Pickup, and Waiting.

Verified end to end:
- Rider booking **accepts** `waypoints[]` (`ride_handler.go:530`), stages them (`booking_waypoints`), and attaches them to `rides.waypoints` (`AttachRideWaypoints`).
- `models.Ride` has **no waypoints field** — `GET /rides/:id` cannot return them.
- `RideGeoView` is `pickup_lat/lng`, `dropoff_lat/lng`, plus `route[]` / `approach[]` polylines. **No waypoint array.**
- `PendingOffer` is one pickup + one dropoff pair.

So multi-stop is **written but never readable**. There is no endpoint through which a driver can learn stop B exists.

**Owner ruling: multi-stop is deferred to Phase 2.** Build the ride UI as 2-stop (pickup → dropoff) in Phase 1. Drop the A/B/C strip and the "Mid point" marker from the Phase-1 frames.

Phase-2 prerequisite (one-line backend ask, data already in the row): expose `waypoints` on `GET /rides/:id` or `/rides/:id/geo`. Keep the trip UI's stop list a **collection** internally even while it renders 2 entries, so Phase 2 is a data change and not a rewrite.

### 3.3 ✅ Fare breakdown matches exactly
`GET /rides/:id/earnings` → `base_pence, distance_pence, time_pence, surge_pence, waiting_pence, commission_pence, tax_pence, penalty_pence, net_pence`.
`GET /drivers/me/earnings/summary` → `trips, gross_pence, commission_pence, tax_pence, penalties_pence, net_pence, online_seconds, avg_net_per_trip_pence, currency`.

Both cover the Figma Earnings breakdown. **All money is `int64` pence** — never use a float in the client.

**Tips — correction:** a `driver_tips` table exists (mig 001: `tip_amount`, `currency`, `status`, `ryft_transaction_id`). Tips are real in the schema, but **no tips field is surfaced** in `RideEarnings` or `EarningsSummary`. Same shape as the ledger gap: the data exists, the API does not carry it. Design the Tips row; bind it when the field ships. Do not compute it client-side.

### 3.4 Rating chips have no field
`POST /rides/:id/rating` = `{score: 1-5, comments: string}`. Figma's preset chips (Clean · Polite · Quite · Ready on Time) have **nowhere to go** — they'd be silently discarded. Ship stars + free-text only. (Also: "Quite" is a typo for "Quiet" in the frame.)

### 3.5 "You Owe the Company" — the concept EXISTS; it is not exposed to the driver

**Correction.** The debt concept is real and well-built in the backend. What is missing is only the driver-facing read endpoint.

What exists (`Go_Database/migrations/`):
- **`ledger_entries` (mig 045)** — immutable double-entry ledger. Signed `amount`; `(+)` credits, `(-)` debits. `account_type` ∈ `driver | rider | platform`. `entry_type` ∈ `penalty | earning | commission | levy | payout | adjustment | rider_fee | driver_credit | refund | opening_balance`. Legs of one event share `txn_group`; `idempotency_key` is UNIQUE so replays never double-post. **An account's balance is the SUM of its entries — and it can be negative.**
- **`driver_wallets` (mig 001)** — `available_balance` / `pending_balance` are `DECIMAL(10,2)` with **no CHECK ≥ 0**, so negative is representable.
- **Invariant (mig 046):** `driver_wallets.available_balance == SUM(ledger entries WHERE account_id = driver)`.
- **`deduction_rules` (034/043/047)** — admin-configured, typed by `frequency` (`per_ride` | `per_event`) and `event_type` (`ride_cancelled`, `passenger_complaint`, `driver_late`, …), targetable at all drivers or selected ones, with a `target` column separating driver-charged from rider-charged rules.
- **`deduction_applications` (035)** — the per-application audit log feeding the admin Deductions panel.
- **`settlement_schedules` (034/035)** — frequency, `run_time`, timezone, `min_payout`, `auto_retry`, `pause_on_anomaly`, `last_run_at`. This is the payout run that a debt would net against.
- **`driver_tips` (mig 001)** — so the Figma **Tips** line is real after all (see §3.3 correction).

**The actual gap is narrow:** the ride-service driver earnings query (`driver_earnings_repo.go`) is **per-completed-ride** — it joins `ledger_entries` only `WHERE ride_id = r.id AND entry_type = 'penalty'`. A standalone debt entry (`ride_id IS NULL` — a weekly levy, an admin adjustment, a VAT charge) is **invisible to the driver**. There is no `GET /drivers/me/balance` or ledger-statement endpoint.

**So the frames are not fiction — they are ahead of the API.** This is a "backend is behind" item, not a "missing concept" item.

**Recommended:** build the You-Owe screens against a new endpoint, and ask backend for:
> `GET /drivers/me/ledger?from&to` → running balance + entries (`amount`, `entry_type`, `reason`, `ride_id?`, `created_at`), plus a `balance_pence` that may be negative.

Two caveats that remain live and are **not** solved by the schema:
1. **VAT principal-vs-agent is still a business/tax decision.** The ledger has no VAT entry type; the Figma's "VAT 20% (overdue)" line presumes a treatment nobody has ratified. Do not encode it — render whatever `entry_type`/`reason` the server sends.
2. **"Auto-deducted from your next payout"** is a policy statement about deductions from a self-employed worker's pay. The mechanism exists (`settlement_schedules` + `min_payout`), but the copy must reflect the operator's actual, signed-off policy — not be invented in the UI.

**Dispute Charge:** no dispute endpoint for a ledger entry exists. Nearest real surface is `POST /me/support-tickets`. Wire the button there rather than to a non-existent dispute API.

### 3.6 Appeals are document-scoped, not penalty-scoped
`POST /drivers/me/compliance-appeals` = `{document_type, reason}`. Returns `{id, status}`. List gives `status`, `review_note`, `reviewed_at`.

Figma's Stats screen shows **"Penalties and Appeals — 1 penalty currently affecting your account"**. There is **no penalty-appeal endpoint**. `stats.penalties_active` is a count only, with no listing endpoint and nothing to appeal against.

**Adapt:** move the appeals section out of Stats and onto **Documents**, where it is genuinely backed ("appeal a rejected document"). On Stats, render `penalties_active` as a bare count with no appeal affordance — or drop the section.
The three states (Active/Under Review/Resolved) map onto appeal `status` and are reusable once re-pointed at documents.

### 3.7 Settings — server-persisted allowlist is exactly 9 keys
`GET|PATCH /me/preferences` (users.preferences JSONB). The server owns the whitelist; **an unknown key is rejected**, so the client cannot stash extras:

```
push_trip_updates   bool     push_promotions   bool
push_payouts        bool     email_receipts    bool
sms_trip_updates    bool     sound_offer_chime bool
marketing_consent   bool
theme               "system" | "light" | "dark"
language            BCP 47 tag, ≤8 chars
```
Unset keys are **absent**, not false — the client applies its own defaults.

Mapping the Figma Settings rows:
- **Notification** → split into the real toggles: `push_trip_updates`, `push_promotions`, `push_payouts`. One row cannot represent three. ✅ backed
- **Ride Request Sound** → `sound_offer_chime`. ✅ backed
- **Appearance (dark/light)** → `theme`, and it is **server-persisted, not client-only** — syncs across devices. ✅ backed
- **Do not lock screen** → client-side wakelock. Keep, store locally.
- **Distance Units (mi/km)** → **no preference key.** Client-side local setting only. Keep, but centralise formatting.
- **Navigation (Apple/Google Maps)** → no key. Client-side local. Keep.
- **Language** → key exists and validates, **but the app has no i18n.** Persisting a language that changes nothing is a lie. **Drop the row** until strings are externalised; the key is ready when it is.
- **Delete Account** → `POST /me/delete-account`. ✅ Keep.
- Not in Figma but backed: `email_receipts`, `sms_trip_updates`, `marketing_consent` — `marketing_consent` is a **GDPR consent record** and should be surfaced.

---

## 4. Backed capability with NO frame — needs design

| # | Capability | Endpoint | Why it matters |
|---|---|---|---|
| 4.1 🔴 | **Driver cancel / no-show exit** | `PATCH /rides/:id/cancel` + `GET /cancellation-reasons?actor=driver` | Fully backed now, incl. `NO_SHOW_TOO_EARLY` with `seconds_remaining`. **Zero frames.** A driver at a no-show pickup has no exit in the design. Safety. |
| 4.2 | **Destination filter** | `PUT|GET|DELETE /drivers/me/destination-filter` | Three working endpoints, no UI. Best cost/benefit item. |
| 4.3 🔴 | **Presence / heartbeat state** | `POST /location` + `today.online` | Driver must see `ONLINE · live` / `ONLINE · location stale — not receiving offers` / `OFFLINE`. No frame. |
| 4.4 | **Relaunch recovery** | `GET /drivers/me/today` → `active_ride_id` | Resume into a live trip after app restart. No frame. |
| 4.5 | **Go-online rejections** | `POST /online` | Returns `PAYOUT_NOT_READY` ("finish payout setup to start earning") and `DEVICE_BLACKLISTED`. **No frame for either.** A driver blocked from going online sees nothing. |
| 4.6 | **Payout-not-ready explainer** | `POST /drivers/me/online` → `PAYOUT_NOT_READY` | Payouts are admin-administered, so this is a **read-only blocked state**, not a setup flow. Driver must be told why they cannot go online and who to contact. |
| 4.7 | **SOS** | `POST|GET /me/sos` | Safety endpoint, no frame. |
| 4.8 | **Support tickets** | `POST|GET /me/support-tickets` | Side nav has "Help & Support", no frame. |
| 4.9 | **Demand heatmap** | `GET /demand-heatmap` | Backed overlay, no frame. |
| 4.10 | **Earnings CSV export** | `GET /earnings/report` | Backed, no frame. |
| 4.11 | **Android background location** | — | Two-stage OS grant + hard-denied recovery. No frame. |

## 5. Missing everywhere (all screens)
No empty, loading, error, or offline-network states in any of the 40 frames. Every list needs all four.

---

## 6. Net count

| Bucket | Frames |
|---|---|
| BUILD as drawn | ~14 |
| ADAPT (backend wins) | ~15 |
| DROP | ~6 — Payment Methods ×2, Calls ×3, Language row |
| DEFERRED to Phase 2 | multi-stop A/B/C strip (not whole frames) |
| BLOCKED on a new endpoint | You-Owe ×3 (needs `GET /drivers/me/ledger`) |
| New screens needed | ~11 (§4) |

**Revised after the owner's corrections:** the design is closer to the backend than the first pass suggested. The driver-debt frames are *ahead of the API*, not fiction — the ledger is built and admin-driven. Genuinely unbuildable is now ~15%, and it is concentrated in **voice calling** (no provider at all) and **driver-side payouts** (deliberately out of scope for this app).
