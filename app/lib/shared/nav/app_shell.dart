import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app_router.dart';
import '../../core/theme/colors.dart';
import '../widgets/app_glass.dart';
import '../widgets/offer_banner.dart';
import '../widgets/push_alert_listener.dart';
import 'side_drawer.dart';

/// Bottom nav + drawer wrapper. The four tabs are locked: Home, Earnings,
/// Docs, Stats. Trips is a drawer destination, not a tab.
///
/// The design draws the tab bar as a floating frosted pill — centred,
/// roughly three-fifths of the screen wide, lifted clear of the bottom edge,
/// icons only, no labels. The grey is translucent over a backdrop blur so
/// the page stays legible through it, and the selected tab is marked by
/// filling its icon rather than drawing an indicator behind it.
class AppShell extends StatelessWidget {
  final Widget child;
  final int currentIndex;
  final VoidCallback? onLogout;

  /// The live route, so the shell can decide what belongs around it: the
  /// tab pill disappears on a trip (the job IS the screen — the way out is
  /// the trip's own back control), and the offer banner skips Home where
  /// the full card already lives.
  final String currentPath;

  const AppShell({
    super.key,
    required this.child,
    required this.currentIndex,
    required this.currentPath,
    this.onLogout,
  });

  bool get _onTrip => currentPath.startsWith(Routes.trip);

  /// The shell owns the only drawer in the tree. Screens inside it build
  /// their own Scaffold for an app bar, so `Scaffold.of(context)` from a
  /// screen finds that inner one — which has no drawer and throws. They
  /// call this instead.
  static final scaffoldKey = GlobalKey<ScaffoldState>();

  static void openDrawer() => scaffoldKey.currentState?.openDrawer();

  /// The strip the floating pill covers. The shell extends the body under
  /// the bar, so any scrollable that sets its own padding must end its
  /// content this far up — otherwise the last row is permanently trapped
  /// beneath the pill. (Scrollables with no explicit padding inherit the
  /// same inset from MediaQuery and need nothing.)
  static const bottomClearance = 108.0;

  static const _tabs = [
    _Tab(Icons.home_outlined, Icons.home, 'Home'),
    // The design's £-in-a-circle. `currency_pound` alone is the glyph without
    // the ring, so the ring is drawn around it below.
    _Tab(Icons.currency_pound, Icons.currency_pound, 'Earnings', ringed: true),
    _Tab(Icons.description_outlined, Icons.description, 'Docs'),
    _Tab(Icons.insert_chart_outlined, Icons.insert_chart, 'Stats'),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
    key: scaffoldKey,
    backgroundColor: AppColors.background,
    drawer: SideDrawer(onLogout: onLogout, currentPath: currentPath),
    // The pill floats over the content rather than reserving a strip of
    // it, which is how the design shows it sitting on the page ground.
    extendBody: true,
    body: Stack(
      children: [
        Positioned.fill(child: child),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: OfferBanner(currentPath: currentPath),
        ),
        // Raises a foreground push as a toast. Zero-sized: it only listens,
        // and the toast itself goes into the overlay above everything.
        const PushAlertListener(),
      ],
    ),
    bottomNavigationBar: _onTrip
        ? null
        : SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 18),
              // heightFactor pins the Center to its child's height —
              // bottomNavigationBar hands out loose constraints, and a bare
              // Center expands into them, parking the pill mid-screen.
              child: Center(
                heightFactor: 1,
                child: AppGlass(
                  borderRadius: BorderRadius.circular(28),
                  tint: AppColors.navPill,
                  child: Material(
                    color: Colors.transparent,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (var i = 0; i < _tabs.length; i++)
                            _TabButton(
                              tab: _tabs[i],
                              selected: i == currentIndex,
                              onTap: () => context.go(Routes.tabs[i]),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
  );
}

class _Tab {
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  /// True where the design draws the glyph inside a hairline circle.
  final bool ringed;

  const _Tab(this.icon, this.selectedIcon, this.label, {this.ringed = false});
}

class _TabButton extends StatelessWidget {
  final _Tab tab;
  final bool selected;
  final VoidCallback onTap;

  const _TabButton({
    required this.tab,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final icon = Icon(
      selected ? tab.selectedIcon : tab.icon,
      size: tab.ringed ? 16 : 24,
      color: Colors.white,
    );

    // Icon only — the design's pill carries no labels. The label survives
    // as the tooltip and the semantic name, so the tab is still findable
    // by assistive tech and by hover.
    return Semantics(
      button: true,
      selected: selected,
      label: tab.label,
      child: Tooltip(
        message: tab.label,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 13),
            child: SizedBox(
              height: 24,
              width: 24,
              child: Center(
                child: tab.ringed
                    ? Container(
                        width: 24,
                        height: 24,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white,
                            width: selected ? 2.2 : 1.5,
                          ),
                        ),
                        child: icon,
                      )
                    : icon,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
