/// Route paths, in one place so deep links and drawer entries cannot drift.
class Routes {
  Routes._();

  static const home = '/';
  static const earnings = '/earnings';
  static const documents = '/documents';
  static const stats = '/stats';

  // Drawer destinations
  static const trips = '/trips';
  static const statement = '/statement';
  static const personalInfo = '/profile';
  static const notifications = '/notifications';
  static const support = '/support';
  static const supportTicket = '/support/ticket';
  static const settings = '/settings';
  static const payouts = '/payouts';
  static const deleteAccount = '/delete-account';

  // Auth
  static const signIn = '/sign-in';
  static const signUp = '/sign-up';
  static const forgotPassword = '/forgot-password';
  static const resetPassword = '/reset-password';
  static const expiredLink = '/expired-link';

  /// Where a driver lands when their session is taken over elsewhere. Its
  /// own route rather than a dialog, because every call is 401 by then and
  /// whatever screen they were on can no longer load anything.
  static const sessionTaken = '/session-taken';

  // Onboarding — a self-registered driver's route to their first trip.
  static const onboarding = '/onboarding';
  static const onboardingLicense = '/onboarding/licence';
  static const onboardingVehicle = '/onboarding/vehicle';
  static const onboardingCredentials = '/onboarding/credentials';

  // Trip
  static const trip = '/trip';

  /// The four bottom-nav tabs, in order. Docs takes a slot because an
  /// expired document stops a driver earning; Trips is in the drawer.
  static const tabs = [home, earnings, documents, stats];
}
