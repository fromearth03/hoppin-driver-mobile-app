import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_shared/hoppin_shared.dart';

/// A picker that answers with whatever the test scripted — no MethodChannel,
/// no plugin. This is why the seam exists.
class _FakePicker implements AvatarPicker {
  _FakePicker(this._result, {this.throws = false});

  final PickedAvatar? _result;
  final bool throws;
  int calls = 0;

  @override
  Future<PickedAvatar?> pickAvatar({bool fromCamera = false}) async {
    calls++;
    if (throws) throw Exception('permission denied');
    return _result;
  }
}

/// A repository that records what it was asked to upload and answers with a
/// scripted result or failure.
class _FakeProfileRepo implements ProfileRepository {
  _FakeProfileRepo({this.url = 'https://api.hoppin.tech/a.jpg', this.error});

  final String url;
  final ApiException? error;
  int uploads = 0;

  @override
  Future<String> uploadAvatar({
    required List<int> bytes,
    required String filename,
  }) async {
    uploads++;
    if (error != null) throw error!;
    return url;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('not needed for these tests');
}

ProviderContainer harness(_FakePicker picker, _FakeProfileRepo repo) {
  final c = ProviderContainer(overrides: [
    avatarPickerProvider.overrideWithValue(picker),
    profileRepositoryProvider.overrideWithValue(repo),
  ]);
  addTearDown(c.dispose);
  return c;
}

const _picked = (bytes: <int>[1, 2, 3], filename: 'me.jpg');

void main() {
  group('AvatarUploadController', () {
    test('a successful pick uploads and exposes the returned URL', () async {
      final picker = _FakePicker(_picked);
      final repo = _FakeProfileRepo(url: 'https://api.hoppin.tech/new.jpg');
      final c = harness(picker, repo);

      await c.read(avatarUploadControllerProvider.notifier).pickAndUpload();

      final state = c.read(avatarUploadControllerProvider);
      expect(state, isA<AvatarUploaded>());
      expect((state as AvatarUploaded).url, 'https://api.hoppin.tech/new.jpg');
      expect(repo.uploads, 1);
    });

    test('backing out of the picker is NOT an error', () async {
      // Cancelling must leave the screen exactly as it was. Showing a failure
      // for a deliberate cancel trains users to distrust real errors.
      final picker = _FakePicker(null);
      final repo = _FakeProfileRepo();
      final c = harness(picker, repo);
      c.read(avatarUploadControllerProvider.notifier).seed('https://old.jpg');

      await c.read(avatarUploadControllerProvider.notifier).pickAndUpload();

      final state = c.read(avatarUploadControllerProvider);
      expect(state, isA<AvatarIdle>());
      expect((state as AvatarIdle).url, 'https://old.jpg',
          reason: 'a cancel must not discard the photo already on file');
      expect(repo.uploads, 0, reason: 'nothing was picked, so nothing uploads');
    });

    test('a denied photo permission reads as permission, not upload failure',
        () async {
      final picker = _FakePicker(null, throws: true);
      final repo = _FakeProfileRepo();
      final c = harness(picker, repo);

      await c.read(avatarUploadControllerProvider.notifier).pickAndUpload();

      final state = c.read(avatarUploadControllerProvider);
      expect(state, isA<AvatarUploadFailed>());
      expect((state as AvatarUploadFailed).message, contains('permission'));
      expect(repo.uploads, 0);
    });

    test('an oversized photo is refused WITHOUT spending the upload', () async {
      final picker = _FakePicker((
        bytes: List<int>.filled(ProfileRepository.maxAvatarBytes + 1, 0),
        filename: 'huge.jpg',
      ));
      final repo = _FakeProfileRepo();
      final c = harness(picker, repo);

      await c.read(avatarUploadControllerProvider.notifier).pickAndUpload();

      expect(c.read(avatarUploadControllerProvider), isA<AvatarUploadFailed>());
      expect(repo.uploads, 0,
          reason: 'the server would reject it — do not spend the request, or '
              'the user waits out a doomed upload on mobile data');
    });

    test('FILE_TOO_LARGE from the server names the real limit', () async {
      final c = harness(
        _FakePicker(_picked),
        _FakeProfileRepo(
          error: const ApiException(
            statusCode: 413,
            message: 'too big',
            code: 'FILE_TOO_LARGE',
          ),
        ),
      );

      await c.read(avatarUploadControllerProvider.notifier).pickAndUpload();

      final state = c.read(avatarUploadControllerProvider) as AvatarUploadFailed;
      expect(state.message, contains('8 MB'));
    });

    test('STORAGE_DISABLED does NOT tell the user to try again', () async {
      // The bucket is unconfigured server-side. Retrying cannot help, so the
      // copy must not send the user round a loop that can only fail.
      final c = harness(
        _FakePicker(_picked),
        _FakeProfileRepo(
          error: const ApiException(
            statusCode: 503,
            message: 'storage not configured',
            code: 'STORAGE_DISABLED',
          ),
        ),
      );

      await c.read(avatarUploadControllerProvider.notifier).pickAndUpload();

      final state = c.read(avatarUploadControllerProvider) as AvatarUploadFailed;
      expect(state.message.toLowerCase(), isNot(contains('try again')));
    });

    test('a 200 with an empty URL is a failure, not a false success', () async {
      final c = harness(_FakePicker(_picked), _FakeProfileRepo(url: ''));

      await c.read(avatarUploadControllerProvider.notifier).pickAndUpload();

      expect(c.read(avatarUploadControllerProvider), isA<AvatarUploadFailed>(),
          reason: 'claiming success while still showing the old photo is the '
              'quiet lie this whole surface exists to avoid');
    });
  });
}
