import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/core/api/api_client.dart';
import 'package:hoppin_driver/core/result.dart';
import 'package:hoppin_driver/features/onboarding/data/models/onboarding_status.dart';
import 'package:hoppin_driver/features/onboarding/data/onboarding_repository.dart';
import 'package:mocktail/mocktail.dart';

class MockApi extends Mock implements ApiClient {}

/// The response GET /drivers/me/onboarding really builds, field for field.
Map<String, dynamic> liveStatus({String status = 'pending_approval'}) => {
      'status': status,
      'can_operate': false,
      'account_status': 'pending',
      'steps': {
        'profile': true,
        'license': true,
        'vehicle': true,
        'vehicle_compliance': false,
        'payout': false,
        'credentials_count': 2,
        'documents': {'approved': 2, 'pending': 3, 'rejected': 1},
      },
      'documents': [
        {
          'type': 'mot_certificate',
          'status': 'rejected',
          'rejection_reason': 'The expiry date is not legible.',
        },
        {'type': 'insurance_policy', 'status': 'pending_review',
         'rejection_reason': ''},
      ],
      'message': 'Your application is under review.',
    };

void main() {
  late MockApi api;
  late OnboardingRepository repo;

  setUp(() {
    api = MockApi();
    repo = OnboardingRepository(api);
  });

  group('status', () {
    test('reads the checklist the service sends', () async {
      when(() => api.get<Map<String, dynamic>>(any()))
          .thenAnswer((_) async => Ok(liveStatus()));

      final o = (await repo.status()).valueOrNull!;

      expect(o.status, OnboardingStatus.pendingApproval);
      expect(o.canOperate, isFalse);
      expect(o.steps.vehicle, isTrue);
      expect(o.steps.vehicleCompliance, isFalse);
      expect(o.steps.credentialsCount, 2);
      expect(o.steps.documentsRejected, 1);
    });

    test('an unknown status never reads as active', () async {
      when(() => api.get<Map<String, dynamic>>(any()))
          .thenAnswer((_) async => Ok(liveStatus(status: 'something_new')));

      final o = (await repo.status()).valueOrNull!;

      // Telling a pending driver they are approved would send them online to
      // be refused at the first offer.
      expect(o.isActive, isFalse);
      expect(o.status, OnboardingStatus.pendingApproval);
    });

    test('surfaces a rejection in the admin own words', () async {
      when(() => api.get<Map<String, dynamic>>(any()))
          .thenAnswer((_) async => Ok(liveStatus()));

      final rejected = (await repo.status()).valueOrNull!.rejectedDocuments;

      expect(rejected.single.type, 'mot_certificate');
      expect(rejected.single.rejectionReason, 'The expiry date is not legible.');
    });

    test('counts only the steps a driver can finish themselves', () async {
      when(() => api.get<Map<String, dynamic>>(any()))
          .thenAnswer((_) async => Ok(liveStatus()));

      final steps = (await repo.status()).valueOrNull!.steps;

      // profile, license, vehicle, credentials, documents — but not
      // vehicle_compliance or payout. Approval is an admin's call and is
      // never counted as a step.
      expect(steps.completed, 5);
      expect(steps.total, 7);
    });
  });

  group('license', () {
    test('sends the licence number to the onboarding patch', () async {
      when(() => api.patch<dynamic>(any(), body: any(named: 'body')))
          .thenAnswer((_) async => const Ok({'status': 'updated'}));

      await repo.saveLicense(
          licenseNumber: '  SMITH901234AB9CD  ', address: '12 High St');

      final body = verify(() => api.patch<dynamic>('/drivers/me/onboarding',
              body: captureAny(named: 'body')))
          .captured
          .single as Map<String, dynamic>;
      expect(body['license_number'], 'SMITH901234AB9CD');
      expect(body['address'], '12 High St');
    });
  });

  group('credentials', () {
    test('sends a plain ISO date, which is all the server parses', () async {
      when(() => api.post<dynamic>(any(), body: any(named: 'body')))
          .thenAnswer((_) async => const Ok({'status': 'saved'}));

      await repo.saveCredential(
        type: 'wolverhampton_taxi_badge',
        number: 'WV-12345',
        expiresAt: DateTime.utc(2028, 1, 31),
      );

      final body = verify(() => api.post<dynamic>('/drivers/me/credentials',
              body: captureAny(named: 'body')))
          .captured
          .single as Map<String, dynamic>;
      // A full RFC3339 timestamp is rejected: the handler parses 2006-01-02.
      expect(body['expires_at'], '2028-01-31');
      expect(body['type'], 'wolverhampton_taxi_badge');
    });

    test('omits an empty share code rather than sending a blank', () async {
      when(() => api.post<dynamic>(any(), body: any(named: 'body')))
          .thenAnswer((_) async => const Ok({'status': 'saved'}));

      await repo.saveCredential(
          type: 'right_to_work', number: 'X1', shareCode: '   ');

      final body = verify(() => api.post<dynamic>(any(),
              body: captureAny(named: 'body')))
          .captured
          .single as Map<String, dynamic>;
      expect(body.containsKey('share_code'), isFalse);
    });
  });

  group('vehicle', () {
    test('carries the compliance dates the sweep reads', () async {
      when(() => api.post<dynamic>(any(), body: any(named: 'body')))
          .thenAnswer((_) async => const Ok({'status': 'ok'}));

      await repo.saveVehicle(
        make: 'Toyota',
        model: 'Prius',
        licensePlate: 'WV21 ABC',
        color: 'Grey',
        year: 2021,
        passengerCapacity: 4,
        insuranceProvider: 'Aviva',
        insuranceExpiry: DateTime.utc(2027, 3, 1),
        motExpiry: DateTime.utc(2027, 2, 15),
        cazCompliant: true,
      );

      final body = verify(() => api.post<dynamic>('/drivers/me/vehicle',
              body: captureAny(named: 'body')))
          .captured
          .single as Map<String, dynamic>;
      expect(body['mot_expiry'], '2027-02-15');
      expect(body['insurance_expiry'], '2027-03-01');
      expect(body['caz_compliant'], isTrue);
    });
  });
}
