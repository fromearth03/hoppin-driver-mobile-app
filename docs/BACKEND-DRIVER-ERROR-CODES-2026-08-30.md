# Driver app — error-code reference (A14)

**Service:** `Go_ride_service` (`:8080`). Answers Ask-1 §9.4, scoped to the codes a
**driver** can actually reach (not all 28 in the service).

Every error is the standard envelope: `{ "error": "<message>", "code": "<CODE>" }`
(the online-eligibility refusal adds `reason` + `blocking_document_types` — see below).
Map on **`code`**; the `error` string is for logs, not display.

**Retryable? key:** *No* = the same request will keep failing until the underlying
state changes (show the message, don't auto-retry). *Yes* = transient, safe to retry
with backoff. *Yes, later* = will succeed once a real-world condition is met.

---

## Global — reachable on any authenticated call
| Code | HTTP | Driver-facing meaning | Retryable? |
|---|---|---|---|
| `VALIDATION_FAILED` | 400 | The request was malformed or a field was invalid. | No — fix input |
| `INTERNAL` | 500 | Something went wrong on our side. | **Yes** (backoff) |
| `FORBIDDEN` | 403 | You don't have access to that resource. | No |
| `NOT_FOUND` / `RIDE_NOT_FOUND` | 404 | That ride/record no longer exists. | No |
| `ACCOUNT_SUSPENDED` | 403 | Your account is suspended. | No — contact support |
| `ACCOUNT_BANNED` | 403 | Your account is banned. | No — contact support |
| `DEVICE_BLACKLISTED` | 403 | This device has been blocked. | No — contact support |

---

## Going online — `POST /drivers/me/online`
**This is the answer to the sub-question: it can refuse THREE ways, not two.** The
one missing from Ask-1 is `NOT_ELIGIBLE`, and it carries a `reason` that is *richer*
than the A6 `blocked_reason` enum.

| Code | HTTP | Meaning | Retryable? |
|---|---|---|---|
| `NOT_ELIGIBLE` | 403 | Not cleared to go online — see `reason`. | Only once `reason` is resolved |
| `DEVICE_BLACKLISTED` | 403 | This device is blocked. | No — contact support |
| `PAYOUT_NOT_READY` | 403 | Finish payout setup (admin/ops) to start earning. | No — resolve first |

`NOT_ELIGIBLE` body: `{ "code":"NOT_ELIGIBLE", "reason":"<TOKEN>", "blocking_document_types":[...] }`
(`blocking_document_types` present only for the `DOCS_*` reasons). Full `reason` set:

| `reason` | Meaning | Screen action |
|---|---|---|
| `SUSPENDED` | Account suspended | Contact support |
| `RESTRICTED` | Account restricted by ops | Contact support |
| `DELETION_REQUESTED` | Account deletion is pending | Cancel deletion / contact support |
| `DOCS_MISSING` | A required document isn't uploaded | Upload the docs in `blocking_document_types` |
| `DOCS_PENDING_REVIEW` | A required doc is awaiting review | Wait — no action |
| `DOCS_REJECTED` | A required doc was rejected | Re-upload (`blocking_document_types`) |
| `DOCS_EXPIRED` | A required doc has expired | Re-upload (`blocking_document_types`) |
| `NO_VEHICLE` | No vehicle registered | Register a vehicle |
| `UNKNOWN` | Unspecified block | Generic "not cleared — contact support" |

> ✅ **A6 now matches.** `GET /drivers/me/status` was updated so its `blocked_reason`
> emits the **same tokens** (the `NOT_ELIGIBLE` reasons + `DEVICE_BLACKLISTED` +
> `PAYOUT_NOT_READY`) and the same `blocking_document_types` — so the Figma §6.3
> blocked-from-online screen keys off **one** vocabulary whether it learns the state
> from a status read or from an online refusal. (The old 3-value enum
> `suspended|document_expired|payout_not_ready` is gone — use these tokens.)

---

## Offers — `POST /offers/:id/accept` · `/decline`
| Code | HTTP | Meaning | Retryable? |
|---|---|---|---|
| `OFFER_EXPIRED` | 409 | This offer has lapsed. | No — wait for the next |
| `OFFER_NOT_FOUND` | 404 | This offer no longer exists. | No |

## Trip lifecycle — `PATCH /rides/:id/arrive` · `start` · `complete` · `cancel`
| Code | HTTP | Meaning | Retryable? |
|---|---|---|---|
| `ILLEGAL_TRANSITION` | 409 | The ride isn't in a state that allows this (e.g. start before arrive). | No — re-sync the ride |
| `NO_SHOW_TOO_EARLY` | 400 | Can't no-show the rider yet — the wait window hasn't passed. Body carries `seconds` remaining. | **Yes, after `seconds`** |

## Live map — `GET /rides/:id/driver-location` (+`/stream`)
| Code | HTTP | Meaning | Retryable? |
|---|---|---|---|
| `NO_DRIVER_ASSIGNED` | 409 | No driver on this ride yet. | Yes, later |
| `RIDE_NOT_ACTIVE` | 409 | The ride isn't active. | No |
| `POSITION_UNAVAILABLE` | 409 | No live position yet. | Yes, later |

## Profile / documents / account — `/me/*`, `/drivers/me/documents`, `/me/delete-account`
| Code | HTTP | Meaning | Retryable? |
|---|---|---|---|
| `STORAGE_DISABLED` | 503 | Uploads are temporarily unavailable. | Yes, later |
| `PHONE_TAKEN` | 409 | That phone number is already in use. | No — use another |
| `USER_NOT_FOUND` | 404 | Your profile couldn't be found. | No |
| `DELETION_BLOCKED` | 409 | Can't delete the account yet (active trip / balance / open issue). | No — resolve the blocker |

---

## NOT driver-reachable — don't write copy for these
These belong to rider-only endpoints (booking, estimate, scheduled rides, share links)
and a driver JWT can't hit them:

`NO_PAYMENT_METHOD` · `VEHICLE_CATEGORY_MISMATCH` · `NO_ZONE` · `NO_TARIFF` ·
`OUTSIDE_SERVICE_AREA` · `ACTIVE_TRIP_EXISTS` · `ACCOUNT_NOT_ELIGIBLE` ·
`IDEMPOTENT_REPLAY` · `SCHEDULED_RIDE_NOT_FOUND` · `SCHEDULED_RIDE_NOT_CANCELLABLE` ·
`SHARE_LINK_INVALID`

So the driver-reachable set is **~22 codes** (incl. the 9 `NOT_ELIGIBLE` reasons),
not the full service surface — write copy for the tables above, fall back to a generic
message for anything unlisted.
