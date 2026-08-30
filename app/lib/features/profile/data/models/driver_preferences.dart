/// App preferences.
///
/// `/me/preferences` stores an opaque JSON blob shared with the rider app,
/// so [unknown] carries anything this app does not recognise straight back
/// on save. Dropping it would wipe settings we know nothing about.
///
/// The server owns a strict key whitelist and rejects the whole patch if it
/// sees anything else, so the field names here are its names. A setting that
/// describes the handset rather than the account has no home on this
/// endpoint and does not belong in this model.
class DriverPreferences {
  /// Offers and trip updates. The one toggle a working driver actually
  /// depends on, so it defaults on.
  final bool notificationsEnabled;
  final bool rideRequestSound;
  final bool pushPromotions;
  final bool pushPayouts;
  final bool emailReceipts;
  final bool smsTripUpdates;
  final Map<String, dynamic> unknown;

  const DriverPreferences({
    this.notificationsEnabled = true,
    this.rideRequestSound = true,
    this.pushPromotions = true,
    this.pushPayouts = true,
    this.emailReceipts = true,
    this.smsTripUpdates = false,
    this.unknown = const {},
  });

  /// The whitelisted keys this app owns. Everything else on the row belongs
  /// to another client and rides along untouched in [unknown].
  static const _known = {
    'push_trip_updates',
    'sound_offer_chime',
    'push_promotions',
    'push_payouts',
    'email_receipts',
    'sms_trip_updates',
  };

  DriverPreferences copyWith({
    bool? notificationsEnabled,
    bool? rideRequestSound,
    bool? pushPromotions,
    bool? pushPayouts,
    bool? emailReceipts,
    bool? smsTripUpdates,
  }) =>
      DriverPreferences(
        notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
        rideRequestSound: rideRequestSound ?? this.rideRequestSound,
        pushPromotions: pushPromotions ?? this.pushPromotions,
        pushPayouts: pushPayouts ?? this.pushPayouts,
        emailReceipts: emailReceipts ?? this.emailReceipts,
        smsTripUpdates: smsTripUpdates ?? this.smsTripUpdates,
        unknown: unknown,
      );

  factory DriverPreferences.fromJson(Map<String, dynamic> json) =>
      DriverPreferences(
        notificationsEnabled: json['push_trip_updates'] as bool? ?? true,
        rideRequestSound: json['sound_offer_chime'] as bool? ?? true,
        pushPromotions: json['push_promotions'] as bool? ?? true,
        pushPayouts: json['push_payouts'] as bool? ?? true,
        emailReceipts: json['email_receipts'] as bool? ?? true,
        smsTripUpdates: json['sms_trip_updates'] as bool? ?? false,
        unknown: {
          for (final e in json.entries)
            if (!_known.contains(e.key)) e.key: e.value,
        },
      );

  /// The patch to send. Only whitelisted keys: an unknown one makes the
  /// server reject the entire request, losing the real settings with it.
  Map<String, dynamic> toJson() => {
        ...unknown,
        'push_trip_updates': notificationsEnabled,
        'sound_offer_chime': rideRequestSound,
        'push_promotions': pushPromotions,
        'push_payouts': pushPayouts,
        'email_receipts': emailReceipts,
        'sms_trip_updates': smsTripUpdates,
      };
}
