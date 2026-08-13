import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hoppin_shared/hoppin_shared.dart';
import 'package:hoppin_ui/hoppin_ui.dart';

/// The authenticated driver's registered vehicle.
final driverVehicleProvider = FutureProvider.autoDispose<DriverVehicle?>((ref) {
  return ref.watch(driverRepositoryProvider).vehicle();
});

abstract final class DriverVehicleDetailsKeys {
  static const root = ValueKey('driver-vehicle-details-root');
  static const loaded = ValueKey('driver-vehicle-details-loaded');
  static const empty = ValueKey('driver-vehicle-details-empty');
  static const error = ValueKey('driver-vehicle-details-error');
}

/// Read-only details for the vehicle held against the driver's account.
class DriverVehicleDetailsScreen extends ConsumerWidget {
  const DriverVehicleDetailsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hoppin = context.hoppin;
    final colors = hoppin.colors;
    final vehicle = ref.watch(driverVehicleProvider);

    return Scaffold(
      key: DriverVehicleDetailsKeys.root,
      backgroundColor: colors.canvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            HopTopBar(
              title: 'Vehicle details',
              onBack: () =>
                  context.canPop() ? context.pop() : context.go('/profile'),
            ),
            Expanded(
              child: RefreshIndicator(
                color: colors.accent,
                backgroundColor: colors.card,
                onRefresh: () async => ref.invalidate(driverVehicleProvider),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    hoppin.spacing.gutter,
                    hoppin.spacing.md,
                    hoppin.spacing.gutter,
                    hoppin.spacing.xl,
                  ),
                  children: [
                    switch (vehicle) {
                      AsyncValue(:final error?) => HopBanner.error(
                        key: DriverVehicleDetailsKeys.error,
                        message: friendlyErrorMessage(error),
                        actionLabel: 'Retry',
                        onAction: () => ref.invalidate(driverVehicleProvider),
                      ),
                      AsyncValue(value: null, hasValue: true) => const HopCard(
                        key: DriverVehicleDetailsKeys.empty,
                        child: HopEmptyState(
                          compact: true,
                          headline: 'No vehicle registered',
                          supporting:
                              'Your vehicle details will appear here once '
                              'they have been added to your account.',
                        ),
                      ),
                      AsyncValue(:final value?) => _VehicleDetails(
                        key: DriverVehicleDetailsKeys.loaded,
                        vehicle: value,
                      ),
                      _ => Center(
                        child: Padding(
                          padding: EdgeInsets.all(hoppin.spacing.xl),
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        ),
                      ),
                    },
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VehicleDetails extends StatelessWidget {
  const _VehicleDetails({required this.vehicle, super.key});

  final DriverVehicle vehicle;

  @override
  Widget build(BuildContext context) {
    final hoppin = context.hoppin;
    final colors = hoppin.colors;
    final color = _present(vehicle.color);
    final insurer = _present(vehicle.insuranceProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HopCard(
          child: Column(
            children: [
              Icon(
                Icons.directions_car_outlined,
                size: 36,
                color: colors.accent,
              ),
              SizedBox(height: hoppin.spacing.sm),
              Text(
                '${vehicle.make} ${vehicle.model}',
                textAlign: TextAlign.center,
                style: hoppin.type.section.copyWith(color: colors.textHi),
              ),
              SizedBox(height: hoppin.spacing.md),
              PlateChip(reg: vehicle.licensePlate, size: PlateSize.lg),
            ],
          ),
        ),
        SizedBox(height: hoppin.spacing.lg),
        _SectionLabel('Vehicle', key: const Key('vehicle-details.vehicle')),
        HopCard(
          padding: EdgeInsets.symmetric(horizontal: hoppin.spacing.lg),
          child: Column(
            children: [
              if (vehicle.year != null)
                _DetailRow(label: 'Year', value: '${vehicle.year}'),
              if (color != null) _DetailRow(label: 'Colour', value: color),
              _DetailRow(
                label: 'Passenger capacity',
                value: '${vehicle.passengerCapacity} passengers',
                divider: false,
              ),
            ],
          ),
        ),
        if (insurer != null || vehicle.insuranceExpiry != null) ...[
          SizedBox(height: hoppin.spacing.lg),
          _SectionLabel(
            'Insurance',
            key: const Key('vehicle-details.insurance'),
          ),
          HopCard(
            padding: EdgeInsets.symmetric(horizontal: hoppin.spacing.lg),
            child: Column(
              children: [
                if (insurer != null)
                  _DetailRow(
                    label: 'Provider',
                    value: insurer,
                    divider: vehicle.insuranceExpiry != null,
                  ),
                if (vehicle.insuranceExpiry != null)
                  _DetailRow(
                    label: 'Expiry date',
                    value: _formatDate(vehicle.insuranceExpiry!),
                    divider: false,
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final hoppin = context.hoppin;
    return Padding(
      padding: EdgeInsets.only(bottom: hoppin.spacing.sm),
      child: Text(
        label.toUpperCase(),
        style: hoppin.type.labelSmall.copyWith(
          color: hoppin.colors.textMid,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.divider = true,
  });

  final String label;
  final String value;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    final hoppin = context.hoppin;
    final colors = hoppin.colors;
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(vertical: hoppin.spacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: hoppin.type.bodySmall.copyWith(color: colors.textMid),
                ),
              ),
              SizedBox(width: hoppin.spacing.md),
              Flexible(
                child: Text(
                  value,
                  textAlign: TextAlign.end,
                  style: hoppin.type.bodyMedium.copyWith(color: colors.textHi),
                ),
              ),
            ],
          ),
        ),
        if (divider) Divider(height: 1, color: colors.hairline),
      ],
    );
  }
}

String? _present(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

String _formatDate(DateTime value) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${value.day} ${months[value.month - 1]} ${value.year}';
}
