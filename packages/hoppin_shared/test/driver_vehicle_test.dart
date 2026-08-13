import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_shared/hoppin_shared.dart';

import 'support/fake_auth_service.dart';
import 'support/scripted_http_adapter.dart';

void main() {
  const payload = <String, dynamic>{
    'id': 'vehicle-1',
    'make': 'Toyota',
    'model': 'Prius',
    'year': 2022,
    'license_plate': 'WH12 ABC',
    'color': 'Silver',
    'passenger_capacity': 4,
    'insurance_provider': 'Acme Cover',
    'insurance_expiry': '2027-08-13',
  };

  DriverRepository repository(Map<String, List<ScriptedReply>> script) {
    final dio = Dio()..httpClientAdapter = ScriptedHttpAdapter(script);
    return DriverRepository(ApiClient(auth: FakeAuthService(), dio: dio));
  }

  test('parses every field served by the vehicle endpoint', () {
    final vehicle = DriverVehicle.fromJson(payload);

    expect(vehicle.id, 'vehicle-1');
    expect(vehicle.make, 'Toyota');
    expect(vehicle.model, 'Prius');
    expect(vehicle.year, 2022);
    expect(vehicle.licensePlate, 'WH12 ABC');
    expect(vehicle.color, 'Silver');
    expect(vehicle.passengerCapacity, 4);
    expect(vehicle.insuranceProvider, 'Acme Cover');
    expect(vehicle.insuranceExpiry, DateTime(2027, 8, 13));
  });

  test('nullable and blank optional fields remain absent', () {
    final vehicle = DriverVehicle.fromJson({
      ...payload,
      'year': null,
      'color': '',
      'insurance_provider': '',
      'insurance_expiry': null,
    });

    expect(vehicle.year, isNull);
    expect(vehicle.color, isEmpty);
    expect(vehicle.insuranceProvider, isEmpty);
    expect(vehicle.insuranceExpiry, isNull);
  });

  test('vehicle reads GET /drivers/me/vehicle', () async {
    final result = await repository({
      '/drivers/me/vehicle': [ScriptedReply.ok(payload)],
    }).vehicle();

    expect(result, isNotNull);
    expect(result!.licensePlate, 'WH12 ABC');
  });

  test('VEHICLE_NOT_FOUND is the normal empty state', () async {
    final result = await repository({
      '/drivers/me/vehicle': [
        const ScriptedReply(404, {
          'error': 'no vehicle registered yet',
          'code': 'VEHICLE_NOT_FOUND',
        }),
      ],
    }).vehicle();

    expect(result, isNull);
  });

  test('other endpoint failures are not mistaken for no vehicle', () async {
    final future = repository({
      '/drivers/me/vehicle': [
        const ScriptedReply(500, {
          'error': 'database unavailable',
          'code': 'INTERNAL',
        }),
      ],
    }).vehicle();

    await expectLater(
      future,
      throwsA(
        isA<ApiException>().having(
          (error) => error.statusCode,
          'statusCode',
          500,
        ),
      ),
    );
  });
}
