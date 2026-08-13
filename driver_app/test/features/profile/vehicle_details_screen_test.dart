import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/features/profile/vehicle_details_screen.dart';
import 'package:hoppin_shared/hoppin_shared.dart';
import 'package:hoppin_ui/hoppin_ui.dart';

void main() {
  final vehicle = DriverVehicle(
    id: 'vehicle-1',
    make: 'Toyota',
    model: 'Prius',
    year: 2022,
    licensePlate: 'WH12 ABC',
    color: 'Silver',
    passengerCapacity: 4,
    insuranceProvider: 'Acme Cover',
    insuranceExpiry: DateTime(2027, 8, 13),
  );

  Future<void> pump(
    WidgetTester tester, {
    DriverVehicle? value,
    Object? error,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          driverRepositoryProvider.overrideWithValue(
            _VehicleRepository(value: value, error: error),
          ),
        ],
        child: MaterialApp(
          theme: HoppinTheme.driverDark(),
          home: const DriverVehicleDetailsScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('renders the registered vehicle returned by the backend', (
    tester,
  ) async {
    await pump(tester, value: vehicle);

    expect(find.byKey(DriverVehicleDetailsKeys.loaded), findsOneWidget);
    expect(find.text('Toyota Prius'), findsOneWidget);
    expect(find.byType(PlateChip), findsOneWidget);
    expect(find.text('WH12 ABC'), findsOneWidget);
    expect(find.text('2022'), findsOneWidget);
    expect(find.text('Silver'), findsOneWidget);
    expect(find.text('4 passengers'), findsOneWidget);
    expect(find.text('Acme Cover'), findsOneWidget);
    expect(find.text('13 Aug 2027'), findsOneWidget);
  });

  testWidgets('renders the backend not-found state without invented details', (
    tester,
  ) async {
    await pump(tester);

    expect(find.byKey(DriverVehicleDetailsKeys.empty), findsOneWidget);
    expect(find.text('No vehicle registered'), findsOneWidget);
    expect(find.byType(PlateChip), findsNothing);
  });

  testWidgets('renders a retryable error instead of an empty state', (
    tester,
  ) async {
    await pump(
      tester,
      error: const ApiException(
        statusCode: 500,
        message: 'database unavailable',
        code: 'INTERNAL',
      ),
    );

    expect(find.byKey(DriverVehicleDetailsKeys.error), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('No vehicle registered'), findsNothing);
  });
}

class _VehicleRepository implements DriverRepository {
  const _VehicleRepository({this.value, this.error});

  final DriverVehicle? value;
  final Object? error;

  @override
  Future<DriverVehicle?> vehicle() async {
    if (error != null) throw error!;
    return value;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
