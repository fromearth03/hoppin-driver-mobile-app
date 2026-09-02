import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Whether an in-app alert buzzes and chimes.
///
/// Local rather than part of `/me/preferences`: this is a property of the
/// handset in the cradle, not of the driver's account. The same person on a
/// second phone should not inherit a choice they made about the first, and
/// the toast has to know the answer instantly — a server round trip would
/// mean the first alert of every session guesses.
///
/// Defaults to on. A driver who misses a penalty because their phone stayed
/// silent is worse off than one who is mildly annoyed by a buzz, and the
/// switch is one tap away in Settings.
class NotificationHaptics extends Notifier<bool> {
  static const _key = 'notification_haptics';

  @override
  bool build() => true;

  /// Reads the stored choice. Safe to call more than once.
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      state = prefs.getBool(_key) ?? true;
    } catch (_) {
      // No preference store on this platform — the default stands.
    }
  }

  Future<void> set(bool value) async {
    state = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key, value);
    } catch (_) {
      // The toggle still holds for this session; it simply will not persist.
    }
  }
}

final notificationHapticsProvider =
    NotifierProvider<NotificationHaptics, bool>(NotificationHaptics.new);
