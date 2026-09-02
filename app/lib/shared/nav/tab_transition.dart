import 'package:flutter/material.dart';

import '../../app_router.dart';

/// Which way a tab change should move, as -1, 0 or 1.
///
/// The bottom bar is a row, so moving along it should look like moving along
/// it: Home to Earnings brings the new screen in from the right, and coming
/// back brings it from the left. A cross-fade in both directions loses the
/// one thing the animation could have said.
///
/// Zero for anything that is not a move between two tabs. Trips, Settings and
/// the rest are opened from the drawer and sit in no row — sliding them along
/// an axis they do not occupy would imply a position they do not have.
int slideDirection({required String? from, required String? to}) {
  if (from == null || to == null || from == to) return 0;
  final a = Routes.tabs.indexOf(from);
  final b = Routes.tabs.indexOf(to);
  if (a < 0 || b < 0) return 0;
  return b > a ? 1 : -1;
}

/// Slides the shell's content when the driver moves along the bottom bar.
///
/// Wraps the child rather than replacing each route's page builder: the shell
/// is the one place that sees every navigation, so it is the only place that
/// knows both where the driver was and where they have gone.
class TabSwitcher extends StatefulWidget {
  final String path;
  final Widget child;

  const TabSwitcher({super.key, required this.path, required this.child});

  @override
  State<TabSwitcher> createState() => _TabSwitcherState();
}

class _TabSwitcherState extends State<TabSwitcher> {
  String? _previous;

  @override
  void didUpdateWidget(TabSwitcher old) {
    super.didUpdateWidget(old);
    if (old.path != widget.path) _previous = old.path;
  }

  @override
  Widget build(BuildContext context) {
    final direction = slideDirection(from: _previous, to: widget.path);

    return AnimatedSwitcher(
      // A tab change is a step sideways, not a screen pushed onto a stack:
      // short enough that a driver switching quickly never waits on it.
      duration: Duration(milliseconds: direction == 0 ? 0 : 220),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeIn,
      // The outgoing screen is not animated out from under the incoming one:
      // two moving layers on a map-heavy page reads as a glitch, and the old
      // screen leaving is not the information here.
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.topLeft,
        children: [
          ...previous,
          if (current != null) current,
        ],
      ),
      transitionBuilder: (child, animation) {
        if (direction == 0) return child;
        return SlideTransition(
          position: Tween<Offset>(
            begin: Offset(direction.toDouble(), 0),
            end: Offset.zero,
          ).animate(animation),
          // Fading alongside the slide keeps the incoming screen from
          // reading as a card thrown over the old one.
          child: FadeTransition(opacity: animation, child: child),
        );
      },
      child: KeyedSubtree(key: ValueKey(widget.path), child: widget.child),
    );
  }
}
