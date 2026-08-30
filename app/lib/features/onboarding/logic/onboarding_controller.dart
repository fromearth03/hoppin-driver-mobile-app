import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../data/models/onboarding_status.dart';
import '../data/onboarding_repository.dart';

class OnboardingState {
  final DriverOnboarding? onboarding;
  final bool isBusy;
  final ApiException? error;

  const OnboardingState({this.onboarding, this.isBusy = false, this.error});

  OnboardingState copyWith({
    DriverOnboarding? onboarding,
    bool? isBusy,
    ApiException? error,
    bool clearError = false,
  }) =>
      OnboardingState(
        onboarding: onboarding ?? this.onboarding,
        isBusy: isBusy ?? this.isBusy,
        error: clearError ? null : (error ?? this.error),
      );
}

/// Approval happens in the admin panel with nothing pushed to the app, so the
/// review screen has to ask. Slow on purpose: a human approves these, and a
/// driver waiting on one is not helped by a faster spinner.
final onboardingPollIntervalProvider =
    Provider<Duration>((ref) => const Duration(seconds: 30));

class OnboardingController extends AsyncNotifier<OnboardingState> {
  Timer? _timer;
  bool _disposed = false;

  OnboardingRepository get _repo => ref.read(onboardingRepositoryProvider);

  @override
  Future<OnboardingState> build() async {
    ref.onDispose(() {
      _disposed = true;
      _timer?.cancel();
    });

    final result = await _repo.status();
    final loaded = result.when(
      ok: (o) => OnboardingState(onboarding: o),
      err: (e) => OnboardingState(error: e),
    );
    // An approved driver has nothing left to wait for.
    if (!(loaded.onboarding?.isActive ?? false)) _startPolling();
    return loaded;
  }

  OnboardingState get _current => state.value ?? const OnboardingState();

  void _emit(OnboardingState next) {
    if (_disposed) return;
    state = AsyncData(next);
  }

  void _startPolling() {
    _timer?.cancel();
    _timer = Timer.periodic(ref.read(onboardingPollIntervalProvider), (_) {
      if (_current.onboarding?.isActive ?? false) {
        _timer?.cancel();
        return;
      }
      refresh();
    });
  }

  Future<void> refresh() async {
    if (_disposed) return;
    final result = await _repo.status();
    if (_disposed) return;
    result.when(
      ok: (o) {
        _emit(_current.copyWith(onboarding: o, clearError: true));
        if (o.isActive) _timer?.cancel();
      },
      // Keep the last good checklist on screen: a dropped poll is not news
      // worth replacing the driver's progress with an error.
      err: (e) => _emit(_current.copyWith(error: e)),
    );
  }
}

final onboardingControllerProvider =
    AsyncNotifierProvider<OnboardingController, OnboardingState>(
        OnboardingController.new);
