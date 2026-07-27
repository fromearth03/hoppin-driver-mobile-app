import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_shared/hoppin_shared.dart';

import 'support/fake_auth_service.dart';

/// Avatar upload contract acceptance for `POST /me/avatar/upload`.
///
/// The route is multipart with field name `file`. The one thing that can break
/// it silently is the client's default `Content-Type: application/json` header
/// overriding the multipart boundary — the server then cannot parse the body
/// and answers VALIDATION_FAILED, which reads to a user as "my photo won't
/// upload" with nothing in the logs pointing at the header.
class _CapturingAdapter implements HttpClientAdapter {
  RequestOptions? captured;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    captured = options;
    return ResponseBody.fromString(
      '{"avatar_url":"https://api.hoppin.tech/api/v1/images/avatars/users/u/1.jpg"}',
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late Dio dio;
  late _CapturingAdapter adapter;
  late ProfileRepository repo;

  setUp(() {
    dio = Dio();
    adapter = _CapturingAdapter();
    dio.httpClientAdapter = adapter;
    repo = ProfileRepository(ApiClient(auth: FakeAuthService(), dio: dio));
  });

  test('posts multipart to /me/avatar/upload and returns avatar_url', () async {
    final url = await repo.uploadAvatar(
      bytes: const [1, 2, 3, 4],
      filename: 'me.jpg',
    );

    expect(adapter.captured!.path, '/me/avatar/upload');
    expect(adapter.captured!.method, 'POST');
    expect(adapter.captured!.data, isA<FormData>());
    expect(
      url,
      'https://api.hoppin.tech/api/v1/images/avatars/users/u/1.jpg',
    );
  });

  test('sends a multipart content-type, not the client JSON default', () async {
    await repo.uploadAvatar(bytes: const [1, 2, 3], filename: 'me.jpg');

    final contentType =
        adapter.captured!.headers[Headers.contentTypeHeader] as String?;
    expect(
      contentType,
      contains('multipart/form-data'),
      reason: 'a JSON content-type here means the server cannot find the '
          'boundary and the upload fails as VALIDATION_FAILED',
    );
  });

  test('the file part is named "file" — the field the server reads', () async {
    await repo.uploadAvatar(bytes: const [1, 2, 3], filename: 'me.jpg');

    final form = adapter.captured!.data as FormData;
    expect(form.files.map((f) => f.key), contains('file'));
    expect(form.files.first.value.filename, 'me.jpg');
  });
}
