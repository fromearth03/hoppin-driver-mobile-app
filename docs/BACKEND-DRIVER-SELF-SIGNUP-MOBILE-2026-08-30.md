# Backend — Driver self-registration (driver mobile app)

**Date:** 2026-08-30 · **Service:** `Go_ride_service` (`api.hoppin.tech`) + Supabase Auth. Live.

A driver can now **self-register in the driver app** and complete the same onboarding
the admin panel used to do — then they stay **restricted until an admin approves**.
All backend is done; this is the mobile contract.

---

## The flow (order matters)

### 1. Sign up (Supabase Auth, directly — same as rider)
Call `supabase.auth.signUp()` with a **`signup_role: 'driver'`** flag in user_metadata:
```dart
await supabase.auth.signUp(
  email: email, password: password,
  data: { 'signup_role': 'driver', 'full_name': name, 'phone': phone },
);
```
Backend (DB trigger) creates the driver **restricted by construction**:
`role='driver'`, `account_status='pending'`, `is_active_on_platform=false`.
> Use the key **`signup_role`**, NOT `role` — a `role` key is reserved for admin/invite
> flows and makes the trigger skip the user.

After email confirm + login, the driver's JWT carries `user_role='driver'`, so all the
`/drivers/me/*` endpoints below work while they're still pending.

> **Registration can be closed by an admin.** There's a kill-switch (Admin → Config →
> Driver Registration). When it's **off**, a `signup_role:'driver'` signup is created as a
> normal **rider** instead (never an orphan account). So after signup, **read the role**
> (`GET /me/profile` → `role`, or the `user_role` JWT claim): if it's `rider` when the user
> chose "become a driver", show *"driver registration is currently closed — contact support"*
> and route them into the rider experience. When it's `driver`, continue the onboarding below.
> (Read the role from the **`user_role`** top-level JWT claim on the Supabase access token —
> the same claim you already use for the rider/driver app split — not from `/me/profile`.)

### 2. Profile — `PATCH /me/profile`
`{ full_name, phone_number, date_of_birth }` (existing endpoint).

### 3. Licence — `PATCH /drivers/me/onboarding`  (NEW)
```jsonc
{ "license_number": "SMITH901234AB9CD", "address": "12 High St, Wolverhampton" }
-> 200 {"status":"updated"}   ·   409 {code:"LICENSE_TAKEN"} if already registered
```

### 4. Vehicle + compliance — `POST /drivers/me/vehicle`  (extended)
Now also accepts MOT / insurance / CAZ, which the admin compliance sweep reads:
```jsonc
{ "make":"Toyota","model":"Prius","license_plate":"WV21 ABC","color":"Grey","year":2021,
  "passenger_capacity":4,
  "insurance_provider":"Aviva","insurance_expiry":"2027-03-01",
  "mot_expiry":"2027-02-15","caz_compliant":true }
-> 200 · 409 {code:"PLATE_TAKEN"}
```

### 5. Credentials — `POST /drivers/me/credentials`  (NEW)  ·  `GET` to list
Badge / DBS / medical / right-to-work etc. — numbers + expiry. **The compliance sweep
reads these**, so they're required to become compliant. One row per type (upsert):
```jsonc
POST { "type":"wolverhampton_taxi_badge", "number":"WV-12345",
       "share_code":"AB12CD34", "is_temporary":false, "expires_at":"2028-01-31" }
-> 200 {"status":"saved","type":"..."}
```

### 6. Documents (upload files) — existing driver endpoints
`GET /document-types` (checklist) → `POST /drivers/me/documents/upload-url` (presigned PUT)
→ upload the file → `POST /drivers/me/documents` (confirm) → `GET /drivers/me/documents`
(status). Types: DVLA licence, taxi badge, right-to-work, MOT, insurance, V5C, CAZ.
Each lands `pending_review` until an admin approves/rejects (with a `rejection_reason`).

### 7. Payout (Stripe Connect) — existing
`POST /me/payout-account` → open the returned `onboarding_url` (Stripe hosted: bank + ID
entered on Stripe, never in the app) → `GET /me/payout-account` → `{payouts_enabled}`
flips true via webhook when done.

### 8. Wait for approval — `GET /drivers/me/onboarding`  (NEW)
Drives the onboarding checklist + the "under review" screen:
```jsonc
{ "status":"pending_approval",        // pending_approval | active | restricted | suspended
  "can_operate": false,               // is_active_on_platform && payouts_enabled
  "account_status":"pending",
  "steps": { "profile":true, "license":true, "vehicle":true, "vehicle_compliance":false,
             "payout":false, "credentials_count":2,
             "documents":{"approved":2,"pending":3,"rejected":0} },
  "documents":[ {"type":"mot_certificate","status":"pending_review","rejection_reason":""} ],
  "message":"Your application is under review — an admin will approve your account…" }
```
Poll this on the onboarding/home screen. When `status:"active"` (and `can_operate:true`),
enable "Go online".

---

## The restriction (what to expect while pending)
Until an admin runs **activate**, the driver is `is_active_on_platform=false`:
- `POST /drivers/me/online` → **403 `NOT_ELIGIBLE`** (or `PAYOUT_NOT_READY` if payout isn't
  set up). Accepting a ride is likewise blocked.
- `GET /drivers/me/status` returns the blocked reason (`DOCS_MISSING`, `DOCS_PENDING_REVIEW`,
  `NO_VEHICLE`, `not_compliant`, …) — surface these on the onboarding screen.
So keep the driver on the onboarding/"under review" flow until `GET /drivers/me/onboarding`
reports `status:"active"`.

## Mobile checklist
- Driver signup screen → `auth.signUp` with `signup_role:'driver'`.
- Onboarding wizard hitting steps 2–7, driven by `GET /drivers/me/onboarding`.
- "Under review" home state until `status:"active"`; then unlock Go-online.
- Reuse the existing document-upload + payout-onboarding widgets.

---

## (Backend note, no app change) — multi-stop price consistency
Multi-stop legs are now priced at **booking time** (which holds the rider's JWT →
corrected ETA) and copied verbatim at ride-creation, so the **estimate = quote = charge**.
Nothing changes in the app contract — `estimate`/`request` still just carry `waypoints`.
