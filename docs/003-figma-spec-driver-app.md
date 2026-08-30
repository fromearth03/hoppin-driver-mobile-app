# Driver App — Design Spec & Frame Corrections

**To:** Design, via the owner
**From:** Driver app build (Flutter, fresh build)
**Date:** 2026-08-27
**Current file:** `figma/driver view Super FINAL/` — 40 frames, 430×932

---

## 1. Read this first

The frames were drawn before the backend contract was known. That is nobody's fault — the API didn't exist in a readable form when the design work happened. But the app is now being built against the real server, and in a number of places the design promises something the server cannot deliver.

**The project's standing rule:**

> **Truth wins over Figma.** Where the design promises what the backend cannot do, the app tells the truth and the frame is the thing that gets corrected.

This matters more for a driver app than a rider app. **A driver app shows a person their pay, their debt, and the performance numbers that decide whether they keep their job.** A made-up number on a rider screen is a bad estimate. A made-up number on a driver screen is a liability — and in the UK, a statement about deductions from a self-employed worker's pay has legal weight.

So the build follows one rule: **the app renders no figure the server did not send.**

**Everything below is verified against the live production database on 2026-08-27** — not against docs, not against assumptions. Where I quote a number (£0.30/min, 3 free minutes, 20% commission), that is what is actually configured in production right now, and you can design to it with confidence.

### Good news first

Most of the design is buildable. The earlier internal audit (July) claimed driver earnings, stats, appeals and waiting-time were entirely unbacked. **That audit is out of date** — all of those shipped since. Roughly 70% of the file maps cleanly. The corrections below are concentrated in a few specific areas.

---

## 2. Summary of what's needed

| Category | Count | What it means |
|---|---|---|
| ✅ Build as drawn | ~14 frames | No change needed |
| 🔧 Correct | ~15 frames | Real data differs from what's drawn |
| ❌ Remove | ~6 frames | No backend, and none planned for Phase 1 |
| ⏸ Phase 2 | 4 frames | Deferred by the owner, keep the file |
| ➕ New frames needed | ~11 | Working capability with no design |

---

## 3. ❌ Remove from Phase 1

### 3.1 Driver Payment Methods — 2 frames
**Frames:** `Payment Methods.svg`, `Payment Methods-1.svg`

**Remove entirely.** Two independent reasons:

1. **Owner ruling:** driver payouts are administered in the **admin panel**, not the driver app. A driver never sets up their own payout destination.
2. The frames borrow the rider's card-entry pattern, which is the **wrong direction of money**. A saved card is for *charging a customer*. A driver needs a *payout destination* (bank account) — a completely different object. Attaching a card to a driver would send money the wrong way.

Confirmed in the live schema: `driver_bank_accounts` and `payment_methods` were both **dropped** from the database. There is nothing behind these screens and nothing planned.

**Replace with:** a read-only status row (see §6.4) — a driver still needs to know *why* they can't go online when payout setup is incomplete.

### 3.2 Voice call — 3 frames → ⏸ **Phase 2**
**Frames:** `Incoming Call.svg`, `Incoming Call 2.svg`, `During Call.svg`

**Owner ruling: calling is Phase 2.** There is no VoIP provider and no masked-number service anywhere in the platform today.

**Keep these frames in the file** — don't delete them, they'll be needed. Just mark them Phase 2 so nobody builds against them now.

Phase 1 is **chat-only**. The `Conversation.svg` frame is fully backed and ships as drawn.

⚠️ **One thing to fix now:** the trip frames (`Heading to Pickup`, `Waiting for Passengers`) show a **green phone button next to the chat button**. In Phase 1 that button does nothing. Please provide those frames with the call button removed, so we don't ship a dead control.

### 3.3 Settings — remove the Language row
**Frame:** `Setting.svg`

The app has **no translations**. A language picker that changes nothing is a lie the user can't detect. The preference *key* exists server-side and is ready — so this returns the day strings are translated, but not before.

---

## 4. 🔧 Corrections — real data differs from the frames

### 4.1 🔴 Earnings — "You Owe the Company" (3 frames)
**Frames:** `Earning - You Owe.svg`, `Earning - You Owe-1.svg`, `Earning - You Owe-2.svg`

**The concept is real — I was wrong to doubt it.** The backend has a proper double-entry ledger, and **two drivers are in debt in production right now** (worst: −£50.00). Driver debt is a live, working part of this business.

**But the API to read it doesn't exist yet.** These screens are *ahead of the backend*, not fiction. We've asked for the endpoint; they're deferred until it lands.

**What to change now:**

