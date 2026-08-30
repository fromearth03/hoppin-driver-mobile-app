import '../../../../core/money.dart';

/// One movement on the driver's account.
///
/// `displayTitle` and `displayReason` are written by the server and rendered
/// verbatim. They are correctable by a backend release rather than an app
/// release, and they deliberately make no VAT or deduction claim — which is
/// exactly why the app must never compose its own copy from `entryType`.
class LedgerEntry {
  final String id;
  final DateTime createdAt;
  final Pence amount;
  final String entryType;
  final String displayTitle;
  final String? displayReason;
  final String? rideId;
  final Pence runningBalance;

  const LedgerEntry({
    required this.id,
    required this.createdAt,
    required this.amount,
    required this.entryType,
    required this.displayTitle,
    required this.runningBalance,
    this.displayReason,
    this.rideId,
  });

  bool get isCredit => amount.pence > 0;

  factory LedgerEntry.fromJson(Map<String, dynamic> json) => LedgerEntry(
        id: json['id'] as String,
        createdAt: DateTime.tryParse((json['created_at'] as String?) ?? '') ??
            DateTime.now(),
        amount: Pence((json['amount_pence'] as num?)?.toInt() ?? 0),
        entryType: (json['entry_type'] as String?) ?? '',
        displayTitle: (json['display_title'] as String?) ?? 'Adjustment',
        displayReason: json['display_reason'] as String?,
        rideId: json['ride_id'] as String?,
        runningBalance:
            Pence((json['running_balance_pence'] as num?)?.toInt() ?? 0),
      );
}

class LedgerPage {
  final Pence balance;
  final String currency;
  final List<LedgerEntry> entries;
  final String? nextCursor;

  const LedgerPage({
    required this.balance,
    required this.entries,
    this.currency = 'GBP',
    this.nextCursor,
  });

  factory LedgerPage.fromJson(Map<String, dynamic> json) => LedgerPage(
        balance: Pence((json['balance_pence'] as num?)?.toInt() ?? 0),
        currency: (json['currency'] as String?) ?? 'GBP',
        entries: ((json['entries'] as List?) ?? const [])
            .map((e) =>
                LedgerEntry.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        nextCursor: json['next_cursor'] as String?,
      );
}
