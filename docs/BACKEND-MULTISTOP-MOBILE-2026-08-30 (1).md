# Backend — Multi-stop rides (mobile: rider + driver)

**Date:** 2026-08-30 · **Service:** `Go_ride_service` (`api.hoppin.tech`). Live.
Money is integer `*_pence`. All endpoints are JWT-authed (send the rider/driver token).

Multi-stop was **half-built + shipped disabled** (the app showed `MultiStopUnavailableNotice`,
seam **SL-11 = MISSING_BE**). It's now **fully wired backend-side** — you can retire that notice
and flip SL-11.

---

## The money model (what to tell the user)

A trip can pass through intermediate stops: **pickup → stop → stop → dropoff**.

- **Fare = Σ each leg's fare + Σ each stop's waiting.** Each leg is priced independently by
  the zone/vehicle engine — e.g. **£30 + £90 + £20 = £140**.
- **Platform commission, levy and every deduction apply exactly ONCE**, on the £140 grand
  total at settlement — **never per leg**. A 3-stop trip is never charged 3× commission.
- **Per-stop waiting:** the driver gets **3 min free per stop** (grace), then **25p/min**
  (configurable). Waiting is added to the total; the one-time deductions still apply once.

---

## 1. Estimate a multi-stop fare — `POST /rides/estimate`

Add a `waypoints` array (ordered intermediate stops) to the existing body. Omit it → the old
single-leg response is unchanged.

```jsonc
POST /rides/estimate
{ "pickup_lat":52.586, "pickup_lng":-2.128,
  "dropoff_lat":52.593, "dropoff_lng":-2.110,
  "vehicle_category_id":"<uuid or ''>",
  "waypoints":[ {"lat":52.580,"lng":-2.120,"label":"Tesco"},
                {"lat":52.578,"lng":-2.101,"label":"Mum's"} ] }
```
**Multi-stop response** (note `multi_stop:true`):
```jsonc
{ "multi_stop": true,
  "legs": [
    { "seq":0, "to_label":"Tesco",   "distance_meters":1400, "duration_seconds":300, "fare_pence":3000, "breakdown":{…} },
    { "seq":1, "to_label":"Mum's",   "distance_meters":6100, "duration_seconds":720, "fare_pence":9000, "breakdown":{…} },
    { "seq":2, "to_label":"Dropoff", "distance_meters":1800, "duration_seconds":360, "fare_pence":2000, "breakdown":{…} } ],
  "total_pence": 14000,          // Σ legs — the platform cuts hit ONCE on this at settlement
  "stops_count": 2,
  "distance_meters": 9300, "duration_seconds": 1380,
  "route": [ {lat,lng}, … ],     // whole-journey polyline (stitched legs) for the map
  "vehicle_category_id":"…", "cancellation_policy":{…} }
```
Show the per-leg lines (`legs[].fare_pence` with `to_label`) and the `total_pence`. Waiting is
**not** in the estimate (it's actual, added live during the trip) — surface it as "waiting may
apply at each stop".
Errors: `422 {code:"NO_ZONE"}` (a stop is outside every zone), `422 {code:"NO_TARIFF"}`.

## 2. Book with stops — `POST /rides/request`

Already accepts `waypoints` — just send it (it used to be silently dropped; the attach bug is
fixed). Fire-and-forget as today (returns `202 {request_id}`).
```jsonc
POST /rides/request
{ "pickup_lat","pickup_lng","dropoff_lat","dropoff_lng","vehicle_category_id",
  "waypoints":[ {"lat","lng","label"}, … ] }   // ≤ 5 stops
```
The backend prices every leg on ride creation and holds the **full multi-stop total** on the
card at accept — the driver's offer already shows the summed fare.

## 3. Read the live breakdown — `GET /rides/:id/stops`

Both rider and driver on the ride. Empty (`multi_stop:false`) for a normal single-stop ride.
```jsonc
{ "multi_stop": true,
  "stops": [
    { "seq":0, "kind":"stop", "label":"Tesco", "to_lat","to_lng",
      "distance_meters":1400, "duration_seconds":300, "fare_pence":3000,
      "waiting_seconds":240, "waiting_pence":25,       // 4 min waited, 1 min charged
      "arrived_at":"…", "departed_at":"…", "added_mid_trip":false },
    … { "seq":2, "kind":"dropoff", … "waiting_pence":0 } ],
  "legs_total_pence":14000, "waiting_total_pence":25, "total_pence":14025 }
```

## 4. Add a stop mid-trip — `POST /rides/:id/stops`  (RIDER or DRIVER)

While the ride is live. Re-prices every leg and returns the new total; both parties get a push
("Stop added"). New stop is inserted as the last intermediate stop (before the dropoff).
```jsonc
POST /rides/:id/stops { "lat":52.577, "lng":-2.099, "label":"Pharmacy" }
-> 200 { "total_pence":16500, "stops_count":3 }
-> 409 {code:"RIDE_CLOSED"} if the ride already finished
```

## 5. Per-stop waiting — DRIVER app  (`PATCH /rides/:id/stops/:seq/{arrive,depart}`)

When the driver reaches a stop, call **arrive**; when they leave, call **depart**. Depart
returns the wait charged at that stop (0 within the 3-min grace).
```jsonc
PATCH /rides/:id/stops/0/arrive  -> 200 { "status":"arrived", "seq":0 }
PATCH /rides/:id/stops/0/depart  -> 200 { "status":"departed", "seq":0, "waiting_pence":25 }
```
`seq` is the leg index whose destination is that stop (from `GET /rides/:id/stops`, `kind:"stop"`).
The dropoff leg has no waiting.

## 6. Receipt / settlement

At completion the rider is charged **Σ legs + Σ waiting**, and the receipt total reflects it.
The full per-leg breakdown stays available at `GET /rides/:id/stops`. Commission/levy/deductions
are already applied once on the total (visible to ops, not the rider).

---

## Mobile checklist
- **Rider app:** add the stop-entry UI (pickup, + Add stop ×N up to 5, dropoff); send `waypoints`
  to `estimate` + `request` (`rides_repository.dart`); show the per-leg breakdown + total; retire
  `MultiStopUnavailableNotice`; flip **SL-11 → LIVE** in `seam_registry.dart`.
- **Rider app (in-trip):** allow "Add stop" → `POST /rides/:id/stops`; show updated fare.
- **Driver app:** show the stop list + per-leg fares (`GET /rides/:id/stops`); at each stop call
  `arrive` then `depart`; show the running waiting charge.
- Copy to reuse: "Stops are priced per leg and added up. Fees are charged once on the total."
