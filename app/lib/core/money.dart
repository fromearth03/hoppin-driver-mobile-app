/// Integer pence. The backend sends `*_pence` as int64 everywhere except
/// `/drivers/me/wallet`, which predates the convention and sends float
/// pounds — use [Pence.fromPounds] at that boundary and nowhere else.
///
/// Money never travels as a double inside the app.
class Pence {
  final int pence;
  const Pence(this.pence);

  /// Converts float pounds to integer pence, rounding half away from zero.
  /// Rounding (not truncation) is what keeps 0.1 + 0.2 from becoming 29p.
  factory Pence.fromPounds(double pounds) => Pence((pounds * 100).round());

  bool get isNegative => pence < 0;
  bool get isZero => pence == 0;

  /// "£8.30", or "−£50.00" when negative. Uses U+2212 MINUS SIGN rather
  /// than a hyphen so a debt reads as a number, not a list dash.
  String format() {
    final abs = pence.abs();
    final body = '£${abs ~/ 100}.${(abs % 100).toString().padLeft(2, '0')}';
    return pence < 0 ? '−$body' : body;
  }

  /// Same, but positives carry an explicit '+'. For ledger and trip rows
  /// where the direction of the movement is the point.
  String formatSigned() {
    if (pence == 0) return format();
    return pence > 0 ? '+${format()}' : format();
  }

  Pence operator +(Pence other) => Pence(pence + other.pence);
  Pence operator -(Pence other) => Pence(pence - other.pence);

  @override
  bool operator ==(Object other) => other is Pence && other.pence == pence;

  @override
  int get hashCode => pence.hashCode;

  @override
  String toString() => 'Pence($pence)';
}
