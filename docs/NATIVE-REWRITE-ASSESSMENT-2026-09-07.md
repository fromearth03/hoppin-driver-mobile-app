# Going native (Kotlin, then Swift) on RIBs — what it actually costs

Assessment requested 2026-09-07. Numbers are measured from this repo, not
estimated from feel. Research on RIBs is from the source repos and Uber's own
engineering writing, cited at the end.

**Short version: 5–8 months of full-time work to get back to where you are
today, with a realistic chance of never getting there. I recommend against it
in this form, and there is a cheaper route to the same goal at the bottom.**

---

## 1. What exists today, measured

| | Count |
|---|---|
| App code | **24,919 lines** Dart, 179 files |
| Test code | **12,417 lines**, 99 files |
| Golden (visual) tests | **53 images** |
| Features | **15** |
| Routes / screens | **25** |
| State controllers | **20** |
| API endpoints referenced | **377** |
| Native/plugin dependencies | **19** |

Per feature, largest first:

| Feature | LOC | Files |
|---|---|---|
| trip | 4,138 | 22 |
| home | 2,843 | 17 |
| onboarding | 2,095 | 11 |
| earnings | 2,030 | 15 |
| support | 1,640 | 6 |
| profile | 1,381 | 13 |
| stats | 1,347 | 11 |
| documents | 1,115 | 8 |
| auth | 987 | 7 |
| trips | 915 | 7 |
| statement | 905 | 8 |
| notifications | 559 | 4 |
| payment | 373 | 3 |
| gate | 277 | 4 |
| heatmap | 96 | 2 |
| `lib/shared` | 2,840 | — |
| `lib/core` | 1,022 | — |

**Team: one committer, 87 commits, five days of history.** That single fact
drives most of what follows.

---

## 2. The RIBs research, and the thing that matters most

### Android RIBs is alive. iOS RIBs is a different story.

- **Android** (`uber/RIBs`): current at **0.16.6**, actively committed, and it
  does have Jetpack Compose support. Fine.
- **iOS** (`uber/ribs-ios`): split into its own repo, at 1.0, and built on
  **UIKit + RxSwift 6**. Not SwiftUI. Not async/await.

That second line is the problem for the Swift plan. Writing a new iOS app in
2026 on UIKit and RxSwift means adopting two technologies the wider iOS world
has moved off. Your boss would be inheriting a codebase that is dated on
delivery, and hiring for RxSwift is harder every year.

### Uber still uses RIBs — correcting an earlier overstatement

A first pass of this assessment said Uber had "abandoned" RIBs. **That was
wrong**, and the correction is in Uber's favour, so it belongs here plainly.

What the Freight post actually says is that "many RIBs in the app's structure
grew too big and complex" and that it "became difficult to share and reuse
similar pieces of the UI and logic without refactoring major parts of the
app." Their response was **not** to replace RIBs. They built a
component-driven framework *on top of* it: "RIBs became a crucial piece in the
framework, and developers already familiar with RIBs could now use them as
ListView components."

The Android repo backs this up — v0.16.6 shipped within the last year, and
releases are regular. It is maintained, not abandoned.

**So the honest objection is not "RIBs is dead." It is a sizing argument.**

RIBs is explicitly built for "mobile apps with a large number of engineers and
nested states," and the published trade-off is that its complexity "pays off in
large teams and apps with deep navigation stacks." Uber's driver app had **40
teams working in parallel** — that is the problem RIBs solves, and it solves
it well.

**This repo has one committer.** The cost is paid up front and in full; the
benefit is proportional to the number of engineers who would otherwise collide,
and that number is one. Uber's own experience is also a warning at your scale:
if RIBs grew unwieldy for them *with* a platform team maintaining it, a solo
developer has no such backstop.

---

## 3. The estimate

Rates assume a competent native developer who already knows Kotlin. Add 30–40%
if they are learning RIBs at the same time, which is likely — the framework is
niche and the learning curve is steep.

### Phase A — Kotlin/Android on RIBs

| Work | Hours | Notes |
|---|---:|---|
| Learn RIBs properly (1 dev) | 60–100 | Router/Interactor/Builder, the DI graph, Rx or coroutine plumbing. Not optional; half-learned RIBs is worse than none |
| Project scaffold, DI, build, CI | 40–60 | Dagger graph, RIB tooling, code generation, signing, pipeline |
| Core: API client, auth, session, device id, error envelope | 80–120 | 377 endpoint references. The `Result`/`ApiException` contract has to be rebuilt exactly or every screen drifts |
| Design system: glass, ambience, cards, skeletons, toasts, buttons | 100–140 | The glass work alone took several iterations here; Compose will need its own |
| 15 features as RIBs | 600–900 | ~40–60h each averaged. `trip` alone is 4.1k lines with a live map, multi-stop, waiting timers, cancel policy |
| Native integrations (19 deps) | 120–180 | Maps, geolocation with background behaviour, FCM, image picker, permissions, Supabase auth, Stripe hand-off, MinIO multipart upload |
| Test suite rebuild | 200–300 | 12.4k lines of tests. Goldens do not port — 53 images to re-shoot and re-verify |
| Manual QA, device testing, fixing | 150–250 | This is where the blank-screen class of bug gets caught. Do not cut it |
| Store setup, release, rollout | 40–60 | |
| **Subtotal** | **1,390–2,110 h** | |

At 6 productive hours/day, one developer: **232–352 working days ≈ 11–17
months.** Two developers with real parallelism: **6–9 months**.

### Phase B — Swift/iOS on RIBs

