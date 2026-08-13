import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_shared/hoppin_shared.dart';

import 'support/fake_auth_service.dart';
import 'support/scripted_http_adapter.dart';

String fakeJwt({String sessionId = 'sess-1'}) {
  String b64(String s) =>
      base64Url.encode(utf8.encode(s)).replaceAll('=', '');
  return '${b64('{"alg":"none"}')}.${b64('{"session_id":"$sessionId"}')}.sig';
}

/// AUTH-03 — the self-healing bearer.
///
/// The interceptor is the race-safety net atop Supabase's own auto-refresh:
/// when a call fires with a token that expired between the SDK's timed
/// refreshes, one 401 must trigger exactly ONE refresh and a single retry that
/// succeeds; N concurrent 401s must share that ONE refresh (no refresh-token
/// reuse storm); and a refresh that throws must sign the rider out with the
/// original error surfacing.
void main() {
  /// Wires an [ApiClient] onto a Dio whose transport is the scripted adapter,
  /// so no network is ever touched.
  ({ApiClient api, ScriptedHttpAdapter adapter}) build(
    FakeAuthService auth,
    Map<String, List<ScriptedReply>> script,
  ) {
    final adapter = ScriptedHttpAdapter(script);
    final dio = Dio()..httpClientAdapter = adapter;
    return (api: ApiClient(auth: auth, dio: dio), adapter: adapter);
  }

  test('a single 401 triggers exactly ONE refresh then a 200 retry', () async {
    final auth = FakeAuthService();
    final built = build(auth, {
      '/guarded': [ScriptedReply.authRequired(), ScriptedReply.ok()],
    });

    final res = await built.api.get<dynamic>('/guarded');

    expect(res.statusCode, 200);
    expect(auth.refreshCount, 1, reason: 'exactly one refresh');
    expect(auth.signOutCount, 0);
    // First call 401s, the retry (same path) 200s → two hits on the path.
    expect(built.adapter.callCounts['/guarded'], 2);
    // The retry must carry the fresh bearer, not the expired one.
    expect(auth.accessToken, 'fresh-token');
  });

  test('two concurrent 401s share ONE refresh', () async {
    final auth = FakeAuthService();
    final built = build(auth, {
      '/a': [ScriptedReply.authRequired(), ScriptedReply.ok()],
      '/b': [ScriptedReply.authRequired(), ScriptedReply.ok()],
    });

    final results = await Future.wait([
      built.api.get<dynamic>('/a'),
      built.api.get<dynamic>('/b'),
    ]);

    expect(results[0].statusCode, 200);
    expect(results[1].statusCode, 200);
    expect(auth.refreshCount, 1,
        reason: 'concurrent 401s must queue behind a single in-flight refresh');
    expect(auth.signOutCount, 0);
  });

  test('a failed refresh signs out and surfaces the original 401', () async {
    final auth = FakeAuthService(refreshFails: true);
    final built = build(auth, {
      '/guarded': [ScriptedReply.authRequired(), ScriptedReply.ok()],
    });

    ApiException? caught;
    try {
      await built.api.get<dynamic>('/guarded');
    } on ApiException catch (e) {
      caught = e;
    }

    expect(caught, isNotNull, reason: 'the original error must surface');
    expect(caught!.statusCode, 401);
    expect(auth.refreshCount, 1);
    expect(auth.signOutCount, 1, reason: 'refresh failure → signOut');
    // No successful retry happened — only the initial 401 hit the wire.
    expect(built.adapter.callCounts['/guarded'], 1);
  });

  test('claims session_id once before the first API call', () async {
    final auth = FakeAuthService(initialToken: fakeJwt());
    final built = build(auth, {
      '/me/session': [ScriptedReply.ok({'message': 'ok'})],
      '/guarded': [ScriptedReply.ok()],
    });

    final res = await built.api.get<dynamic>('/guarded');

    expect(res.statusCode, 200);
    expect(built.adapter.callCounts['/me/session'], 1);
    expect(built.adapter.callCounts['/guarded'], 1);
    expect(auth.refreshCount, 0);

    await built.api.get<dynamic>('/guarded');
    expect(built.adapter.callCounts['/me/session'], 1,
        reason: 'same session_id must not re-claim');
    expect(built.adapter.callCounts['/guarded'], 2);
  });

  test('SESSION_REPLACED signs out and does NOT refresh', () async {
    final auth = FakeAuthService();
    final built = build(auth, {
      '/guarded': [ScriptedReply.sessionReplaced()],
    });

    ApiException? caught;
    try {
      await built.api.get<dynamic>('/guarded');
    } on ApiException catch (e) {
      caught = e;
    }

    expect(caught, isNotNull);
    expect(caught!.statusCode, 401);
    expect(caught.code, 'SESSION_REPLACED');
    expect(auth.refreshCount, 0, reason: 'dead session must not be refreshed');
    expect(auth.signOutCount, 1);
    expect(built.adapter.callCounts['/guarded'], 1);
  });

  test('a non-401 error is NOT retried and never refreshes', () async {
    final auth = FakeAuthService();
    final built = build(auth, {
      '/boom': [
        const ScriptedReply(500, {'error': 'server', 'code': 'SERVER_ERROR'}),
      ],
    });

    ApiException? caught;
    try {
      await built.api.get<dynamic>('/boom');
    } on ApiException catch (e) {
      caught = e;
    }

    expect(caught!.statusCode, 500);
    expect(auth.refreshCount, 0);
    expect(auth.signOutCount, 0);
    expect(built.adapter.callCounts['/boom'], 1);
  });
}
