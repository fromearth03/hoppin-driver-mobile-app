/// The launch gate — `GET /api/v1/app-status?platform=&version=`.
///
/// Public (no JWT — it runs before login) and the operator's kill switch: it
/// decides whether this build may proceed at all. The SERVER does every version
/// comparison (`minimum_required_version` vs `latest_version` vs the current
/// build), so the client just obeys the two booleans. The operator picks
/// hard-block vs soft-nudge purely by which version field they bump at release:
/// raising `minimum_required_version` above a build forces it, raising only
/// `latest_version` merely offers.
///
/// 🔴 Precedence when read: MAINTENANCE first (the whole platform is down),
/// then FORCE UPDATE (this build is too old), then the soft update nudge. A
/// client must resolve them in that order — a maintenance window outranks an
/// update prompt.
class AppStatus {
  const AppStatus({
    this.maintenanceMode = false,
    this.forceUpdateRequired = false,
    this.updateAvailable = false,
    this.minimumRequiredVersion,
    this.latestVersion,
  });

  factory AppStatus.fromJson(Map<String, dynamic> json) {
    String? clean(Object? v) {
      if (v is! String) return null;
      final t = v.trim();
      return t.isEmpty ? null : t;
    }

    return AppStatus(
      maintenanceMode: json['maintenance_mode'] as bool? ?? false,
      forceUpdateRequired: json['force_update_required'] as bool? ?? false,
      updateAvailable: json['update_available'] as bool? ?? false,
      minimumRequiredVersion: clean(json['minimum_required_version']),
      latestVersion: clean(json['latest_version']),
    );
  }

  /// The whole platform is down for maintenance — the app is UNUSABLE.
  final bool maintenanceMode;

  /// This build is below the required floor — a HARD block, no dismiss.
  final bool forceUpdateRequired;

  /// A newer build exists but this one still works — a SOFT, dismissible nudge.
  final bool updateAvailable;

  final String? minimumRequiredVersion;
  final String? latestVersion;

  /// The single gate a launch screen acts on, resolved in precedence order.
  AppGate get gate {
    if (maintenanceMode) return AppGate.maintenance;
    if (forceUpdateRequired) return AppGate.forceUpdate;
    if (updateAvailable) return AppGate.updateAvailable;
    return AppGate.ok;
  }

  /// The safe default when the status could not be read (offline, timeout, the
  /// endpoint erroring, or a `web` platform the endpoint does not gate). A
  /// failed launch check must NEVER lock a user out of a working app, so an
  /// unknown status is treated as "proceed" — the operator's kill switch is a
  /// deliberate action, never an accident of a dropped request.
  static const AppStatus unknown = AppStatus();

  Map<String, dynamic> toJson() => {
        'maintenance_mode': maintenanceMode,
        'force_update_required': forceUpdateRequired,
        'update_available': updateAvailable,
        'minimum_required_version': minimumRequiredVersion,
        'latest_version': latestVersion,
      };

  @override
  bool operator ==(Object other) =>
      other is AppStatus &&
      other.maintenanceMode == maintenanceMode &&
      other.forceUpdateRequired == forceUpdateRequired &&
      other.updateAvailable == updateAvailable &&
      other.minimumRequiredVersion == minimumRequiredVersion &&
      other.latestVersion == latestVersion;

  @override
  int get hashCode => Object.hash(maintenanceMode, forceUpdateRequired,
      updateAvailable, minimumRequiredVersion, latestVersion);
}

/// The launch decision, in precedence order.
enum AppGate {
  /// Down for maintenance — block, unusable.
  maintenance,

  /// Too old — hard block, must update.
  forceUpdate,

  /// Newer build exists — soft, dismissible nudge; app still works.
  updateAvailable,

  /// Proceed normally.
  ok,
}
