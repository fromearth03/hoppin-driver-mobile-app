import '../../../../core/money.dart';

/// What cancelling THIS ride, right now, would cost this driver.
///
/// 🔴 THE PICKER CANNOT ANSWER THIS. The fee-bearing events —
/// `rider_cancel`, `rider_mid_trip`, `driver_cancel` — are DERIVED from ride
/// state, so they are deliberately absent from `/cancellation-reasons`: they
/// are not things a driver picks. The result was that every option on screen
/// carried no fee and read as free, and the server then charged the derived
/// event anyway.
///
/// This is the server running its own cancel-path derivation without
/// cancelling, so the app can say what it will actually cost before anyone
/// commits.
class CancellationQuote {
  /// What cancelling would cost. Zero when [free].
  final Pence fee;

  final bool free;

  /// When the grace runs out, if there is one. Null means there is no clock —
  /// either it is free for reasons unrelated to time, or it is already
  /// chargeable.
  final DateTime? freeUntil;

  /// The fee-bearing event the server would fire. Empty when none would.
  /// Diagnostic: shown to nobody, useful in a bug report.
  final String event;

  /// One line, server-owned, shown verbatim. Never reworded here — it is the
  /// only part of this that explains the number to a driver, and the server
  /// is the thing that knows why.
  final String explain;

  const CancellationQuote({
    this.fee = const Pence(0),
    this.free = true,
    this.freeUntil,
    this.event = '',
    this.explain = '',
  });

  /// 🔴 THE FALLBACK IS DELIBERATELY FREE. A quote that could not be produced
  /// must never stop a driver cancelling, and must never invent a charge. The
  /// ride has to stay escapable even when this call fails — so a failure reads
  /// as free and silent, not as a fee and not as a blocked button.
  ///
  /// The service agrees: its handler answers 200 with exactly this shape when
  /// its own derivation errors, so this is belt-and-braces rather than the
  /// only guard.
  static const unknown = CancellationQuote();

  /// True only when there is a real charge to warn about.
  ///
  /// 🔴 `free: false` WITH NO AMOUNT READS AS FREE. The server can say "not
  /// free" while having no fee configured for the derived event; showing
  /// "you will be charged £0.00" is worse than saying nothing, and telling a
  /// driver they will be charged when we do not know the number is worse
  /// still.
  bool get charges => !free && fee.pence > 0;

  factory CancellationQuote.fromJson(Map<String, dynamic> json) =>
      CancellationQuote(
        fee: Pence((json['fee_pence'] as num?)?.toInt() ?? 0),
        // Absent reads as free: the safe direction. A missing field must not
        // manufacture a charge.
        free: json['free'] as bool? ?? true,
        freeUntil: switch (json['free_until']) {
          final String s => DateTime.tryParse(s),
          _ => null,
        },
        event: (json['event'] as String?) ?? '',
        explain: (json['explain'] as String?) ?? '',
      );

  /// Seconds left before cancelling starts costing, or null when there is no
  /// clock to show.
  ///
  /// Null rather than zero once it has run out: a countdown sitting at 00:00
  /// still reads as "free", and the driver would be charged.
  int? get freeSecondsRemaining {
    final until = freeUntil;
    if (until == null) return null;
    final left = until.toUtc().difference(DateTime.now().toUtc()).inSeconds;
    return left > 0 ? left : null;
  }
}
