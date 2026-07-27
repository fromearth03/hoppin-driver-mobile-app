/// Money formatting. Platform convention (docs/04): amounts are **pounds** as
/// numbers unless the field name ends in `_pence` — receipts and transactions
/// are integer pence. All GBP.
library;

/// `12.5` → `£12.50`
String formatPounds(num pounds) => '£${pounds.toStringAsFixed(2)}';

/// `900` → `£9.00`
String formatPence(int pence) => formatPounds(pence / 100);
