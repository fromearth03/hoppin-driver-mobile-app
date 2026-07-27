import 'package:flutter/material.dart';
import 'package:hoppin_ui/hoppin_ui.dart';

/// The #68 rung. 🔴 READ THIS BEFORE YOU "IMPROVE" THIS SCREEN.
///
/// There is no `GET /me/notifications`. We cannot load a driver's history. We
/// therefore **do not know** whether they have notifications, and the ONLY
/// honest render of that is a disclosure.
///
/// An empty centre reading "You have no notifications" is a LIE — it asserts a
/// fact we do not have. **Asserting emptiness when the truth is ignorance is
/// precisely the quiet lie this instrument exists to delete.**
///
/// It says: we can show what arrived while the app was open; we cannot load
/// what came before. And it says push delivery is not yet switched on by the
/// platform (#15/#16), so there is nothing being sent to miss.
///
/// "Delete all notifications" ships DISABLED inside this rung — deleting a
/// SERVER record we cannot reach is a lie. "Mark all as read" stays ENABLED:
/// read-state is purely local and lies about nothing.
///
/// 🔴 THE ASYMMETRY WITH THE SUPPORT HUB IS DELIBERATE AND MUST SURVIVE.
/// `GET /me/support-tickets` is BOUND, so ITS empty list is a fact and it gets
/// a confident `HopEmptyState`. This screen has no endpoint at all. Anyone who
/// "tidies" these two into one shared empty-state component has converted a
/// disclosure into a lie.
///
/// It is CONSTRUCTED by `notification_centre_screen.dart` on BOTH branches: the
/// empty feed, and pinned beneath a populated list (live events do not make
/// OLDER history readable). That mount site is what the Group C reachability
/// check looks for — a declared-but-never-constructed disclosure is dead code
/// wearing a compliance badge.
///
/// Body-swaps to the live read with zero view changes when the endpoint ships.
class NotificationHistoryUnavailable extends StatelessWidget {
  /// Creates the #68 history disclosure.
  const NotificationHistoryUnavailable({super.key});

  @override
  Widget build(BuildContext context) {
    final hoppin = context.hoppin;
    final colors = hoppin.colors;

    return HopCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.history_toggle_off, color: colors.textMid, size: 20),
              SizedBox(width: hoppin.spacing.sm),
              Expanded(
                child: Text(
                  // Says what we CANNOT DO. It does not say what the driver
                  // does or does not have — we have no way to know that.
                  "Older notifications can't be loaded yet",
                  style:
                      hoppin.type.titleSmall.copyWith(color: colors.textHi),
                ),
              ),
            ],
          ),
          SizedBox(height: hoppin.spacing.sm),
          Text(
            'This list shows what arrived while the app was open. We cannot '
            'load your earlier notifications yet.',
            style: hoppin.type.bodySmall.copyWith(color: colors.textMid),
          ),
          SizedBox(height: hoppin.spacing.sm),
          Text(
            // The #15/#16 gate, said plainly and promising NOTHING. A
            // correctly-registered token that never receives anything is the
            // honest state of a wired client waiting on a server — it is not a
            // licence to imply pushes are coming.
            'Push notifications are not being sent by the platform yet, so '
            'nothing is arriving that way.',
            style: hoppin.type.bodySmall.copyWith(color: colors.textMid),
          ),
        ],
      ),
    );
  }
}
