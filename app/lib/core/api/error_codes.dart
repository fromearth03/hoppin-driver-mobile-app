import 'api_exception.dart';

/// What a blocked-from-online row offers the driver to do about it.
enum BlockedAction {
  openDocuments,
  registerVehicle,
  contactSupport,

  /// Send the driver to their application checklist. Only useful now that a
  /// driver can register themselves and has steps of their own to finish.
  openOnboarding,
  none,
}

class NotEligibleCopy {
  final String title;
  final String body;
  final BlockedAction action;
  const NotEligibleCopy(this.title, this.body, this.action);
}

/// The ~22 codes a driver JWT can actually reach, per the backend's
/// error-code reference. Rider-only codes are deliberately absent — writing
/// copy for codes we cannot hit invites the wrong message being shown.
const _copy = <String, String>{
  // Global
  'VALIDATION_FAILED': 'Please check the details and try again.',
  'INTERNAL': 'Something went wrong on our side. Trying again…',
  'FORBIDDEN': "You don't have access to that.",
  'NOT_FOUND': 'That record no longer exists.',
  'RIDE_NOT_FOUND': 'That ride no longer exists.',
  'ACCOUNT_SUSPENDED': 'Your account is suspended. Please contact support.',
  'ACCOUNT_BANNED': 'Your account is banned. Please contact support.',
  'DEVICE_BLACKLISTED': 'This device has been blocked. Please contact support.',
  // Auth
  'INVALID_CREDENTIALS': 'That email or password is incorrect.',
  'TOO_MANY_ATTEMPTS': 'Too many attempts. Please wait a minute and try again.',
  'EXPIRED_LINK': 'This link has expired. Please request a new one.',
  'AUTH_FAILED': "We couldn't sign you in. Please try again.",
  // Going online
  'NOT_ELIGIBLE': "You're not cleared to go online yet.",
  'PAYOUT_NOT_READY': 'Payment setup is incomplete. Please contact support.',
  // Offers
  'OFFER_EXPIRED': 'This offer has lapsed.',
  'OFFER_NOT_FOUND': 'This offer is no longer available.',
  // Trip lifecycle
  'ILLEGAL_TRANSITION':
      "This ride isn't in a state that allows that. Refreshing now.",
  // Live map
  'NO_DRIVER_ASSIGNED': 'No driver on this ride yet.',
  'RIDE_NOT_ACTIVE': "This ride isn't active.",
  'POSITION_UNAVAILABLE': 'Waiting for a live position…',
  // Profile / documents / account
  'STORAGE_DISABLED':
      'Uploads are temporarily unavailable. Please try again shortly.',
  'PHONE_TAKEN': 'That phone number is already in use.',
  'USER_NOT_FOUND': "We couldn't find your profile.",
  'DELETION_BLOCKED': "Your account can't be deleted yet.",
};

/// User-facing copy for a failure. Never returns the server's `error`
/// string — that is log material and can carry internals.
String errorCopy(ApiException e) {
  if (e.code == 'NO_SHOW_TOO_EARLY') {
    // The server sends `seconds_remaining`; an earlier draft of this map
    // read `seconds`, which is not a key the API returns.
    final seconds = (e.fields['seconds_remaining'] as num?)?.round() ?? 0;
    final minutes = (seconds / 60).ceil();
    return 'You can report a no-show in $minutes min.';
  }
  return _copy[e.code] ?? 'Something went wrong. Please try again.';
}

const _blocked = <String, NotEligibleCopy>{
  'SUSPENDED': NotEligibleCopy('Account suspended',
      'Your account is suspended.', BlockedAction.contactSupport),
  'RESTRICTED': NotEligibleCopy('Account restricted',
      'Your account has been restricted.', BlockedAction.contactSupport),
  'DELETION_REQUESTED': NotEligibleCopy('Deletion pending',
      'Your account is scheduled for deletion.', BlockedAction.contactSupport),
  'DOCS_MISSING': NotEligibleCopy('Document needed',
      "This hasn't been uploaded yet.", BlockedAction.openDocuments),
  'DOCS_PENDING_REVIEW': NotEligibleCopy('Under review',
      "We're checking this — nothing for you to do.", BlockedAction.none),
  'DOCS_REJECTED': NotEligibleCopy('Document not accepted',
      'This needs uploading again.', BlockedAction.openDocuments),
  'DOCS_EXPIRED': NotEligibleCopy(
      'Document expired', 'This needs renewing.', BlockedAction.openDocuments),
  'NO_VEHICLE': NotEligibleCopy('No vehicle registered',
      'Add your vehicle to start driving.', BlockedAction.registerVehicle),
  'DEVICE_BLACKLISTED': NotEligibleCopy('Device blocked',
      'This device has been blocked.', BlockedAction.contactSupport),
  // A self-registered driver sets up their own payouts, so this is theirs
  // to finish. It used to tell them to wait on an operator who was never
  // coming.
  'PAYOUT_NOT_READY': NotEligibleCopy(
      'Payment setup incomplete',
      'Finish setting up how you get paid.',
      BlockedAction.openOnboarding),
  'NOT_ELIGIBLE': NotEligibleCopy(
      'Waiting for approval',
      'An admin reviews every driver before their first trip.',
      BlockedAction.openOnboarding),
  'not_compliant': NotEligibleCopy(
      'Checks outstanding',
      'Some of your details still need completing.',
      BlockedAction.openOnboarding),
  'UNKNOWN': NotEligibleCopy("Can't go online right now",
      'Please contact support.', BlockedAction.contactSupport),
};

/// Copy for one `blocked_reason` / `NOT_ELIGIBLE.reason` token. The same
/// vocabulary serves `GET /drivers/me/status` and the online refusal, so
/// one map covers both paths.
NotEligibleCopy notEligibleCopy(String reason) =>
    _blocked[reason] ?? _blocked['UNKNOWN']!;