| Element in the frame | Problem | What to do |
|---|---|---|
| **"VAT 20% (overdue) £95.29"** | The VAT treatment (principal vs agent) is a **business/tax decision the company hasn't formally made**. The frame silently picks one. | Remove the VAT line. Draw a **generic deduction row** that takes a server-supplied label instead. |
| **"This amount will be auto-deducted from your next payout"** | A policy statement about deductions from a **self-employed worker's pay**. Live UK legal exposure. | Remove. The server will send the exact approved wording; draw a slot for a 1–2 line server-supplied message. |
| **All figures** (£245.80, £90.29, £95.29) | Invented. | Mark explicitly as **placeholder** (see §8). |
| **"Dispute Charge" button** | No dispute endpoint exists. | Keep the button — it will file a support ticket. Relabel to **"Question this charge"**, which is what actually happens. |

**Design the deduction row as a repeating component:**
```
[icon]  Late arrival penalty                      −£3.00
        You arrived more than 10 minutes after
        the quoted ETA.
        26 Aug · Trip #1234                    [Question this charge]
```
Both the **title** and the **reason sentence** come from the server. The owner's explicit requirement: *a driver must be told why they were charged, for every deduction.* So every row needs room for a real sentence, not just an amount.

**Live deduction rules in production** (design to these):

| Rule | Amount | When |
|---|---|---|
| Insurance Levy | £0.45 | every ride |
| Driver Late Penalty | £3.00 | arriving late |
| Low Rating Penalty | £2.00 | rating drops |
| Passenger Complaint Penalty | £10.00 | upheld complaint |

Also needed: **positive** entries use the same component (bonuses, credits, refunds are all real live types). The screen is a **statement**, not just a debt list. Balance can be positive or negative — please draw both.

### 4.2 🔴 Earnings breakdown — Tips has no data
**Frame:** `Earnings.svg`

The weekly breakdown maps almost perfectly to the server:

| Frame row | Backed? |
|---|---|
| Base Fare | ✅ |
| Distance / Time | ✅ |
| Surge | ✅ |
| **Tips** | ⚠️ **Table exists but has 0 rows; not exposed by the API** |
| Commission (15%) | ✅ but **the live rate is 20%, not 15%** |
| Tax (VAT 20%) | ✅ |
| Penalties | ✅ |
| Net Total | ✅ |

**Two fixes:**
1. **Commission is 20% in production**, not 15%. Please update the frame. Better: draw it as **"Commission"** with the percentage supplied by the server, since it is admin-configurable per zone and will not always be 20%.
2. **Tips** — confirm with the owner whether tipping is live. If not, remove the row; a permanent £0.00 line invites "where are my tips?" support tickets.

### 4.3 🔴 Finish Ride — the breakdown will show zeros
**Frames:** `Finish Ride.svg`, `Finish Ride-1.svg`

The frame shows Base Fare / Wait Time / Distance & Time / Total. The server has a table shaped exactly for this — **but it is empty in production: 0 rows against 36 completed rides.**

We've raised this as the #1 backend blocker. Until it's fixed, the itemised breakdown renders £0.00 on every line while the total is correct.

**Please design an alternative compact state** for this card: total earned + payment method, with the itemisation collapsed or omitted. We need something honest to ship if the breakdown isn't populated in time.

**Also on this frame — the rating chips.** "Clean · Polite · Quite · Ready on Time" have **nowhere to go**: the rating API accepts a score (1–5) and free text only. Tapping a chip would silently discard it.
- **Remove the chips**, keep stars + the optional comment box. (24 reviews live, 8 with comments — the free-text box gets real use.)
- Minor: **"Quite"** is a typo for "Quiet".

### 4.4 🔴 Offer cards — rider identity isn't available
**Frames:** `Ride Request On.svg`, `Ride Accept.svg`

The offer cards show **rider photo, name, star rating "4.3 (13)", and a "Comment:" line**. None of it is in the offer payload. The offer carries only: coordinates, fare, estimated miles, and an expiry.

**This is deliberate, not an oversight.** We are *not* asking the backend to add rider identity to offers, for two reasons:
1. It enables cherry-picking by rider rating.
2. Rider name and photo shown pre-acceptance carries **discrimination risk** under UK equality law.

Rider name, photo, rating and comments **are** available *after* the driver accepts — that's what `Heading to Pickup` and the trip screens should show, and they're right to.

**Redesign the offer card around what a driver actually decides on:**
```
┌──────────────────────────────────────┐
│  £20.15                    ⏱ 0:23    │  ← fare + expiry countdown
│  8.6 mi · ~34 min                    │
│                                      │
│  ● Pickup   Wolverhampton City Ctr   │
│    5 min away (2.1 mi)               │
│  ● Dropoff  Transit Station, W'ton   │
│                                      │
│  [ Standard ]                        │  ← ride category
│  ┌────────────┐  ┌────────────────┐  │
│  │  Decline   │  │   Accept       │  │
│  └────────────┘  └────────────────┘  │
└──────────────────────────────────────┘
```

