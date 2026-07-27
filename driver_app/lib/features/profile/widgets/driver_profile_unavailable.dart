import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hoppin_ui/hoppin_ui.dart';

/// The #39 rung — there is no driver `GET`/`PATCH /me/profile`.
///
/// 🔴 MOUNTED UNCONDITIONALLY, and that is deliberate. A conditional rung
/// ("show this when the fetch fails") implies the data SOMETIMES arrives. It
/// never does. There is no endpoint. The seam is not sometimes-null — it is
/// ALWAYS null, and a rung that only appears on a bad day teaches a driver
/// that a good day exists.
///
/// It carries the ONE live control on the screen: a working exit to support,
/// which is the honest route to **Art. 16 rectification** while no PATCH
/// exists. A driver whose name is wrong on the platform has a right to have it
/// corrected, and a human can do it today.
///
/// Body-swaps to the live profile write with zero view changes when the
/// endpoint ships: the rung disappears and Save gets a callback.
class DriverProfileUnavailable extends StatelessWidget {
  /// Creates the #39 profile-write disclosure.
  const DriverProfileUnavailable({super.key});

  @override
  Widget build(BuildContext context) {
    final hoppin = context.hoppin;

    return HopCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const HopEmptyState(
            compact: true,
            headline: "You can't change these details here yet",
            supporting:
                "Saving isn't switched on. To correct anything we hold about "
                'you, open a support ticket and a person will put it right.',
          ),
          SizedBox(height: hoppin.spacing.sm),
          HopButton.secondary(
            key: const Key('driver.profile.rung.support'),
            label: 'Open a support ticket',
            expand: false,
            // The one live control on this screen. It must actually land — a
            // disclosure that strands the driver is only half-honest.
            onPressed: () => context.go('/support'),
          ),
        ],
      ),
    );
  }
}
