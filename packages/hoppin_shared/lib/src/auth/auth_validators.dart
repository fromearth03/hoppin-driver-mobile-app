/// Pure form validators shared by both apps. Kept free of Flutter imports so
/// they unit-test without a widget harness.
library;

final _emailRe = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

/// Returns an error message, or null when [value] looks like an email.
String? validateEmail(String? value) {
  final v = value?.trim() ?? '';
  if (v.isEmpty) return 'Enter your email';
  if (!_emailRe.hasMatch(v)) return 'Enter a valid email address';
  return null;
}

/// Returns an error message, or null when the password passes.
///
/// Sign-up enforces a minimum length; sign-in only requires presence — the
/// server is the judge of an existing password.
String? validatePassword(String? value, {bool forSignUp = false}) {
  final v = value ?? '';
  if (v.isEmpty) return 'Enter your password';
  if (forSignUp && v.length < 8) return 'Use at least 8 characters';
  return null;
}