⚠️ **The expiry countdown is missing from every frame.** Offers expire — live data shows 3 timed out and 3 declined out of 55. A driver must see time running out. **This is the single most important addition to this screen.**

Addresses depend on a pending backend ask. Please design a **loading state** for the address lines (fare and distance appear immediately; addresses resolve a moment later).

### 4.5 🔴 Stats — appeals move to Documents
**Frames:** `Stats.svg`, `Stats Active Appeal.svg`, `Stats Under Review.svg`, `Stats Resolved.svg`

The Stats frame shows **"Penalties and Appeals — 1 penalty currently affecting your account"** with Active / Under Review / Resolved states.

**The problem:** the appeals system in the backend appeals a **document** (an expired licence, a rejected insurance certificate) — not a penalty. There is no endpoint to list penalties or contest one.

**Owner's decision: move appeals onto the Documents screen**, where they're genuinely backed.

- **On Stats:** keep the penalty **count** as a plain, non-tappable stat. Remove the appeal affordance.
- **On Documents:** add the appeals section. The three states (Active / Under Review / Resolved) are **good work and fully reusable** — just re-point them at documents. A rejected document with an "Appeal this decision" action is exactly right.

**Stats data — what's real:**

| Frame shows | Reality |
|---|---|
| Total Trips **£1247.00** | ⚠️ Trips is a **count**, not a currency. The frame shows a £ figure under a "Total Trips" label. Please fix. |
| Rating 4.7 | ✅ Real (live average 4.96 across 33 drivers) |
| Acceptance Rate 96% | ✅ Real |
| Cancellation Rate 4% | ✅ Real |

⚠️ **Critical: every rate can be legitimately absent.** A driver who received no offers this week has *no* acceptance rate. The server correctly sends "no value" rather than 0%, because **0% and "no data" mean very different things to someone whose job depends on the number.**

**Please design an "—" / "No data this period" state for each stat tile.** This is not an edge case; it's every new driver's first week.

### 4.6 Documents — the upload flow is 2 steps, and the type list is wrong
**Frames:** `Select and Upload Document.svg`, `Uploaded Multiple Document List.svg`

**a) The 4-step wizard (1-2-3-4) doesn't match reality.** There are **7–8 document types**, all required. Please re-spec as a **checklist** — a list of required documents each with its own status, that the driver works through in any order. That's how the data is actually shaped, and it's friendlier: a driver can upload their MOT today and their insurance tomorrow.

**Live document types:**
`DVLA Driving Licence` · `Wolverhampton Taxi Badge` · `Right to Work` · `MOT Certificate` · `Insurance Policy` · `V5C Logbook` · `Clean Air Zone Compliance` (+ `NR3S Background Check`, pending backend confirmation)

There is **no "Medical Certificate"** — if that appears anywhere in the file, please remove it; uploading it returns an error.

**b) Status badges must cover 4 states**, not just "Valid":
`Pending review` (grey — where every upload starts) · `Approved` (green) · `Rejected` (red, with the reason and an Appeal action) · `Expired` (amber, with re-upload)

⚠️ **`Pending review` is the state every document sits in immediately after upload.** It's currently missing from the design, and it's the one a driver sees most often.

**c) Upload is a 2-step process** (request a URL, then upload). Please design a **progress state** between "chose file" and "uploaded" — for a photo of a logbook on mobile data, that's a real wait.

### 4.7 Personal Information — two fields don't exist
**Frames:** `Personal Information.svg`, `Personal Information-1.svg`

The profile API accepts exactly **two** editable fields: **full name** and **phone number**. Email is read-only.

| Field in frame | Status |
|---|---|
| Full name | ✅ Editable |
| Phone number | ✅ Editable |
| Email | ⚠️ Show as **read-only** |
| **City** (e.g. "Wolverhampton, England") | ❌ **Remove.** There is no city field anywhere in the system — not a missing endpoint, a missing *concept*. |
| Profile photo | ✅ Real (avatar upload exists) |

### 4.8 Settings — map to the real preference keys
**Frame:** `Setting.svg`

The server stores exactly 9 preferences. Mapping:

