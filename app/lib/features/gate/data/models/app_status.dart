/// Which wall, if any, the app must put in front of the driver.
enum AppGate {
  /// Nothing in the way.
  none,

  /// The service is down on purpose. Outranks everything: sending a driver
  /// to a store to update while the backend is offline sends them somewhere
  /// that cannot help them.
  maintenance,

  /// This build is below the floor the operator has armed.
  forceUpdate,
}

/// The public launch gate from `GET /api/v1/app-status`.
///
/// Read before login and polled while the app runs, so an operator can take
/// the service down — or retire a broken build — without waiting for anyone
/// to restart anything.
///
/// Every flag defaults to false. An unconfigured platform answers with the
/// platform name and nothing else, and reading a missing flag as true would
/// lock the whole fleet out of the app.
class AppStatus {
  final String? platform;
  final String? minimumRequiredVersion;
  final String? latestVersion;
  final bool maintenanceMode;
  final bool updateAvailable;
  final bool forceUpdateRequired;

  const AppStatus({
    this.platform,
    this.minimumRequiredVersion,
    this.latestVersion,
    this.maintenanceMode = false,
    this.updateAvailable = false,
    this.forceUpdateRequired = false,
  });

  /// Nothing gated. Also what a failed read falls back to: the app must never
  /// lock a driver out because a status call timed out.
  static const open = AppStatus();

  factory AppStatus.fromJson(Map<String, dynamic> json) => AppStatus(
        platform: json['platform'] as String?,
        minimumRequiredVersion: json['minimum_required_version'] as String?,
        latestVersion: json['latest_version'] as String?,
        maintenanceMode: json['maintenance_mode'] as bool? ?? false,
        updateAvailable: json['update_available'] as bool? ?? false,
        forceUpdateRequired: json['force_update_required'] as bool? ?? false,
      );

  AppGate get gate {
    if (maintenanceMode) return AppGate.maintenance;
    if (forceUpdateRequired) return AppGate.forceUpdate;
    return AppGate.none;
  }

  /// Whether the driver is stopped. An available update is a nudge, never a
  /// wall: a driver mid-shift must not be barred from working because a
  /// nicer build exists.
  bool get blocks => gate != AppGate.none;
}
