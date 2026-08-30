enum DistanceUnit { miles, kilometres }

enum NavApp { google, apple }

/// App preferences.
///
/// `/me/preferences` stores an opaque JSON blob shared with other clients,
/// so [unknown] carries anything this app does not recognise straight back
/// on save. Dropping it would wipe settings we know nothing about.
class DriverPreferences {
  final bool notificationsEnabled;
  final bool rideRequestSound;
  final bool keepScreenAwake;
  final DistanceUnit distanceUnit;
  final NavApp navApp;
  final Map<String, dynamic> unknown;

  const DriverPreferences({
    this.notificationsEnabled = true,
    this.rideRequestSound = true,
    this.keepScreenAwake = false,
    this.distanceUnit = DistanceUnit.miles,
    this.navApp = NavApp.google,
    this.unknown = const {},
  });

  static const _known = {
    'notifications_enabled',
    'ride_request_sound',
    'keep_screen_awake',
    'distance_unit',
    'nav_app',
  };

  DriverPreferences copyWith({
    bool? notificationsEnabled,
    bool? rideRequestSound,
    bool? keepScreenAwake,
    DistanceUnit? distanceUnit,
    NavApp? navApp,
  }) =>
      DriverPreferences(
        notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
        rideRequestSound: rideRequestSound ?? this.rideRequestSound,
        keepScreenAwake: keepScreenAwake ?? this.keepScreenAwake,
        distanceUnit: distanceUnit ?? this.distanceUnit,
        navApp: navApp ?? this.navApp,
        unknown: unknown,
      );

  factory DriverPreferences.fromJson(Map<String, dynamic> json) =>
      DriverPreferences(
        notificationsEnabled: json['notifications_enabled'] as bool? ?? true,
        rideRequestSound: json['ride_request_sound'] as bool? ?? true,
        keepScreenAwake: json['keep_screen_awake'] as bool? ?? false,
        distanceUnit: switch (json['distance_unit'] as String?) {
          'kilometres' || 'km' => DistanceUnit.kilometres,
          _ => DistanceUnit.miles,
        },
        navApp: switch (json['nav_app'] as String?) {
          'apple' => NavApp.apple,
          _ => NavApp.google,
        },
        unknown: {
          for (final e in json.entries)
            if (!_known.contains(e.key)) e.key: e.value,
        },
      );

  Map<String, dynamic> toJson() => {
        ...unknown,
        'notifications_enabled': notificationsEnabled,
        'ride_request_sound': rideRequestSound,
        'keep_screen_awake': keepScreenAwake,
        'distance_unit':
            distanceUnit == DistanceUnit.kilometres ? 'kilometres' : 'miles',
        'nav_app': navApp == NavApp.apple ? 'apple' : 'google',
      };
}