| Frame row | Reality |
|---|---|
| **Notification** (one toggle) | ⚠️ There are **three** separate server toggles: **Trip updates**, **Promotions**, **Payouts**. One row can't represent three — please split. |
| Ride Request Sound | ✅ Real (`sound_offer_chime`) |
| Do not lock the screen | ✅ Client-side, works |
| Appearance (dark/light) | ✅ Real — and **server-persisted**, so it follows the driver across devices. Both themes are already designed. |
| Navigation (Apple/Google) | ✅ Client-side choice |
| Distance Units (mi/km) | ✅ Client-side |
| **Language** | ❌ **Remove** (§3.3) |
| Delete Account | ✅ Real |
| *(missing)* | ➕ **Email receipts**, **SMS trip updates** — real toggles with no row |
| *(missing)* | ➕ **Marketing consent** — this is a **GDPR consent record** and should be visible and changeable |

### 4.9 Bottom navigation — 5 tabs → 4
**Every frame.** Currently: Home · Earnings · Records · Stats · Wallet.

Two problems, both confirmed by the owner:
- **Records** has no frame anywhere in the file and no clear purpose.
- **Wallet** and **Earnings** overlap — both are "my money", and it's not clear which a driver would tap.

**Agreed structure — 4 tabs:**

| Tab | Contains |
|---|---|
| **Home** | Online/offline toggle, offers, active trip |
| **Earnings** | Period totals + breakdown · **Statement** (balance, deductions, what you owe / are owed) · Payout history *(read-only)* |
| **Trips** | Completed trip history *(this is what "Records" was reaching for)* |
| **Stats** | Rating, acceptance, completion, cancellation |

Please re-cut the tab bar across all frames, and add the **Earnings → Statement** sub-view.

### 4.10 Small corrections
- **Side Nav:** rename "Payment Methods" → remove (§3.1). "Help & Support" needs a destination frame (§6.8).
- **Waiting timer:** the live policy is **3 free minutes, then £0.30/min**. If the design implies a different threshold, align it. A **count-up** with "charging begins at 3:00" is honest; a count*down* to an invented number is not.
- **No-show:** a driver may report a no-show after **5 minutes** (£59.00 penalty applies to the rider). This threshold is real and should be shown.

---

## 5. ⏸ Phase 2 — keep, don't build

### 5.1 Multi-stop (A / B / C)
**Frames:** `Ride Accept`, `Heading to Pickup`, `Waiting for Passengers` — the A → B ("Mid point") → C strip.

**Owner ruling: Phase 2.** Confirmed in the live database: the waypoints table exists but has **0 rows** — multi-stop has never been used in production, and no driver-facing endpoint can read the stops back.

**For Phase 1:** please supply these three frames in a **2-stop version** (pickup → dropoff only). Keep the multi-stop versions in the file for Phase 2.

### 5.2 Voice calling
See §3.2. Frames stay; call buttons come off the Phase 1 trip frames.

---

## 6. ➕ New frames needed

Real, working capability with no design. Ordered by importance.

### 6.1 🔴 Driver cancel / no-show exit — **safety**
**The single most important gap in the file.**

Today a driver at a pickup where the rider never shows has **no way out** in any of the 40 frames. They are stuck in an active trip.

The backend fully supports this: a reasons list, a 5-minute no-show threshold, and a specific error telling the driver how much longer they must wait.

**Needed:**
- A **cancel action** on the active-trip screens
- A **reason picker** — live options: *Rider did not show up* · *Can't reach the rider* · *Vehicle problem*
- A **confirmation** step showing whether a penalty applies
- A **"too early" state**: *"You can report a no-show in 2:14"* with a live countdown

⚠️ The file also **contradicts itself** here: one frame says *"You cannot cancel a ride after accepting it"*, while the Earnings sheet has a *"Cancellation penalty"* line — which implies cancelling *is* possible. Both can't be true. The truth: cancelling is possible, and it may carry a penalty.

### 6.2 🔴 Presence / heartbeat — "you are not receiving offers"
A driver's location can silently go stale (tunnel, background kill, GPS drop). They're then **invisible to dispatch while believing they're online.** Nothing tells them.

**Needed — three distinct states in the Home header:**
- 🟢 **Online** — receiving offers
- 🟡 **Online, location stale** — *"You're not receiving offers. Check your connection."*
- ⚪ **Offline**

The amber state is the one that matters. **Better a driver who knows they're offline than one who thinks they're online.**

### 6.3 🔴 Blocked from going online
Going online can be **refused** by the server. In production, **only 4 of 33 drivers currently have payouts enabled** — so this is the *common* case, not an edge case.

**Needed — a blocked state on Home** explaining, in plain language:
- *Payout setup incomplete* → **"Your payout details are being set up by the office. You'll be able to go online once that's done."* (Not a button — the driver cannot fix this themselves; payouts are admin-managed.)
- *Documents expired / rejected* → link to Documents
- *Account suspended* → contact support

