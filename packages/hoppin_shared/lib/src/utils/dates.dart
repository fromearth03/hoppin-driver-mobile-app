/// Tiny date formatting helpers — deliberately dependency-free (no intl) until
/// localisation becomes a requirement. All render in the device's local time.
library;

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _two(int n) => n.toString().padLeft(2, '0');

/// `2026-07-05T17:42:00Z` → `5 Jul, 18:42` (local time).
String formatShortDateTime(DateTime dt) {
  final l = dt.toLocal();
  return '${l.day} ${_months[l.month - 1]}, ${_two(l.hour)}:${_two(l.minute)}';
}

/// `17:42` (local time).
String formatTime(DateTime dt) {
  final l = dt.toLocal();
  return '${_two(l.hour)}:${_two(l.minute)}';
}