| Work | Hours | Notes |
|---|---:|---|
| Learn RIBs-iOS + RxSwift | 80–120 | RxSwift is its own learning curve if the dev knows async/await |
| Everything above, ported | 900–1,400 | Business logic is understood by then, so it is faster than Android — but UIKit is more verbose than Compose, which claws much of it back |
| iOS-specific native work | 150–250 | Background location on iOS is materially harder than Android. Push, permissions, App Store review |
| Test suite | 150–250 | |
| **Subtotal** | **1,280–2,020 h** | |

**Roughly the same again.** RIBs' cross-platform claim is about *architectural
parity*, not shared code — you write everything twice.

### Total

| | One dev | Two devs |
|---|---|---|
| Android only | 11–17 months | 6–9 months |
| Android + iOS | 22–33 months | 11–17 months |

**Cost to reach exactly the feature set you have running today.** Zero new
capability. During this window the Flutter app must still be maintained, or
the business stops moving.

---

## 4. Where this goes wrong

Ranked by how likely they are to actually bite, based on what has already gone
wrong in this repo.

**1. Losing the invisible fixes.** This codebase carries dozens of hard-won
corrections that are invisible in a feature list: the `AppShell` Stack that
collapsed every screen to blank, `AsyncValue.when` blanking a screen on every
poll tick, the offer countdown racing under the driver's finger, the GPS beat
needing a warm stream, session-replaced recovery, the CORS device-header trap,
the MinIO upload path. **A rewrite reintroduces every one of these unless each
is deliberately carried over.** Nobody has ever done that completely.
Budget 3–6 weeks of bug tail per platform and expect to be wrong.

**2. Riverpod → RIBs is not a port, it is a redesign.** 20 controllers using
`AsyncValue` with a value-first render policy. RIBs has no equivalent; you
rebuild each as an Interactor with its own stream discipline. The
stale-while-revalidate behaviour that stops screens blanking has to be
re-derived from scratch.

**3. The test suite does not come with you.** 12.4k lines and 53 goldens are
Dart and Flutter-specific. All of it is rewritten. If it is not, you lose the
only safety net you have — and this project already shipped three broken APKs
in a row *with* that net, because a golden had recorded a bug as expected.

**4. RIBs on Compose is the road less travelled.** RIBs was designed around
imperative view attachment; Compose is declarative. The integration exists but
the community using it is small, so unusual problems will not have a Stack
Overflow answer waiting.

**5. iOS on UIKit + RxSwift ages badly.** Handing your boss a UIKit/RxSwift
codebase in 2026 is handing over technical debt on day one.

**6. Single-developer bus factor.** One person holds all context. Mid-rewrite,
that person leaving is close to fatal — there is no old app to fall back to
because it has stopped being maintained.

**7. Feature freeze.** Anything shipped in Flutter during the rewrite must be
built twice. In practice this either freezes the product for a year or the
rewrite never converges. This is the classic failure mode and it is the most
likely one here.

---

## 5. Review burden

You asked specifically about review time.

- **Code review:** ~25k lines of Kotlin, in unfamiliar architecture, at a
  realistic 300–500 lines/hour for meaningful review = **50–85 hours** per
  platform. Double it if the reviewer is also learning RIBs.
- **Functional review (yours):** every screen, every state, on real hardware.
  Based on the rounds we have just been through — 15 features × 3–4 rounds ×
  1–2 h = **45–120 hours** of your own testing, per platform.
- **Parity review:** proving the new app does everything the old one does.
  There is no document that lists it; it lives in the code. Writing that list
  is itself **20–40 hours**, and it is the only thing standing between you and
  silently shipping a regression.

---

## 6. What I would actually do

**Do not rewrite to reach parity. Rewrite only if you have a reason Flutter
cannot serve** — and right now the open items are a server-reachability bug, a
spacing issue, and glass polish. None of those are Flutter's fault, and none
are fixed by Kotlin.

Three routes, cheapest first:

### Option 1 — Stay on Flutter, harden it (recommended)
Cost: **0 extra.** iOS ships from the same codebase whenever your boss wants
it; that is the one thing you would be throwing away. The current app is one
verified bug away from solid.

### Option 2 — Kotlin/Compose without RIBs
If the goal is genuinely native Android, skip RIBs. Modern Android
(Compose + ViewModel + Hilt) does everything RIBs would here, with a hiring
pool and documentation that actually exist. **Saves 200–350 hours** and most
of the risk. Uber's own trajectory supports this.

### Option 3 — Native, staged, if it must happen
1. Ship iOS from Flutter first, so your boss has something in hand.
2. Rewrite **one** feature natively — `documents` (1,115 LOC, self-contained)
   is the right pilot. Measure how long it really takes.
3. Decide from that measurement, not from this estimate.

**The one question that settles it:** what can you not do in Flutter that you
could do in Kotlin? If there is a real answer — a native SDK, a performance
wall, a partner requirement — the rewrite may be justified and we should scope
it around *that*. If the answer is "native feels more serious," it is 22–33
months for a feeling.

---

## Sources

- [uber/RIBs (Android)](https://github.com/uber/RIBs) — 0.16.6, active, Compose extensions
- [uber/ribs-ios](https://github.com/uber/ribs-ios) — separate repo, UIKit + RxSwift 6
- [Architecting Uber's New Driver App in RIBs](https://www.uber.com/us/en/blog/driver-app-ribs-architecture/) — design intent, large-team framing
- [Building the New Uber Freight App as Lists of Modular, Reusable Components](https://www.uber.com/us/en/blog/uber-freight-app-architecture-design/) — RIBs kept, components layered on top
- [Review Uber/RIBs after 2 weeks of use](https://congnc-if.medium.com/uber-ribs-the-best-mobile-architecture-68bdb0a90750) — practitioner account of the learning curve
