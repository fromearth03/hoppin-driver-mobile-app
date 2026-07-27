import 'package:flutter/material.dart';
import 'package:hoppin_ui/hoppin_ui.dart';

/// SEAM #82 — vehicle registration / assignment from the app.
///
/// 🔴 **REGISTRATION3 IS A FORM THAT POSTS NOWHERE, AND WE ARE NOT SHIPPING IT.**
///
/// The Figma's Registration3 collects the vehicle's registration plate, its make
/// and model, the insurance provider and the insurance expiry date. **Nothing on
/// the backend accepts a single one of them.** `Ride` carries a `vehicle_id` the
/// app never sets; vehicle assignment happens ADMIN-SIDE. There is no
/// `POST /drivers/me/vehicle`, and there is no endpoint that would take these
/// fields under any other name.
///
/// A driver who fills that form, taps Continue, and sees the step tick over now
/// **BELIEVES their vehicle is registered against their account.** It is not.
/// They will discover it when dispatch never matches them — or, far worse, when
/// somebody asks about insurance and the platform has no record they ever told
/// us. A form that silently discards a driver's work while showing them a
/// success state is not a shortcut; it is a lie with a plausible-looking UI.
///
/// So the step ships the STRUCTURE (so the wizard's shape survives, and the day
/// the endpoint lands the fields drop straight in) and this RUNG (so the driver
/// is told the truth today): vehicle details are held by the operator, not by
/// this app, and if theirs are wrong they talk to us. Forward exit: continue to
/// the documents, which DO work.
///
/// Registered in `kSeamRegistry` under **#82** (SCOPE-TRACE row 52). Mounted
/// UNCONDITIONALLY by `vehicle_step.dart` — the seam is not sometimes-null, it
/// is always-null, and a rung behind an `if` is one refactor from being
/// unreachable.
class VehicleRegistrationUnavailable extends StatelessWidget {
  /// Creates the #82 vehicle-registration degrade rung.
  const VehicleRegistrationUnavailable({this.onContactSupport, super.key});

  /// Route to support, when the driver's vehicle details are wrong. Optional so
  /// the rung stays pumpable bare (group C mounts it with no app around it) — a
  /// disclosure that needs the whole app running to render is not a disclosure.
  final VoidCallback? onContactSupport;

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
              Icon(
                Icons.directions_car_outlined,
                size: 20,
                color: colors.textMid,
              ),
              SizedBox(width: hoppin.spacing.sm),
              Expanded(
                child: Text(
                  // In the DRIVER'S terms. Not "gap #82", not "no endpoint" —
                  // the driver does not have a backlog, they have a car.
                  'Your operator holds your vehicle details',
                  style: hoppin.type.bodyMedium.copyWith(color: colors.textHi),
                ),
              ),
            ],
          ),
          SizedBox(height: hoppin.spacing.sm),
          Text(
            "We can't register a vehicle from the app yet. The Hoppin team has "
            'the car you drive on file, along with its insurance — you '
            "don't need to enter anything here.",
            style: hoppin.type.meta.copyWith(color: colors.textMid),
          ),
          SizedBox(height: hoppin.spacing.sm),
          Text(
            "If you've changed vehicle, or anything below looks wrong, contact "
            "us and we'll update it before your next shift.",
            style: hoppin.type.meta.copyWith(color: colors.textMid),
          ),
          if (onContactSupport != null) ...[
            SizedBox(height: hoppin.spacing.lg),
            HopButton.secondary(
              label: 'Contact the team',
              onPressed: onContactSupport,
              expand: false,
            ),
          ],
        ],
      ),
    );
  }
}
