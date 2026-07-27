import 'package:flutter/material.dart';

import '../components/fare_estimate_card.dart';
import '../components/hop_bottom_nav.dart';
import '../components/hop_button.dart';
import '../components/hop_card.dart';
import '../components/hop_list_row.dart';
import '../components/hop_popup.dart';
import '../components/hop_sheet.dart';
import '../components/hop_top_bar.dart';
import '../components/location_field.dart';
import '../components/otp_input.dart';
import '../components/plate_chip.dart';
import '../components/ride_type_card.dart';
import '../components/status_pill.dart';
import '../theme/context_extension.dart';

/// The hoppin_ui dev gallery: every wave-1 brand component in its variants,
/// plus the type ramp, on one scrollable screen.
///
/// Three jobs: a screen any app can push temporarily to eyeball the system
/// under its own theme, the living usage reference for the phases that build
/// on these components, and the smoke-test surface that proves the whole
/// set lays out under all four themes.
class HoppinGallery extends StatelessWidget {
  /// Creates the gallery screen.
  const HoppinGallery({super.key});

  Widget _section(BuildContext context, String title) {
    final hoppin = context.hoppin;
    return Padding(
      padding: EdgeInsets.only(
        top: hoppin.spacing.xl,
        bottom: hoppin.spacing.md,
      ),
      child: Text(
        title.toUpperCase(),
        style: hoppin.type.labelSmall.copyWith(
          color: hoppin.colors.textMid,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _gap(BuildContext context) =>
      SizedBox(height: context.hoppin.spacing.md);

  Widget _ledgerRow(BuildContext context, String label, String amount) {
    final hoppin = context.hoppin;
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: hoppin.type.bodySmall.copyWith(
              color: hoppin.colors.textMid,
            ),
          ),
        ),
        Text(
          amount,
          style: hoppin.type.ledger.copyWith(color: hoppin.colors.textHi),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final hoppin = context.hoppin;
    final colors = hoppin.colors;
    return Scaffold(
      appBar: AppBar(title: const Text('Hoppin gallery')),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(hoppin.spacing.gutter),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _section(context, 'Buttons'),
            HopButton.primary(label: 'Confirm ride', onPressed: () {}),
            _gap(context),
            HopButton.primary(
              label: 'Confirming',
              busy: true,
              onPressed: () {},
            ),
            _gap(context),
            HopButton.secondary(
              label: 'Schedule',
              icon: Icons.schedule,
              onPressed: () {},
            ),
            _gap(context),
            const HopButton.secondary(label: 'Unavailable', onPressed: null),
            _gap(context),
            HopButton.ghost(label: 'Skip for now', onPressed: () {}),
            _section(context, 'Cards'),
            HopCard(
              child: Text(
                'Resting card — hairline border, radius 10, no shadow.',
                style: hoppin.type.bodySmall.copyWith(color: colors.textHi),
              ),
            ),
            _gap(context),
            HopCard(
              selected: true,
              child: Text(
                'Selected card — selectedTint fill + 1px navy border.',
                style: hoppin.type.bodySmall.copyWith(color: colors.textHi),
              ),
            ),
            _gap(context),
            HopCard(
              onTap: () {},
              child: Text(
                'Tappable card — ink response inside the same radius.',
                style: hoppin.type.bodySmall.copyWith(color: colors.textHi),
              ),
            ),
            _section(context, 'Status pills'),
            Wrap(
              spacing: hoppin.spacing.sm,
              runSpacing: hoppin.spacing.sm,
              children: const [
                StatusPill(label: 'Requested'),
                StatusPill(tone: PillTone.accent, label: 'Matched'),
                StatusPill(tone: PillTone.success, label: 'Live', dot: true),
                StatusPill(tone: PillTone.warn, label: 'Delayed'),
                StatusPill(tone: PillTone.error, label: 'Cancelled'),
                StatusPill(tone: PillTone.accent, label: '4 min', numeric: true),
              ],
            ),
            _section(context, 'Number plate'),
            Wrap(
              spacing: hoppin.spacing.md,
              runSpacing: hoppin.spacing.md,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: const [
                PlateChip(reg: 'BK72 WNH'),
                PlateChip(reg: 'BK72 WNH', size: PlateSize.lg),
              ],
            ),
            _section(context, 'Sheet'),
            Builder(
              builder: (context) => HopButton.ghost(
                label: 'Open sheet',
                onPressed: () => HopSheet.show<void>(
                  context,
                  builder: (sheetContext) {
                    final sheetHoppin = sheetContext.hoppin;
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Fare breakdown',
                          style: sheetHoppin.type.title.copyWith(
                            color: sheetHoppin.colors.textHi,
                          ),
                        ),
                        SizedBox(height: sheetHoppin.spacing.lg),
                        _ledgerRow(sheetContext, 'Base fare', '£4.20'),
                        SizedBox(height: sheetHoppin.spacing.sm),
                        _ledgerRow(sheetContext, 'Distance', '£3.20'),
                        SizedBox(height: sheetHoppin.spacing.lg),
                        HopButton.primary(
                          label: 'Done',
                          onPressed: () => Navigator.of(sheetContext).pop(),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
            _section(context, 'Ride types'),
            Wrap(
              spacing: hoppin.spacing.md,
              runSpacing: hoppin.spacing.md,
              children: [
                RideTypeCard(
                  name: 'Standard',
                  capacity: '4 seats • Upto 2 bags',
                  icon: Icons.directions_car_outlined,
                  selected: true,
                  onTap: () {},
                ),
                RideTypeCard(
                  name: 'Estate',
                  capacity: '4 seats • Upto 4 bags',
                  icon: Icons.airport_shuttle_outlined,
                  onTap: () {},
                ),
              ],
            ),
            _section(context, 'Location field'),
            LocationField(
              fromLabel: 'From',
              fromValue: '12 Kings Road, Reading',
              toLabel: 'To',
              toValue: 'Reading Station',
              onEditFrom: () {},
              onEditTo: () {},
            ),
            _section(context, 'Fare estimate'),
            const FareEstimateCard(
              lines: [
                FareLine(label: 'Base fare', amount: '£4.20'),
                FareLine(label: 'Distance', amount: '£3.20'),
                FareLine(
                  label: 'Surge',
                  amount: '£2.10',
                  surgeMultiplier: '1.5x',
                ),
              ],
              totalAmount: '£9.50',
            ),
            _section(context, 'Verification code'),
            OtpInput(onChanged: (_) {}),
            _section(context, 'List rows'),
            HopCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  HopListRow(
                    icon: Icons.person_outline,
                    label: 'Personal information',
                    divider: true,
                    onTap: () {},
                  ),
                  HopListRow(
                    icon: Icons.account_balance_wallet_outlined,
                    label: 'Payment methods',
                    onTap: () {},
                  ),
                ],
              ),
            ),
            _section(context, 'Top bar'),
            HopTopBar(
              title: 'Book Ride',
              notificationCount: 2,
              onBack: () {},
              onBell: () {},
              onAvatarTap: () {},
            ),
            _section(context, 'Bottom nav'),
            HopBottomNav(currentIndex: 0, onTap: (_) {}),
            _section(context, 'Popup'),
            Builder(
              builder: (context) => HopButton.ghost(
                label: 'Open popup',
                onPressed: () => HopPopup.confirm(
                  context,
                  title: 'Cancel ride?',
                  message: 'You may be charged a cancellation fee.',
                  confirmLabel: 'Cancel ride',
                  cancelLabel: 'Keep ride',
                  destructive: true,
                ),
              ),
            ),
            _section(context, 'Type ramp'),
            Text(
              'Display 44',
              style: hoppin.type.display.copyWith(color: colors.textHi),
            ),
            Text(
              'Headline 28',
              style: hoppin.type.headline.copyWith(color: colors.textHi),
            ),
            Text(
              'Title 20',
              style: hoppin.type.title.copyWith(color: colors.textHi),
            ),
            Text(
              'Body 16 — Geist carries the words.',
              style: hoppin.type.body.copyWith(color: colors.textHi),
            ),
            Text(
              'Label 13',
              style: hoppin.type.label.copyWith(color: colors.textMid),
            ),
            _gap(context),
            Text(
              '£7.40',
              style: hoppin.type.moneyHero.copyWith(color: colors.textHi),
            ),
            _gap(context),
            _ledgerRow(context, 'Earned today', '£43.75'),
            SizedBox(height: hoppin.spacing.xl),
          ],
        ),
      ),
    );
  }
}
