import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app_router.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import 'side_drawer.dart';

/// Bottom nav + drawer wrapper. The four tabs are locked: Home, Earnings,
/// Docs, Stats. Trips is a drawer destination, not a tab.
///
/// The design draws the tab bar as a floating grey pill — centred, about
/// three-fifths of the screen wide, lifted clear of the bottom edge — rather
/// than a full-width Material bar, and marks the selected tab by filling its
/// icon instead of drawing an indicator behind it. It appears identically on
/// every screen in the pack (offline home, online home, stats), so the grey
/// is the bar's own colour, not the offline state tinting the chrome.
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
        drawer: SideDrawer(onLogout: onLogout),
        // The pill floats over the content rather than reserving a strip of
        // it, which is how the design shows it sitting on the page ground.
        extendBody: true,
        body: child,
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            // The labelled bar in the design spans the width inset by a
            // thumb's width each side, sitting clear of the bottom edge.
            padding: const EdgeInsets.fromLTRB(17, 0, 17, 18),
            child: Material(
              color: AppColors.textSecondary,
              borderRadius: BorderRadius.circular(24),
              clipBehavior: Clip.antiAlias,
              child: Row(
                children: [
                  for (var i = 0; i < _tabs.length; i++)
                    Expanded(
                      child: _TabButton(
                        tab: _tabs[i],
                        selected: i == currentIndex,
                        onTap: () => context.go(Routes.tabs[i]),
                      ),
                    ),
                ],
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
      size: tab.ringed ? 17 : 26,
      color: Colors.white,
    );

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 26,
              child: tab.ringed
                  ? Container(
                      width: 26,
                      height: 26,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white,
                          width: selected ? 2.4 : 1.6,
                        ),
                      ),
                      child: icon,
                    )
                  : icon,
            ),
            const SizedBox(height: 3),
            Text(
              tab.label,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.fade,
              style: AppText.caption.copyWith(
                color: Colors.white,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
