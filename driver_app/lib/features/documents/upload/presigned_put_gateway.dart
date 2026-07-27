import 'package:dio/dio.dart';

/// The ONE place document bytes leave this app.
///
/// 🔴 IT DOES NOT USE `ApiClient`, AND THAT IS THE ENTIRE POINT.
///
/// `ApiClient` (`hoppin_shared/src/api/api_client.dart:20-38`) does three things
/// to every request that passes through it, and each one, on its own, breaks a
/// presigned PUT:
///
///  1. It attaches `Authorization: Bearer <supabase token>` from a Dio
///     interceptor. A presigned S3/GCS URL signs a **specific set of headers**,
///     and `Authorization` is **not in that set** — sending one invalidates the
///     signature and the bucket answers **403**. The failure looks exactly like
///     an auth failure, so the instinctive fix (refresh the token, retry)
///     reproduces it forever, and the driver — who is holding a photograph of
///     their DVLA licence and has done nothing wrong — is simply stuck.
///  2. It pins `Content-Type: application/json`. The content type is **signed
///     too**, byte for byte.
///  3. It pins a `baseUrl` of `:8080`. The presigned URL is an absolute URL to
///     someone else's host entirely.
///
/// So this gateway constructs its **own `Dio()` with ZERO interceptors** and
/// sets exactly ONE meaningful header. Not a flag on the shared client that says
/// "skip the bearer this time" — a flag can be forgotten by the next person, and
/// forgetting it is silent. A **separate client cannot be forgotten**: there is
/// nowhere here for a bearer to come from.
///
/// `presigned_put_test.dart` asserts all three properties, including a source
/// grep of this very file.
abstract class PresignedPutGateway {
  /// PUT [bytes] to [uploadUrl] with exactly [contentType].
  ///
  /// 🔴 [uploadUrl] IS A BEARER CREDENTIAL. It grants **write access to our
  /// storage bucket**, to **anyone who holds it**, for **five minutes**. It must
  /// not reach a log, an analytics event, a crash breadcrumb, or a user-visible
  /// string. Implementations MUST sanitise every error before it escapes —
  /// `DioException.toString()` prints `requestOptions.uri`, signature and all.
  ///
  /// Throws [UploadFailure] — and nothing else — on any failure.
  Future<void> put({
    required String uploadUrl,
    required List<int> bytes,
    required String contentType,
  });
}

/// A sanitised upload failure. It carries a status and **nothing else** — no
/// URI, no headers, no Dio object, nothing that could be printed into a leak.
///
/// This is why the gateway does not simply rethrow. `friendlyErrorMessage()`
/// happens to answer a generic string for a bare `DioException` today, but that
/// is a property of *that* helper, not a property of the exception — and the
/// exception is the thing that travels. Anything that ever calls `toString()` on
/// it (a logger, a `Text('$e')`, a crash reporter) would print the credential.
class UploadFailure implements Exception {
  const UploadFailure(this.statusCode);

  /// The storage backend's status, or `0` for a transport failure.
  ///
  /// `403` is overwhelmingly the interesting one: it means the signature did
  /// not validate, which in practice means a header we sent was not one the
  /// server signed.
  final int statusCode;

  @override
  String toString() => 'UploadFailure($statusCode)'; // never a URL
}

/// The live gateway: a bare [Dio], no interceptors, one header.
class DioPresignedPutGateway implements PresignedPutGateway {
  /// [dio] is injectable **for tests only** — production always gets the bare
  /// one. Nothing in this app may pass `ApiClient`'s Dio in here; there is a
  /// source assertion in `presigned_put_test.dart` that this file never so much
  /// as names it.
  DioPresignedPutGateway({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  @override
  Future<void> put({
    required String uploadUrl,
    required List<int> bytes,
    required String contentType,
  }) async {
    try {
      final res = await _dio.put<void>(
        uploadUrl,
        // A byte stream, deliberately. Hand Dio a `String` and it appends
        // `; charset=utf-8` to the content type for you — which breaks the
        // signature exactly as thoroughly as the bearer does.
        data: Stream<List<int>>.fromIterable([bytes]),
        options: Options(
          headers: <String, Object>{
            // EXACTLY what the slot asked for. Not a variant, not a guess.
            Headers.contentTypeHeader: contentType,
            // Required when the body is a stream: Dio cannot infer the length,
            // and S3/GCS reject a chunked PUT against a presigned URL.
            Headers.contentLengthHeader: bytes.length,
          },
          responseType: ResponseType.plain,
          validateStatus: (s) => s != null && s >= 200 && s < 300,
        ),
      );
      if (res.statusCode == null) throw const UploadFailure(0);
    } on DioException catch (e) {
      // 🔴 SANITISE. `e` carries `requestOptions.uri` — the presigned URL —
      // and prints it from toString(). Rethrowing it, logging it, or feeding it
      // to a message helper leaks a live write credential to our storage
      // bucket. The status is the only thing worth keeping and the only thing
      // that leaves.
      throw UploadFailure(e.response?.statusCode ?? 0);
    }
  }
}
