# hoppin_ui

Hoppin design system — tokens, type scale, colour system, ThemeExtensions,
and brand components. Pure presentation; light and dark both first-class.

## Layout (Phases 3/4 slot into this — do not reorganize)

```
lib/src/
  tokens/
    primitives.dart   raw palette — PRIVATE, never exported or imported by apps
    semantic.dart     (app, brightness) -> semantic scheme; exports HoppinApp only
    spacing.dart      HoppinSpacing / HoppinRadii statics
  theme/
    hoppin_colors.dart      HoppinColors ThemeExtension (copyWith + lerp)
    hoppin_motion.dart      HoppinMotion ThemeExtension (durations + curves)
    hoppin_typography.dart  HoppinType — Geist scale + GeistMono numerals
    theme_builders.dart     HoppinTheme.riderLight/riderDark/driverLight/driverDark
    context_extension.dart  context.hoppin.colors/.motion/.spacing/.radii/.type
  components/         brand components — static ones land in 05-02
  gallery/            dev gallery — 05-02
assets/fonts/         Geist + Geist Mono variable TTFs (OFL, tnum-proven by test)
```

## Ownership contract (FIXED — from the Phase 5 context)

- **Phase 3** builds `GoButton`, `CountdownRing`, `SlideToConfirm`,
  `MoneyTicker` into `src/components/`.
- **Phase 4** builds `RouteStrip`, `RadarPulse` into `src/components/`.
- Phase 5 wave 1 (05-01/05-02) must NOT build those six animated primitives.

## House rules

- **Pure presentation** (riblet rule): state in, events out. No riverpod, no
  repositories, no hoppin_shared/hoppin_demo imports, no direct wall-clock
  reads — time enters via `clock.now()` (package:clock) so tests and the
  demo control it. Dependency surface = Flutter SDK + package:clock + the
  map presentation stack (flutter_map, latlong2, flutter_map_animations —
  HopMap only; amended for Phase 6). Spirit preserved: still zero
  riverpod/repository/hoppin_shared/hoppin_demo imports, no wall-clock
  reads. No other file in the monorepo may import the map packages (the
  Phase 6 gate greps for it), and no map-package type leaks into HopMap's
  public API — the tile-provider/engine swap stays a one-seam change.
- **Every animation duration comes from `HoppinMotion` tokens** — no inline
  `Duration` literals in animation code (05-03 enforces with a sweep).
- **Cheap motion only:** transform + paint-alpha; no `Opacity` widget in
  animations; `RepaintBoundary` around every looping animator.
- **Glass ONLY via `HopGlass`.** Never a raw `BackdropFilter` in app code or in
  another component — `HopGlass` is the one place the material is defined, and
  `motion_guards_test` enforces that by filename (it bans `BackdropFilter` /
  `ImageFilter.blur` / `MaskFilter` in every file under `lib/` except
  `hop_glass.dart`). Two hand-rolled blurs drift apart and start reading as two
  different materials; an unbounded number of them is a frame budget nobody is
  counting. If a surface needs frosted glass, it COMPOSES `HopGlass` — it does
  not open a second blur site.
  - The blur only works if something is painted BEHIND it. Chrome must be
    LAYERED over content (a `Stack`, or `extendBody`/`extendBodyBehindAppBar`),
    never stacked above it in a `Column` — a blur with nothing to sample
    degrades silently into a tinted box that photographs perfectly. See
    `RiderShell`.
  - A surface picks a `HopGlassTier` (a DUTY), never an alpha. `chrome` (72%)
    carries titles and icons; `sheet` (86%) carries body copy and needs the
    denser fill to clear the WCAG floor. Both alphas are pinned by measured
    worst-case contrast in `tokens/semantic_test` — do not re-tune by eye.
  - The sigma is a token constant and **never animates** (an animated sigma
    re-rasterises the backdrop every frame). Keep the region bounded; never
    full-screen.
  - Blur is composed with a saturation matrix (`HoppinChrome.saturation`),
    because a Gaussian blur averages colour toward grey and un-compensated
    frost reads muddy. Both halves live in the primitive.
  - _Web caveat withdrawn (2026-07-16): web is dropped, both apps target
    iOS + Android. The old Skia-divergence-above-sigma-7 and
    blur-doesn't-cross-platform-views constraints no longer apply; the map is
    `flutter_map` (pure Dart, no platform view), so glass composites over it
    correctly. Native-appropriate sigma (~15–22) is fine._
- **Consume tokens via `context.hoppin`** (`.colors`, `.motion`, `.spacing`,
  `.radii`, `.type`) — never raw hex, never `HoppinPrimitives`.
- **ColorScheme is hand-built** — never `ColorScheme.fromSeed` (it re-tones
  the brand hex). Rider light primary must stay exactly `#14523F`.
- **Elevation 0 everywhere**; hierarchy is hairline-border-first. The one
  ambient veil under modal sheets is drawn by HopSheet itself (05-02) — a
  static `BoxShadow` beneath the sheet, outside its glass clip. (The sheet's
  SURFACE is frosted `HopGlass` at the `sheet` tier; the veil is the cast
  underneath it, not the material.)
- Dark surfaces are warm near-blacks (`#0E0E0D` canvas) — never pure `#000`;
  dark text-hi is never pure `#FFF`.
- Every numeral uses a `HoppinType` GeistMono style (tabular figures);
  ledgers add slashed zero.
- **Add every new public file to the barrel** (`lib/hoppin_ui.dart`).

## Theming an app

```dart
MaterialApp(
  theme: HoppinTheme.riderLight(),
  darkTheme: HoppinTheme.riderDark(),
  // driver app: HoppinTheme.driverLight() / HoppinTheme.driverDark()
);
```
