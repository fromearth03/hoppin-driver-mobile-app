import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/driver_preferences.dart';
import '../data/models/driver_profile.dart';
import '../data/preferences_repository.dart';
import '../data/profile_repository.dart';

final profileProvider = FutureProvider<DriverProfile?>((ref) async {
  final result = await ref.watch(profileRepositoryProvider).me();
  return result.valueOrNull;
});

class PreferencesController extends AsyncNotifier<DriverPreferences> {
  bool _disposed = false;

  @override
  Future<DriverPreferences> build() async {
    ref.onDispose(() => _disposed = true);
    final result = await ref.read(preferencesRepositoryProvider).load();
    return result.valueOrNull ?? const DriverPreferences();
  }

  /// Saves on every change rather than behind a Save button — a settings
  /// screen the driver leaves without saving is a screen that silently
  /// discarded their choice.
  ///
  /// Named `apply` rather than `update`, which `AsyncNotifier` already
  /// defines with an incompatible signature.
  Future<void> apply(DriverPreferences next) async {
    if (_disposed) return;
    state = AsyncData(next);
    await ref.read(preferencesRepositoryProvider).save(next);
  }
}

final preferencesControllerProvider =
    AsyncNotifierProvider<PreferencesController, DriverPreferences>(
        PreferencesController.new);
