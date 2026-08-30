# Backend — Zones: discounts + zone-scoped promo codes

**Date:** 2026-08-30 · **Services:** `Go_ride_service`, dispatch, admin. All live.

Two new zone capabilities, plus zone-drawing safety rules. Admin UI is done (by us);
this covers the **mobile-facing** contract + the admin behaviour for reference.

---

## 1. Per-zone discount (automatic, mobile shows it for free)

An admin can set an automatic **% discount on any zone** (editable any time). It's
applied **inside the shared fare engine** — `gross × (1 − pct/100)`, before the
minimum-fare floor and before CAZ — so it flows to the **estimate, the charge, driver
earnings and the dispatch offer identically**. A ride is "in" a zone by its **pickup**.

- **Rider apps need no change**: the estimate + receipt totals already reflect the
  discount. If you want to *show* it, the pricing `Breakdown` (returned as `estimate`
  on `POST /rides/estimate`, and inside multi-stop legs) now carries:
  ```jsonc
  { "gross": 12.00, "discount_pct": 20, "discount": 2.40, "total": 9.60, … }
  ```
  So you can render "Zone discount −£2.40 (20%)" if desired. `discount_pct: 0` = none.
- The default (city-wide) zone can carry a discount too → applies everywhere in the
  service area.
- **Stacks with promo codes**: the zone discount is baked into the fare; a promo code
  is subtracted on top (as today).

---

## 2. Zone-scoped promo codes

A promo code can now be **scoped to a zone** (admin sets it; null = all zones /
everywhere). A scoped code only applies when the ride's **pickup** is inside that zone.

**New error on apply** — `POST /rides/:id/promo`:
```jsonc
400 { "code": "PROMO_WRONG_ZONE",
      "error": "this promo code isn't valid for your pickup area" }
```
Add this to your promo-error handling (alongside `PROMO_NOT_FOUND`, `PROMO_INACTIVE`,
`PROMO_EXHAUSTED`, `PROMO_USED`, `PROMO_MIN_RIDE`, …). Copy suggestion:
*"This code isn't available in your pickup area."*

- `GET /promotions/validate?code=` is unchanged (it has no pickup context); the
  authoritative zone check is at **apply** time, so a code may validate but return
  `PROMO_WRONG_ZONE` when applied to a ride outside its zone. Handle both.
- **Driver bonus** campaigns scoped to a zone only pay when the ride's pickup is in
  that zone (no app change — it's enforced server-side at settlement).

---

## Admin behaviour (reference — no app work)

- **Zones page (Pricing Setup):** a Zones list with a top **"Create new zone"** button;
  click a zone (or a tariff's zone) to **view/edit it on the map**. The zone editor has
  a **Discount %** field and shows **existing zones as a faint red overlay** so you can
  see where not to draw.
- **Drawing rules (enforced backend-side too):** a zone must be **one valid closed
  polygon** (no self-crossing lines), and **must not overlap** another zone —
  **only the city-wide default may overlap**. Invalid/overlapping saves are rejected
  with a clear message (edge-touching borders are allowed).
- **Promo form:** a **Zone** selector ("All zones" = everywhere).

---

## Summary for the mobile devs
1. Nothing required for the discount — totals already include it; optionally show the
   `discount`/`discount_pct` line from the estimate breakdown.
2. Add **`PROMO_WRONG_ZONE`** to the promo-apply error handling.
That's the whole app-facing surface; everything else is admin + server-side.
