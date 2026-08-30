/// Where a self-registered driver stands, from `GET /drivers/me/onboarding`.
enum OnboardingStatus { pendingApproval, active, restricted, suspended }

/// How a single uploaded document is faring in review.
class OnboardingDocument {
  final String type;
  final String status;

  /// The admin's own words. Never substituted with a generic phrase — the
  /// driver has to know what to fix.
  final String rejectionReason;

  const OnboardingDocument({
    required this.type,
    required this.status,
    this.rejectionReason = '',
  });

  bool get isRejected => status == 'rejected';

  factory OnboardingDocument.fromJson(Map<String, dynamic> json) =>
      OnboardingDocument(
        type: (json['type'] as String?) ?? '',
        status: (json['status'] as String?) ?? '',
        rejectionReason: (json['rejection_reason'] as String?) ?? '',
      );
}

/// The checklist. Each flag is one step the driver must complete before an
/// admin will look at the application.
class OnboardingSteps {
  final bool profile;
  final bool license;
  final bool vehicle;
  final bool vehicleCompliance;
  final bool payout;
  final int credentialsCount;
  final int documentsApproved;
  final int documentsPending;
  final int documentsRejected;

  const OnboardingSteps({
    this.profile = false,
    this.license = false,
    this.vehicle = false,
    this.vehicleCompliance = false,
    this.payout = false,
    this.credentialsCount = 0,
    this.documentsApproved = 0,
    this.documentsPending = 0,
    this.documentsRejected = 0,
  });

  factory OnboardingSteps.fromJson(Map<String, dynamic> json) {
    final docs = (json['documents'] as Map?) ?? const {};
    return OnboardingSteps(
      profile: json['profile'] as bool? ?? false,
      license: json['license'] as bool? ?? false,
      vehicle: json['vehicle'] as bool? ?? false,
      vehicleCompliance: json['vehicle_compliance'] as bool? ?? false,
      payout: json['payout'] as bool? ?? false,
      credentialsCount: (json['credentials_count'] as num?)?.toInt() ?? 0,
      documentsApproved: (docs['approved'] as num?)?.toInt() ?? 0,
      documentsPending: (docs['pending'] as num?)?.toInt() ?? 0,
      documentsRejected: (docs['rejected'] as num?)?.toInt() ?? 0,
    );
  }

  /// A credential is required for the compliance sweep to pass, so no
  /// credential at all is an incomplete step like any other.
  bool get credentials => credentialsCount > 0;

  bool get documents => documentsApproved + documentsPending > 0;

  /// Everything the driver can do unaided. Approval itself is not here —
  /// that is an admin's decision, not a step they can tick off.
  int get completed => [
        profile,
        license,
        vehicle,
        vehicleCompliance,
        payout,
        credentials,
        documents,
      ].where((done) => done).length;

  int get total => 7;
}

class DriverOnboarding {
  final OnboardingStatus status;

  /// Approved *and* able to be paid. A driver can be approved with payouts
  /// still pending, and must not be told they can work.
  final bool canOperate;
  final String accountStatus;
  final OnboardingSteps steps;
  final List<OnboardingDocument> documents;

  /// The server's own wording for the current state. Shown verbatim rather
  /// than paraphrased, so support and the app never tell different stories.
  final String message;

  const DriverOnboarding({
    required this.status,
    this.canOperate = false,
    this.accountStatus = '',
    this.steps = const OnboardingSteps(),
    this.documents = const [],
    this.message = '',
  });

  bool get isActive => status == OnboardingStatus.active;

  /// Documents an admin sent back. These are the only items the driver can
  /// act on while waiting, so they lead the review screen.
  List<OnboardingDocument> get rejectedDocuments =>
      documents.where((d) => d.isRejected).toList();

  factory DriverOnboarding.fromJson(Map<String, dynamic> json) =>
      DriverOnboarding(
        // An unknown status must never read as active: that would tell a
        // pending driver to go online and fail them at the first offer.
        status: switch (json['status'] as String?) {
          'active' => OnboardingStatus.active,
          'restricted' => OnboardingStatus.restricted,
          'suspended' => OnboardingStatus.suspended,
          _ => OnboardingStatus.pendingApproval,
        },
        canOperate: json['can_operate'] as bool? ?? false,
        accountStatus: (json['account_status'] as String?) ?? '',
        steps: OnboardingSteps.fromJson(
            Map<String, dynamic>.from((json['steps'] as Map?) ?? const {})),
        documents: ((json['documents'] as List?) ?? const [])
            .map((e) =>
                OnboardingDocument.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        message: (json['message'] as String?) ?? '',
      );
}
