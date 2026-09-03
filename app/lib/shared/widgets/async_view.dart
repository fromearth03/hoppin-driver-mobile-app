import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Renders an [AsyncValue] the way a driver app should: **the last good answer
/// stays on screen while the next one is fetched.**
///
/// 🔴 WHY `.when` IS THE WRONG DEFAULT HERE. `AsyncValue.when` routes on the
/// CURRENT state, so a refresh over data the app already holds takes the
/// `loading` branch and the screen blanks to a spinner — throwing away
/// content that is still perfectly good and, on a slow connection, leaving
/// the driver looking at nothing for seconds at a time. Worse, Riverpod
/// delivers a FAILED future as `AsyncLoading` carrying the error, so a
/// loading-first ladder shows a spinner that never resolves: the call died
/// and the driver is never told.
///
/// This asks in the order that keeps the most on screen:
///
///  1. **Any value we hold** — including a stale one mid-refresh. Wrapped so
///     the caller can dim it or show a bar while [isRefreshing].
///  2. **An error with no value** — a real failure with nothing to fall back
///     on, so it is shown.
///  3. **Nothing at all** — the genuine cold start, and the only case that
///     earns a placeholder.
///
/// The result is that a tab change, a poll tick and a pull-to-refresh never
/// blank a screen that already had content.
class AsyncView<T> extends StatelessWidget {
  const AsyncView({
    super.key,
    required this.value,
    required this.data,
    required this.loading,
    this.error,
  });

  final AsyncValue<T> value;

  /// Builds the content. [isRefreshing] is true when this is a stale value
  /// being replaced — use it for a subtle cue, never to hide the content.
  final Widget Function(T value, bool isRefreshing) data;

  /// The COLD-START placeholder only: no value has ever arrived. Prefer a
  /// skeleton of the real layout over a spinner.
  final Widget Function() loading;

  /// A failure with no value to fall back on. Omit to render [loading]
  /// instead, which suits a screen whose own body already shows errors.
  final Widget Function(Object error, StackTrace? stack)? error;

  @override
  Widget build(BuildContext context) {
    // Value first, deliberately — see the class note.
    if (value.hasValue) {
      return data(value.requireValue, value.isLoading || value.isRefreshing);
    }
    if (value.hasError) {
      final build = error;
      if (build != null) return build(value.error!, value.stackTrace);
    }
    return loading();
  }
}

/// The same ordering for a caller that wants the parts rather than a widget.
extension AsyncPreferValue<T> on AsyncValue<T> {
  /// The value we hold, stale or fresh, or null on a true cold start.
  T? get heldValue => hasValue ? requireValue : null;

  /// A failure the screen must show because there is nothing else to show.
  /// A failure ON TOP of a held value is not this: that is a refresh which
  /// did not land, and the content stays.
  Object? get blockingError => hasValue ? null : error;

  /// True while a value we already hold is being replaced.
  bool get isRefreshingHeld => hasValue && (isLoading || isRefreshing);
}
