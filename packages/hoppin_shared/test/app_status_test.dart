import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_shared/hoppin_shared.dart';

import 'support/fake_auth_service.dart';

/// The launch gate — `GET /app-status`. The model resolves the operator's three
/// flags into one ordered decision; the repo degrades to "proceed" on any
/// failure so a dropped launch check never locks a user out.
void main() {
  group('AppStatus.gate precedence', () {
    test('maintenance outranks everything', () {
      const s = AppStatus(
        maintenanceMode: true,
        forceUpdateRequired: true,
        updateAvailable: true,
      );
      expect(s.gate, AppGate.maintenance);
    });

    test('force update outranks a soft nudge', () {
      const s = AppStatus(forceUpdateRequired: true, updateAvailable: true);
      expect(s.gate, AppGate.forceUpdate);
    });

    test('a soft nudge when only update is available', () {
      const s = AppStatus(updateAvailable: true);
      expect(s.gate, AppGate.updateAvailable);
    });

    test('ok when nothing is set', () {
      expect(const AppStatus().gate, AppGate.ok);
      expect(AppStatus.unknown.gate, AppGate.ok,
          reason: 'the unknown/failure default must proceed, never block');
    });
  });

  group('AppStatus.fromJson', () {
    test('round-trips the live shape', () {
      final s = AppStatus.fromJson(const {
        'maintenance_mode': false,
        'force_update_required': true,
        'update_available': true,
        'minimum_required_version': '1.2.0',
        'latest_version': '1.5.0',
      });
      expect(s.forceUpdateRequired, isTrue);
      expect(s.minimumRequiredVersion, '1.2.0');
      expect(s.latestVersion, '1.5.0');
      expect(s.gate, AppGate.forceUpdate);
    });

    test('missing flags default to false (nothing gated)', () {
      expect(AppStatus.fromJson(const {}).gate, AppGate.ok);
    });
  });

  group('RidesRepository.appStatus', () {
    test('a 500 degrades to unknown → proceed, never blocks launch', () async {
      final dio = Dio()..httpClientAdapter = _StatusAdapter(status: 500);
      final repo = RidesRepository(ApiClient(auth: FakeAuthService(), dio: dio));

      final s = await repo.appStatus(platform: 'android', version: '0.1.0');

      expect(s.gate, AppGate.ok,
          reason: 'a server error at launch must not lock the user out');
    });

    test('a maintenance response gates', () async {
      final dio = Dio()
        ..httpClientAdapter = _StatusAdapter(
          status: 200,
          body: '{"maintenance_mode":true,"force_update_required":false,'
              '"update_available":false}',
        );
      final repo = RidesRepository(ApiClient(auth: FakeAuthService(), dio: dio));

      final s = await repo.appStatus(platform: 'ios', version: '0.1.0');

      expect(s.gate, AppGate.maintenance);
    });
  });
}

class _StatusAdapter implements HttpClientAdapter {
  _StatusAdapter({required this.status, this.body = '{}'});
  final int status;
  final String body;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      body,
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
