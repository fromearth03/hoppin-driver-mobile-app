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
  static const settings = '/settings';
  static const payouts = '/payouts';
  static const deleteAccount = '/delete-account';

  // Auth
  static const signIn = '/sign-in';
  static const forgotPassword = '/forgot-password';
  static const resetPassword = '/reset-password';

  // Trip
  static const trip = '/trip';

  /// The four bottom-nav tabs, in order. Docs takes a slot because an
  /// expired document stops a driver earning; Trips is in the drawer.
  static const tabs = [home, earnings, documents, stats];
}
