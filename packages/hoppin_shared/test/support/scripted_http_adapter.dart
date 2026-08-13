import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// A Dio [HttpClientAdapter] fake that scripts a fixed sequence of responses
/// per request path — no network, fully deterministic.
///
/// The repo has always used fake *repositories*; the 401→refresh→retry
/// interceptor lives BELOW the repository layer, so it can only be exercised by
/// faking Dio's transport. This is that missing fixture.
///
/// Give it a [script] keyed by request path. Each entry is a list of canned
/// [ScriptedReply]s consumed in order — the Nth call to that path returns the
/// Nth reply (the last reply repeats once the list is exhausted, so a
/// `[401, 200]` script self-heals on retry).
class ScriptedHttpAdapter implements HttpClientAdapter {
  ScriptedHttpAdapter(this.script);

  /// path → ordered replies. Query strings are stripped before matching.
  final Map<String, List<ScriptedReply>> script;

  /// How many times each path has been fetched — the interceptor's retry shows
  /// up here as a second hit on the same path.
  final Map<String, int> callCounts = {};

  /// Every path fetched, in order (handy for asserting request ordering).
  final List<String> requestLog = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.path.split('?').first;
    requestLog.add(path);
    final index = callCounts[path] ?? 0;
    callCounts[path] = index + 1;

    final replies = script[path];
    if (replies == null || replies.isEmpty) {
      return ResponseBody.fromString(
        jsonEncode({'error': 'no script for $path', 'code': 'NO_SCRIPT'}),
        404,
        headers: _jsonHeaders,
      );
    }

    final reply = index < replies.length ? replies[index] : replies.last;
    return ResponseBody.fromString(
      jsonEncode(reply.body),
      reply.statusCode,
      headers: _jsonHeaders,
    );
  }

  @override
  void close({bool force = false}) {}

  static const _jsonHeaders = {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  };
}

/// One canned HTTP reply in a [ScriptedHttpAdapter] script.
class ScriptedReply {
  const ScriptedReply(this.statusCode, this.body);

  /// A 401 `{error, code: AUTH_REQUIRED}` — the token-expired signal the
  /// interceptor refreshes on.
  factory ScriptedReply.authRequired() => const ScriptedReply(
        401,
        {'error': 'Token expired', 'code': 'AUTH_REQUIRED'},
      );

  /// A 401 `{error, code: SESSION_REPLACED}` — another device stole the login.
  factory ScriptedReply.sessionReplaced() => const ScriptedReply(
        401,
        {
          'error': 'signed in on another device',
          'code': 'SESSION_REPLACED',
        },
      );

  /// A 200 `{ok: true}` — the healed retry.
  factory ScriptedReply.ok([Map<String, dynamic>? body]) =>
      ScriptedReply(200, body ?? {'ok': true});

  final int statusCode;
  final Map<String, dynamic> body;
}
