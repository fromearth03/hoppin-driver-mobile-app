import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app_router.dart';
import '../../core/theme/colors.dart';
import 'side_drawer.dart';

/// Bottom nav + drawer wrapper. The four tabs are locked: Home, Earnings,
/// Docs, Stats. Trips is a drawer destination, not a tab.
class AppShell extends StatelessWidget {
  final Widget child;
  final int currentIndex;
  final VoidCallback? onLogout;

  const AppShell({
    super.key,
    required this.child,
    required this.currentIndex,
    this.onLogout,
  });

  /// The shell owns the only drawer in the tree. Screens inside it build
  /// their own Scaffold for an app bar, so `Scaffold.of(context)` from a
  /// screen finds that inner one — which has no drawer and throws. They
  /// call this instead.
  static final scaffoldKey = GlobalKey<ScaffoldState>();

  static void openDrawer() => scaffoldKey.currentState?.openDrawer();

  @override
  Widget build(BuildContext context) => Scaffold(
        key: scaffoldKey,
        drawer: SideDrawer(onLogout: onLogout),
        body: child,
        bottomNavigationBar: NavigationBar(
          selectedIndex: currentIndex,
          backgroundColor: AppColors.surface,
          indicatorColor: AppColors.primary.withValues(alpha: 0.12),
          onDestinationSelected: (i) => context.go(Routes.tabs[i]),
          destinations: const [
            NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: 'Home'),
            NavigationDestination(
                icon: Icon(Icons.payments_outlined),
                selectedIcon: Icon(Icons.payments),
                label: 'Earnings'),
            NavigationDestination(
                icon: Icon(Icons.description_outlined),
                selectedIcon: Icon(Icons.description),
                label: 'Docs'),
            NavigationDestination(
                icon: Icon(Icons.bar_chart_outlined),
                selectedIcon: Icon(Icons.bar_chart),
                label: 'Stats'),
          ],
        ),
      );
}