Right now the toggle would just fail silently.

### 6.4 Payout status — read-only
Replaces the removed Payment Methods frames. A simple read-only card in Earnings: whether payouts are set up, the last payout date and amount, and *"Managed by the office — contact support to change."*

### 6.5 Destination filter
Three fully working endpoints, **zero UI, no frame**. A driver sets a destination and gets offers heading that way — used at end of shift or heading home. The server already tracks uses-remaining per day and an expiry.

**Needed:** set / view / clear, showing *"2 of 2 uses left today"* and time remaining. **Best value-per-effort item in the whole app** — no design debt, no backend work.

### 6.6 Empty, loading, error & offline states — **all screens**
**None of the 40 frames has any of these.** Every list needs four states:
- **Loading** (skeleton preferred over a spinner)
- **Empty** — "No trips yet", "No offers right now", "No deductions this period"
- **Error** — with a Retry action
- **No connection** — a driver in a rural patch of the West Midlands will hit this daily

This is the **largest single gap by frame count** and the most visible in daily use.

### 6.7 Notifications — 3 types
`GET /me/notifications` is fully backed (890 system, 48 trip, 5 compliance live). All have deep links. The frame exists but should differentiate **trip**, **compliance** (document expiring — urgent) and **system**, and support swipe-to-dismiss + mark-all-read, which the API supports.

### 6.8 Help & Support
"Help & Support" is in the side nav with **no destination frame**. Support tickets are fully backed (create, list, reply). Needed: ticket list, new ticket, and a thread view.

### 6.9 SOS / emergency
A backed safety endpoint with no design. Needed: a trip-screen SOS affordance and a confirm step. Safety feature — worth doing properly.

### 6.10 Android background location
Android requires a **second, separate permission dialog** for background location, and a hard denial can't be re-prompted — the driver must be walked to OS settings. No frame anticipates either. Without background location the driver stops receiving offers when the app isn't foreground.

### 6.11 One-time safety notice
UK law: handheld phone use while driving is an offence (£200 + 6 points) **even when stationary at lights**, and a conviction feeds the council's "fit and proper person" test. A one-time "cradle your device" notice at first launch is cheap and in the operator's interest.

---

## 7. Verified reference values

Design to these — read from production 2026-08-27.

**Fares**

| Category | Base | Per mile | Per min | Minimum |
|---|---|---|---|---|
| Standard | £2.50 | £1.25 | £0.20 | £4.00 |
| Accessibility | £2.50 | £1.25 | £0.20 | £4.00 |
| XL | £3.50 | £1.75 | £0.30 | £6.00 |

**Commission: 20%** (not the 15% in the frame) · **Waiting: 3 free minutes, then £0.30/min** · **No-show: report after 5 minutes**

**Deductions:** Insurance Levy £0.45/ride · Late £3.00 · Low Rating £2.00 · Passenger Complaint £10.00

**Document statuses:** Pending review · Approved · Rejected · Expired
**Notification types:** trip · compliance · system
**Trip states:** requested → matching → assigned → accepted → arriving → started → completed *(or cancelled / failed)*

**Currency is GBP only. All money is whole pence** — please avoid designs implying sub-penny precision.

---

## 8. One standing request

**Please mark every number in a frame as either real or placeholder.**

Several of the corrections above exist because a plausible-looking figure was read downstream as a specification. "£442.60" in a frame looked like a requirement; it was illustrative. A simple visual convention — a tint, a `*`, a layer-name prefix — would prevent this entirely.

It matters most on the money and stats screens, where a wrong number isn't a cosmetic bug but a statement about someone's pay.

---

## 9. What we need back, in order

1. **2-stop versions** of the three trip frames *(blocks the ride flow — our first build target)*
2. **Trip frames with the call button removed** *(Phase 1 is chat-only)*
3. **Offer card redesign** with expiry countdown, no rider identity *(§4.4)*
4. **Cancel / no-show frames** *(safety — a driver is stuck today)*
5. **Empty / loading / error / offline states** *(§6.6)*
6. **4-tab bottom nav** re-cut across all frames, plus Earnings → Statement
7. **Blocked-from-online + presence states** *(§6.2, §6.3)*
8. Documents as a checklist with 4 status badges *(§4.6)*
9. Stats with "no data" states, appeals moved to Documents *(§4.5)*
10. Settings corrections *(§4.8)*
11. Destination filter *(§6.5 — small, high value)*

Items 1–3 unblock the first build phase. Everything else can follow in order.

Happy to walk through any of this together — several items are quicker to resolve in a 20-minute call than over a document.
