import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The incoming-offer chime (DRIVER-02) — a short rising "da-ding" played at
/// the offer takeover's entrance.
///
/// Chrome gesture unlock: browsers refuse audio until the user has clicked
/// the page, and ANY prior click unlocks HTMLMediaElement for the whole
/// session. The driver's Sign in tap is that click — [prime] runs there,
/// creating the lazy player and loading the source (a silent operation) so
/// the first real [play] is both allowed and instant. This is mode-blind
/// product behavior: a live driver wants offer audio armed after login too.
///
/// EVERY call is try/catch-swallowed (catch-all, not just Exception —
/// plugin errors vary by platform): in tests and on platforms with no audio
/// plugin the calls complete quietly, and when playback is blocked the
/// takeover's visual entrance carries the beat alone.
class OfferChime {
  AudioPlayer? _player;

  /// Creates the lazy player and loads the chime source. Safe anywhere,
  /// cheap to repeat; never throws.
  Future<void> prime() async {
    try {
      final player = _player ??= AudioPlayer();
      // Await creation FIRST: on a plugin-less platform the constructor's
      // async setup fails, and calling any player method after that leaks
      // an unhandled async error — surfacing the failure here keeps it
      // inside this catch instead. creatingCompleter is the plugin's only
      // public creation-completion surface, hence the lint suppression.
      // ignore: invalid_use_of_visible_for_testing_member
      await player.creatingCompleter.future;
      await player.setSource(AssetSource('audio/offer_chime.wav'));
      await player.setVolume(1);
    } catch (_) {
      // No audio on this platform (or the load was refused) — quiet no-op.
    }
  }

  /// Plays the chime from the top; primes first if needed. Never throws.
  Future<void> play() async {
    try {
      if (_player == null) await prime();
      final player = _player;
      if (player == null) return;
      // Same creation gate as [prime] — see the comment there.
      // ignore: invalid_use_of_visible_for_testing_member
      await player.creatingCompleter.future;
      await player.seek(Duration.zero);
      await player.resume();
    } catch (_) {
      // Audio blocked — the visual offer entrance carries the beat.
    }
  }
}

/// App-level chime service. Widget tests override this with a recording
/// fake; production and demo share the real one (the seam is the provider,
/// never a mode branch).
final offerChimeProvider = Provider<OfferChime>((_) => OfferChime());
