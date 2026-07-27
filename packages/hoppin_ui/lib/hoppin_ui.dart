/// Hoppin design system — tokens, type scale, colour system, ThemeExtensions,
/// and brand components. Light and dark are both first-class.
///
/// This is a PURE PRESENTATION package (riblet rule): state in, events out.
/// No riverpod, no repositories, no hoppin_shared/hoppin_demo imports, no
/// direct wall-clock reads — time enters through package:clock so tests and
/// the demo control it. The dependency surface is the Flutter SDK plus
/// package:clock plus the map presentation stack (maplibre_gl —
/// imported by HopMap ONLY; Phase 6 amendment, see README house rules).
///
/// Ownership contract for `src/components/` (fixed by the Phase 5 context):
/// - Phase 3 adds `go_button`, `countdown_ring`, `slide_to_confirm`,
///   `money_ticker`.
/// - Phase 4 adds `route_strip`, `radar_pulse`.
/// - Phase 5 wave 1 (05-01/05-02) must NOT build those six animated
///   primitives; 05-02 lands the static brand components and the gallery.
library;

export 'src/components/countdown_ring.dart';
export 'src/components/fare_estimate_card.dart';
export 'src/components/go_button.dart';
export 'src/components/hop_avatar.dart';
export 'src/components/hop_avatar_editor.dart';
export 'src/components/hop_launch_block.dart';
export 'src/components/hop_banner.dart';
export 'src/components/hop_bottom_nav.dart';
export 'src/components/hop_button.dart';
export 'src/components/hop_empty_state.dart';
export 'src/components/hop_card.dart';
export 'src/components/hop_glass.dart';
export 'src/components/hop_glass_press.dart';
export 'src/components/hop_list_row.dart';
export 'src/components/hop_map.dart';
export 'src/components/hop_map_models.dart';
export 'src/components/hop_popup.dart';
export 'src/components/hop_sheet.dart';
export 'src/components/hop_top_bar.dart';
export 'src/components/location_field.dart';
export 'src/components/otp_input.dart';
export 'src/components/money_ticker.dart';
export 'src/components/plate_chip.dart';
export 'src/components/radar_pulse.dart';
export 'src/components/ride_type_card.dart';
export 'src/components/route_strip.dart';
export 'src/components/slide_to_confirm.dart';
export 'src/components/status_pill.dart';
export 'src/gallery/hoppin_gallery.dart';
export 'src/theme/context_extension.dart';
export 'src/theme/hoppin_colors.dart';
export 'src/theme/hoppin_motion.dart';
export 'src/theme/hoppin_typography.dart';
export 'src/theme/theme_builders.dart';
// Primitives stay private; the semantic resolver is internal to the theme
// builders — only the app selector is public.
export 'src/tokens/semantic.dart' show HoppinApp;
export 'src/tokens/spacing.dart';
