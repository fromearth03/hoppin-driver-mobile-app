/// The operator's real contact details — `GET /api/v1/contacts`.
///
/// Admin-edited (`platform_contacts`) and read live, so a number change never
/// needs an app release. Public: the endpoint takes no JWT, which matters
/// because a rider in trouble may not be signed in.
///
/// 🔴 Every field is OPTIONAL and empty means ABSENT, not "0" or "unknown". The
/// server returns blanks rather than erroring when the row is missing, so a
/// caller must be able to tell "we have no phone number" from "here is an empty
/// one" — printing a blank contact row is exactly the dead end the help screen
/// was written to avoid.
class PlatformContacts {
  const PlatformContacts({
    this.supportEmail,
    this.supportPhone,
    this.emergencyPhone,
    this.whatsappNumber,
  });

  factory PlatformContacts.fromJson(Map<String, dynamic> json) {
    return PlatformContacts(
      supportEmail: _clean(json['support_email']),
      supportPhone: _clean(json['support_phone']),
      emergencyPhone: _clean(json['emergency_phone']),
      whatsappNumber: _clean(json['whatsapp_number']),
    );
  }

  /// Blank, whitespace-only and non-string values all collapse to null so a
  /// caller only has to check for null.
  static String? _clean(Object? raw) {
    if (raw is! String) return null;
    final t = raw.trim();
    return t.isEmpty ? null : t;
  }

  final String? supportEmail;
  final String? supportPhone;
  final String? emergencyPhone;
  final String? whatsappNumber;

  /// True when the operator has published nothing at all. The UI shows its
  /// honest "tickets only" copy in that case — the same sentence it used before
  /// this endpoint was wired.
  bool get isEmpty =>
      supportEmail == null &&
      supportPhone == null &&
      emergencyPhone == null &&
      whatsappNumber == null;

  bool get hasAny => !isEmpty;

  Map<String, dynamic> toJson() => {
        'support_email': supportEmail ?? '',
        'support_phone': supportPhone ?? '',
        'emergency_phone': emergencyPhone ?? '',
        'whatsapp_number': whatsappNumber ?? '',
      };

  @override
  bool operator ==(Object other) =>
      other is PlatformContacts &&
      other.supportEmail == supportEmail &&
      other.supportPhone == supportPhone &&
      other.emergencyPhone == emergencyPhone &&
      other.whatsappNumber == whatsappNumber;

  @override
  int get hashCode =>
      Object.hash(supportEmail, supportPhone, emergencyPhone, whatsappNumber);
}
