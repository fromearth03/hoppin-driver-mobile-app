# Driver App — Batch 6: Compliance Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A driver can see every document and its status, learn exactly why one was rejected, upload a replacement, read their performance stats, see which penalties are affecting their account, and appeal one — reading the reviewer's decision when it comes back.

**Architecture:** Three repositories over the Batch 1 `ApiClient` — documents, stats, appeals — with a controller each. Documents is a bottom-nav tab; Stats is the other. The penalty list and the appeals accordion both live on Stats, since a penalty and its appeal are one story. Uploads use the two-step presigned flow the backend already exposes.

**Tech Stack:** Flutter, Riverpod, Dio, `image_picker`, `file_picker`.

**Spec:** `docs/superpowers/specs/2026-08-30-driver-app-phase1-design.md` §4.7, §4.8

## Global Constraints

- **`rejection_reason` is rendered verbatim.** It is the whole point of A21: without it a driver re-uploads the same file and is rejected again. Never paraphrase it, never substitute a generic message.
- **`review_note` is rendered verbatim** as an appeal's outcome. Admins must supply one on both approve and reject, so a decision arriving without one is a backend bug, not a blank state to design around.
- **Nullable rates render "—", never "0%".** A driver with no offers yet has an unknown acceptance rate, not a zero one.
- **`penalties_count` and the penalty list are both ledger-sourced** (A13 resolved). They cannot disagree, so the count is tappable and opens the list.
- **`trips_cancelled` and `completion_rate` count only cancels the driver made.** The UI says so, because a driver seeing a cancellation count needs to know whose it is.
- **A document with `uploadable: false` shows status only** — `nr3s_background_check` is operator-run, and an upload button on it would be a button that cannot work.
- Light theme tokens only; money is `Pence`.

---

### Task 1: Documents

**Files:**
- Create: `app/lib/features/documents/data/models/driver_document.dart`
- Create: `app/lib/features/documents/data/documents_repository.dart`
- Test: `app/test/features/documents/documents_repository_test.dart`

**Interfaces:**
- Consumes: `ApiClient`, `Result` (Batch 1)
- Produces:
  - `DocumentStatus` enum (`pending`, `approved`, `rejected`, `expired`, `missing`).
  - `DocumentType(code, label, uploadable, expires)`; `DriverDocument(id, documentType, status, uploadedAt, expiresAt, rejectionReason)` with `.isExpiringSoon`, `.needsAction`.
  - `DocumentSlot(type, document)` pairing every known type with the driver's upload, if any.
  - `DocumentsRepository.types()`, `.mine()`, `.slots()`, `.uploadUrl(type)`, `.confirm(...)`.
  - Provider `documentsRepositoryProvider`.

- [ ] **Step 1: Write the failing test**

Create `app/test/features/documents/documents_repository_test.dart`:

```dart
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/core/api/api_client.dart';
import 'package:hoppin_driver/core/auth/token_store.dart';
import 'package:hoppin_driver/features/documents/data/documents_repository.dart';
import 'package:hoppin_driver/features/documents/data/models/driver_document.dart';
import 'package:mocktail/mocktail.dart';

class _MockAdapter extends Mock implements HttpClientAdapter {}

void main() {
  setUpAll(() => registerFallbackValue(RequestOptions(path: '/')));

  ResponseBody body(String json, int status) =>
      ResponseBody.fromString(json, status, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      });

  late _MockAdapter adapter;
  late DocumentsRepository repo;

  setUp(() {
    adapter = _MockAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    repo = DocumentsRepository(ApiClient(dio, InMemoryTokenStore()));
  });

  group('DriverDocument', () {
    test('carries the rejection reason so a re-upload can succeed', () {
      final d = DriverDocument.fromJson({
        'id': 'd1',
        'document_type': 'vehicle_insurance',
        'verification_status': 'rejected',
        'uploaded_at': '2026-08-01T10:00:00Z',
        'rejection_reason': 'The photo was too blurry to read the expiry date.',
      });

      expect(d.status, DocumentStatus.rejected);
      // Without this the driver re-uploads the same file and is rejected
      // again — the loop A21 existed to break.
      expect(d.rejectionReason,
          'The photo was too blurry to read the expiry date.');
      expect(d.needsAction, isTrue);
    });

    test('an approved document needs nothing', () {
      final d = DriverDocument.fromJson({
        'id': 'd2',
        'document_type': 'dbs_check',
        'verification_status': 'approved',
        'uploaded_at': '2026-08-01T10:00:00Z',
        'expires_at': '2027-08-01T10:00:00Z',
      });

      expect(d.needsAction, isFalse);
      expect(d.isExpiringSoon, isFalse);
    });

    test('flags a document expiring within thirty days', () {
      final soon = DateTime.now().add(const Duration(days: 20));
      final d = DriverDocument.fromJson({
        'id': 'd3',
        'document_type': 'mot_certificate',
        'verification_status': 'approved',
        'uploaded_at': '2026-01-01T10:00:00Z',
        'expires_at': soon.toIso8601String(),
      });

      expect(d.isExpiringSoon, isTrue);
    });

    test('treats an already-expired document as needing action', () {
      final past = DateTime.now().subtract(const Duration(days: 1));
      final d = DriverDocument.fromJson({
        'id': 'd4',
        'document_type': 'vehicle_insurance',
        'verification_status': 'approved',
        'uploaded_at': '2026-01-01T10:00:00Z',
        'expires_at': past.toIso8601String(),
      });

      expect(d.status, DocumentStatus.expired);
      expect(d.needsAction, isTrue);
    });

    test('an unknown status degrades to pending rather than throwing', () {
      final d = DriverDocument.fromJson({
        'id': 'd5',
        'document_type': 'x',
        'verification_status': 'something_new',
        'uploaded_at': '2026-01-01T10:00:00Z',
      });

      expect(d.status, DocumentStatus.pending);
    });
  });

  group('DocumentsRepository', () {
    test('pairs every known type with the driver upload, if any', () async {
      var call = 0;
      when(() => adapter.fetch(any(), any(), any())).thenAnswer((_) async {
        call++;
        return call == 1
            ? body(
                '[{"code":"vehicle_insurance","label":"Vehicle Insurance",'
                '"uploadable":true,"expires":true},'
                '{"code":"nr3s_background_check","label":"Background Check",'
                '"uploadable":false,"expires":false}]',
                200)
            : body(
                '[{"id":"d1","document_type":"vehicle_insurance",'
                '"verification_status":"approved",'
                '"uploaded_at":"2026-08-01T10:00:00Z"}]',
                200);
      });

      final r = await repo.slots();

      expect(r.valueOrNull, hasLength(2));
      expect(r.valueOrNull!.first.document, isNotNull);
      // A type the driver has never uploaded still gets a slot, so the grid
      // shows what is missing rather than silently omitting it.
      expect(r.valueOrNull!.last.document, isNull);
      expect(r.valueOrNull!.last.type.uploadable, isFalse);
    });

    test('an operator-run type is not uploadable', () async {
      when(() => adapter.fetch(any(), any(), any())).thenAnswer((_) async =>
          body('[{"code":"nr3s_background_check","label":"Background Check",'
              '"uploadable":false,"expires":false}]', 200));

      final r = await repo.types();

      expect(r.valueOrNull!.single.uploadable, isFalse);
    });

    test('surfaces STORAGE_DISABLED as retryable', () async {
      when(() => adapter.fetch(any(), any(), any())).thenAnswer((_) async =>
          body('{"code":"STORAGE_DISABLED","error":"bucket down"}', 503));

      final r = await repo.uploadUrl('vehicle_insurance');

      expect(r.errorOrNull!.code, 'STORAGE_DISABLED');
      expect(r.errorOrNull!.isRetryable, isTrue);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/features/documents/`
Expected: FAIL — files do not exist

- [ ] **Step 3: Write the models**

Create `app/lib/features/documents/data/models/driver_document.dart`:

```dart
enum DocumentStatus { pending, approved, rejected, expired, missing }

/// One of the eight document types the platform recognises.
///
/// `uploadable: false` marks an operator-run check (the NR3S background
/// check): the driver can see its status but cannot act on it, so the card
/// shows no upload affordance.
class DocumentType {
  final String code;
  final String label;
  final bool uploadable;
  final bool expires;

  const DocumentType({
    required this.code,
    required this.label,
    this.uploadable = true,
    this.expires = false,
  });

  factory DocumentType.fromJson(Map<String, dynamic> json) {
    final code = (json['code'] ?? json['document_type'] ?? '') as String;
    return DocumentType(
      code: code,
      label: (json['label'] as String?) ?? _humanise(code),
      uploadable: json['uploadable'] as bool? ?? true,
      expires: json['expires'] as bool? ?? false,
    );
  }

  /// Only ever applied to a closed server enum, where title-casing is safe.
  static String _humanise(String code) => code
      .split('_')
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');
}

class DriverDocument {
  final String id;
  final String documentType;
  final DocumentStatus status;
  final DateTime? uploadedAt;
  final DateTime? expiresAt;

  /// Written by an admin when they reject. Rendered verbatim — the reason a
  /// driver cannot fix a rejection is not knowing what was wrong with it.
  final String? rejectionReason;

  const DriverDocument({
    required this.id,
    required this.documentType,
    required this.status,
    this.uploadedAt,
    this.expiresAt,
    this.rejectionReason,
  });

  static const _expiryWarning = Duration(days: 30);

  bool get isExpired =>
      expiresAt != null && DateTime.now().isAfter(expiresAt!);

  bool get isExpiringSoon =>
      expiresAt != null &&
      !isExpired &&
      expiresAt!.difference(DateTime.now()) < _expiryWarning;

  /// True when the driver has something to do about it. Pending review is
  /// deliberately excluded: there is nothing to act on while we check.
  bool get needsAction =>
      status == DocumentStatus.rejected ||
      status == DocumentStatus.expired ||
      status == DocumentStatus.missing;

  factory DriverDocument.fromJson(Map<String, dynamic> json) {
    final expiresAt = json['expires_at'] == null
        ? null
        : DateTime.tryParse(json['expires_at'] as String);
    final raw = (json['verification_status'] as String?) ?? '';
    var status = switch (raw) {
      'approved' || 'verified' => DocumentStatus.approved,
      'rejected' => DocumentStatus.rejected,
      'expired' => DocumentStatus.expired,
      // Anything unrecognised reads as pending: claiming a document is
      // approved when we do not know would be the dangerous error.
      _ => DocumentStatus.pending,
    };
    if (status == DocumentStatus.approved &&
        expiresAt != null &&
        DateTime.now().isAfter(expiresAt)) {
      status = DocumentStatus.expired;
    }

    return DriverDocument(
      id: (json['id'] as String?) ?? '',
      documentType: (json['document_type'] as String?) ?? '',
      status: status,
      uploadedAt: json['uploaded_at'] == null
          ? null
          : DateTime.tryParse(json['uploaded_at'] as String),
      expiresAt: expiresAt,
      rejectionReason: json['rejection_reason'] as String?,
    );
  }
}

/// A type paired with the driver's upload for it, if there is one. Every
/// known type gets a slot so the grid shows gaps rather than hiding them.
class DocumentSlot {
  final DocumentType type;
  final DriverDocument? document;

  const DocumentSlot({required this.type, this.document});

  DocumentStatus get status => document?.status ?? DocumentStatus.missing;
  bool get needsAction => document?.needsAction ?? true;
}
```

- [ ] **Step 4: Write the repository**

Create `app/lib/features/documents/data/documents_repository.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/result.dart';
import 'models/driver_document.dart';

class DocumentsRepository {
  final ApiClient _api;
  DocumentsRepository(this._api);

  Future<Result<List<DocumentType>>> types() async {
    final r = await _api.get<dynamic>('/document-types');
    return r.when(
      ok: (data) => Ok(_list(data, 'document_types')
          .map((e) => DocumentType.fromJson(e))
          .toList()),
      err: (e) => Err(e),
    );
  }

  Future<Result<List<DriverDocument>>> mine() async {
    final r = await _api.get<dynamic>('/drivers/me/documents');
    return r.when(
      ok: (data) => Ok(_list(data, 'documents')
          .map((e) => DriverDocument.fromJson(e))
          .toList()),
      err: (e) => Err(e),
    );
  }

  /// Every known type, paired with the driver's upload for it.
  Future<Result<List<DocumentSlot>>> slots() async {
    final typesResult = await types();
    if (!typesResult.isOk) return Err(typesResult.errorOrNull!);
    final mineResult = await mine();
    if (!mineResult.isOk) return Err(mineResult.errorOrNull!);

    final byType = {
      for (final d in mineResult.valueOrNull!) d.documentType: d,
    };
    return Ok(typesResult.valueOrNull!
        .map((t) => DocumentSlot(type: t, document: byType[t.code]))
        .toList());
  }

  /// Step one of the upload: ask for a presigned destination.
  Future<Result<Map<String, dynamic>>> uploadUrl(String documentType) =>
      _api.post<Map<String, dynamic>>('/drivers/me/documents/upload-url',
          body: {'document_type': documentType});

  /// Step two: tell the server the file landed.
  Future<Result<DriverDocument>> confirm({
    required String documentType,
    required String fileUrl,
    DateTime? expiresAt,
  }) async {
    final r = await _api.post<Map<String, dynamic>>('/drivers/me/documents',
        body: {
          'document_type': documentType,
          'bucket_file_url': fileUrl,
          if (expiresAt != null)
            'expires_at': expiresAt.toUtc().toIso8601String(),
        });
    return r.when(
      ok: (json) => Ok(DriverDocument.fromJson(json)),
      err: (e) => Err(e),
    );
  }

  List<Map<String, dynamic>> _list(dynamic data, String key) {
    final raw = data is Map ? ((data[key] as List?) ?? const []) : (data as List? ?? const []);
    return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }
}

final documentsRepositoryProvider = Provider<DocumentsRepository>(
    (ref) => DocumentsRepository(ref.watch(apiClientProvider)));
```

- [ ] **Step 5: Run test to verify it passes**

Run: `cd app && flutter test test/features/documents/`
Expected: PASS, 8 tests

- [ ] **Step 6: Commit**

```bash
git add app/lib/features/documents app/test/features/documents
git commit -m "feat: add documents with rejection reasons and expiry tracking"
```

---

### Task 2: The Documents screen

**Files:**
- Create: `app/lib/features/documents/logic/documents_controller.dart`
- Create: `app/lib/features/documents/ui/documents_screen.dart`
- Create: `app/lib/features/documents/ui/widgets/document_card.dart`
- Modify: `app/lib/app.dart`
- Test: `app/test/features/documents/documents_screen_test.dart`

**Interfaces:**
- Consumes: `DocumentsRepository` (Task 1)
- Produces: `DocumentsController` (`AsyncNotifier<List<DocumentSlot>>`) with `.refresh()`; `DocumentsScreen`; `DocumentCard(slot, {onTap})`. Replaces the Documents placeholder route.

- [ ] **Step 1: Write the failing test**

Create `app/test/features/documents/documents_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/core/result.dart';
import 'package:hoppin_driver/features/documents/data/documents_repository.dart';
import 'package:hoppin_driver/features/documents/data/models/driver_document.dart';
import 'package:hoppin_driver/features/documents/ui/documents_screen.dart';
import 'package:mocktail/mocktail.dart';

class MockDocsRepo extends Mock implements DocumentsRepository {}

DocumentSlot slot({
  String code = 'vehicle_insurance',
  String label = 'Vehicle Insurance',
  bool uploadable = true,
  DriverDocument? document,
}) =>
    DocumentSlot(
      type: DocumentType(code: code, label: label, uploadable: uploadable),
      document: document,
    );

DriverDocument doc({
  DocumentStatus status = DocumentStatus.approved,
  String? rejectionReason,
  DateTime? expiresAt,
}) =>
    DriverDocument(
      id: 'd1',
      documentType: 'vehicle_insurance',
      status: status,
      rejectionReason: rejectionReason,
      expiresAt: expiresAt,
      uploadedAt: DateTime.now(),
    );

Widget wrap(MockDocsRepo repo) => ProviderScope(
      overrides: [documentsRepositoryProvider.overrideWithValue(repo)],
      child: const MaterialApp(home: DocumentsScreen()),
    );

void main() {
  late MockDocsRepo repo;
  setUp(() => repo = MockDocsRepo());

  testWidgets('shows a rejected document reason verbatim', (tester) async {
    when(() => repo.slots()).thenAnswer((_) async => Ok([
          slot(
              document: doc(
                  status: DocumentStatus.rejected,
                  rejectionReason:
                      'The photo was too blurry to read the expiry date.'))
        ]));

    await tester.pumpWidget(wrap(repo));
    await tester.pumpAndSettle();

    expect(find.text('The photo was too blurry to read the expiry date.'),
        findsOneWidget);
  });

  testWidgets('never substitutes a generic message for a real reason',
      (tester) async {
    when(() => repo.slots()).thenAnswer((_) async => Ok([
          slot(
              document: doc(
                  status: DocumentStatus.rejected,
                  rejectionReason: 'Wrong page uploaded.'))
        ]));

    await tester.pumpWidget(wrap(repo));
    await tester.pumpAndSettle();

    expect(find.text('Wrong page uploaded.'), findsOneWidget);
    expect(find.textContaining('Please try again'), findsNothing);
  });

  testWidgets('a missing document invites an upload', (tester) async {
    when(() => repo.slots())
        .thenAnswer((_) async => Ok([slot(document: null)]));

    await tester.pumpWidget(wrap(repo));
    await tester.pumpAndSettle();

    expect(find.text('Not uploaded'), findsOneWidget);
    expect(find.text('Upload'), findsOneWidget);
  });

  testWidgets('an operator-run document offers no upload', (tester) async {
    when(() => repo.slots()).thenAnswer((_) async => Ok([
          slot(
              code: 'nr3s_background_check',
              label: 'Background Check',
              uploadable: false)
        ]));

    await tester.pumpWidget(wrap(repo));
    await tester.pumpAndSettle();

    expect(find.text('Background Check'), findsOneWidget);
    // The driver cannot supply this one; an Upload button would be a lie.
    expect(find.text('Upload'), findsNothing);
  });

  testWidgets('a document under review offers no action', (tester) async {
    when(() => repo.slots()).thenAnswer(
        (_) async => Ok([slot(document: doc(status: DocumentStatus.pending))]));

    await tester.pumpWidget(wrap(repo));
    await tester.pumpAndSettle();

    expect(find.textContaining('Under review'), findsOneWidget);
    expect(find.text('Upload'), findsNothing);
  });

  testWidgets('warns about a document expiring soon', (tester) async {
    when(() => repo.slots()).thenAnswer((_) async => Ok([
          slot(
              document: doc(
                  expiresAt: DateTime.now().add(const Duration(days: 14))))
        ]));

    await tester.pumpWidget(wrap(repo));
    await tester.pumpAndSettle();

    expect(find.textContaining('Expires'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/features/documents/documents_screen_test.dart`
Expected: FAIL — screen files do not exist

- [ ] **Step 3: Write the controller**

Create `app/lib/features/documents/logic/documents_controller.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/documents_repository.dart';
import '../data/models/driver_document.dart';

class DocumentsController extends AsyncNotifier<List<DocumentSlot>> {
  bool _disposed = false;

  @override
  Future<List<DocumentSlot>> build() async {
    ref.onDispose(() => _disposed = true);
    final result = await ref.read(documentsRepositoryProvider).slots();
    return result.when(
      ok: (slots) => slots,
      err: (e) => throw e,
    );
  }

  Future<void> refresh() async {
    final result = await ref.read(documentsRepositoryProvider).slots();
    if (_disposed) return;
    result.when(
      ok: (slots) => state = AsyncData(slots),
      err: (e) => state = AsyncError(e, StackTrace.current),
    );
  }
}

final documentsControllerProvider =
    AsyncNotifierProvider<DocumentsController, List<DocumentSlot>>(
        DocumentsController.new);
```

- [ ] **Step 4: Write the card and screen**

Create `app/lib/features/documents/ui/widgets/document_card.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/typography.dart';
import '../../data/models/driver_document.dart';

/// One document and what the driver should do about it.
///
/// A rejection shows the admin's reason in full. That single field is the
/// difference between a driver fixing the problem and re-uploading the same
/// file until they call support.
class DocumentCard extends StatelessWidget {
  final DocumentSlot slot;
  final VoidCallback? onUpload;

  const DocumentCard({super.key, required this.slot, this.onUpload});

  (String, Color, IconData) get _statusChip => switch (slot.status) {
        DocumentStatus.approved => ('Approved', AppColors.positive, Icons.check_circle),
        DocumentStatus.pending => ('Under review', AppColors.warning, Icons.schedule),
        DocumentStatus.rejected => ('Not accepted', AppColors.negative, Icons.error),
        DocumentStatus.expired => ('Expired', AppColors.negative, Icons.event_busy),
        DocumentStatus.missing => ('Not uploaded', AppColors.textSecondary, Icons.upload_file),
      };

  @override
  Widget build(BuildContext context) {
    final (label, colour, icon) = _statusChip;
    final document = slot.document;

    // Upload is offered only when the driver can actually supply the file
    // and there is something to do — never while a review is in flight.
    final canUpload = slot.type.uploadable &&
        slot.status != DocumentStatus.pending &&
        slot.status != DocumentStatus.approved;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: slot.needsAction ? AppColors.negative : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(slot.type.label, style: AppText.heading)),
              Icon(icon, size: 16, color: colour),
              const SizedBox(width: 4),
              Text(label, style: AppText.caption.copyWith(color: colour)),
            ],
          ),
          if (document?.rejectionReason != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.negative.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(document!.rejectionReason!, style: AppText.caption),
            ),
          ],
          if (document?.expiresAt != null && document!.rejectionReason == null) ...[
            const SizedBox(height: 6),
            Text(
              'Expires ${DateFormat('d MMM yyyy').format(document.expiresAt!.toLocal())}',
              style: AppText.caption.copyWith(
                color: document.isExpiringSoon || document.isExpired
                    ? AppColors.negative
                    : AppColors.textSecondary,
              ),
            ),
          ],
          if (canUpload) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onUpload,
                child: const Text('Upload'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
```

Create `app/lib/features/documents/ui/documents_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/theme/typography.dart';
import '../../../shared/widgets/app_error_state.dart';
import '../../../shared/widgets/app_loading.dart';
import '../logic/documents_controller.dart';
import 'widgets/document_card.dart';

class DocumentsScreen extends ConsumerWidget {
  const DocumentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(documentsControllerProvider);
    final controller = ref.read(documentsControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Documents')),
      body: async.when(
        loading: () => const AppLoading(),
        error: (e, _) => AppErrorState(
          error: e is ApiException ? e : ApiException('INTERNAL', '', 500),
          onRetry: controller.refresh,
        ),
        data: (slots) {
          final needsAction = slots.where((s) => s.needsAction).length;
          return RefreshIndicator(
            onRefresh: controller.refresh,
            child: ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                if (needsAction > 0)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: Text(
                      needsAction == 1
                          ? 'One document needs your attention'
                          : '$needsAction documents need your attention',
                      style: AppText.heading,
                    ),
                  ),
                const SizedBox(height: 8),
                ...slots.map((slot) => DocumentCard(
                      slot: slot,
                      onUpload: () => _upload(context, slot.type.code),
                    )),
              ],
            ),
          );
        },
      ),
    );
  }

  void _upload(BuildContext context, String documentType) {
    // The presigned two-step upload is wired in Task 3.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Uploading $documentType')),
    );
  }
}
```

- [ ] **Step 5: Register the route**

In `app/lib/app.dart`, replace the Documents placeholder:

```dart
          GoRoute(
              path: Routes.documents,
              builder: (_, __) => const DocumentsScreen()),
```

- [ ] **Step 6: Run test to verify it passes**

Run: `cd app && flutter test test/features/documents/`
Expected: PASS, 14 tests

- [ ] **Step 7: Commit**

```bash
git add app/lib app/test
git commit -m "feat: add the documents screen showing rejection reasons"
```

---

### Task 3: Document upload

**Files:**
- Modify: `app/pubspec.yaml`
- Create: `app/lib/features/documents/logic/upload_controller.dart`
- Create: `app/lib/features/documents/ui/upload_sheet.dart`
- Modify: `app/lib/features/documents/ui/documents_screen.dart`
- Test: `app/test/features/documents/upload_controller_test.dart`

**Interfaces:**
- Consumes: `DocumentsRepository` (Task 1)
- Produces: `UploadState(isUploading, error)`; `UploadController.upload(documentType, bytes, filename, expiresAt)` performing the presign → PUT → confirm sequence; `UploadSheet.show(context, type)`.

- [ ] **Step 1: Add the dependency**

In `app/pubspec.yaml` add to `dependencies`:

```yaml
  image_picker: ^1.1.2
```

Run: `cd app && flutter pub get`

- [ ] **Step 2: Write the failing test**

Create `app/test/features/documents/upload_controller_test.dart`:

```dart
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/core/api/api_exception.dart';
import 'package:hoppin_driver/core/result.dart';
import 'package:hoppin_driver/features/documents/data/documents_repository.dart';
import 'package:hoppin_driver/features/documents/data/models/driver_document.dart';
import 'package:hoppin_driver/features/documents/logic/upload_controller.dart';
import 'package:mocktail/mocktail.dart';

class MockDocsRepo extends Mock implements DocumentsRepository {}

class MockUploader extends Mock implements FileUploader {}

void main() {
  late MockDocsRepo repo;
  late MockUploader uploader;

  setUp(() {
    repo = MockDocsRepo();
    uploader = MockUploader();
  });

  ProviderContainer container() {
    final c = ProviderContainer(overrides: [
      documentsRepositoryProvider.overrideWithValue(repo),
      fileUploaderProvider.overrideWithValue(uploader),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  final bytes = Uint8List.fromList([1, 2, 3]);

  test('presigns, uploads, then confirms — in that order', () async {
    when(() => repo.uploadUrl(any())).thenAnswer((_) async => const Ok({
          'upload_url': 'https://storage/put',
          'file_url': 'https://storage/file.jpg',
        }));
    when(() => uploader.put(any(), any(), any()))
        .thenAnswer((_) async => const Ok(null));
    when(() => repo.confirm(
            documentType: any(named: 'documentType'),
            fileUrl: any(named: 'fileUrl'),
            expiresAt: any(named: 'expiresAt')))
        .thenAnswer((_) async => Ok(DriverDocument(
            id: 'd1',
            documentType: 'vehicle_insurance',
            status: DocumentStatus.pending)));

    final c = container();
    final r = await c
        .read(uploadControllerProvider.notifier)
        .upload('vehicle_insurance', bytes, 'insurance.jpg');

    expect(r.isOk, isTrue);
    verifyInOrder([
      () => repo.uploadUrl('vehicle_insurance'),
      () => uploader.put('https://storage/put', bytes, any()),
      () => repo.confirm(
          documentType: 'vehicle_insurance',
          fileUrl: 'https://storage/file.jpg',
          expiresAt: any(named: 'expiresAt')),
    ]);
  });

  test('does not confirm when the file never reached storage', () async {
    when(() => repo.uploadUrl(any())).thenAnswer((_) async => const Ok({
          'upload_url': 'https://storage/put',
          'file_url': 'https://storage/file.jpg',
        }));
    when(() => uploader.put(any(), any(), any())).thenAnswer(
        (_) async => Err(ApiException('INTERNAL', 'network', 0)));

    final c = container();
    final r = await c
        .read(uploadControllerProvider.notifier)
        .upload('vehicle_insurance', bytes, 'insurance.jpg');

    expect(r.isOk, isFalse);
    // Confirming a file that is not there would leave the driver looking
    // compliant with nothing uploaded.
    verifyNever(() => repo.confirm(
        documentType: any(named: 'documentType'),
        fileUrl: any(named: 'fileUrl'),
        expiresAt: any(named: 'expiresAt')));
  });

  test('surfaces STORAGE_DISABLED without attempting an upload', () async {
    when(() => repo.uploadUrl(any())).thenAnswer(
        (_) async => Err(ApiException('STORAGE_DISABLED', '', 503)));

    final c = container();
    final r = await c
        .read(uploadControllerProvider.notifier)
        .upload('vehicle_insurance', bytes, 'insurance.jpg');

    expect(r.errorOrNull!.code, 'STORAGE_DISABLED');
    verifyNever(() => uploader.put(any(), any(), any()));
  });

  test('passes an expiry date through to the confirm call', () async {
    final expires = DateTime.utc(2027, 6, 1);
    when(() => repo.uploadUrl(any())).thenAnswer((_) async => const Ok({
          'upload_url': 'https://storage/put',
          'file_url': 'https://storage/file.jpg',
        }));
    when(() => uploader.put(any(), any(), any()))
        .thenAnswer((_) async => const Ok(null));
    when(() => repo.confirm(
            documentType: any(named: 'documentType'),
            fileUrl: any(named: 'fileUrl'),
            expiresAt: any(named: 'expiresAt')))
        .thenAnswer((_) async => Ok(DriverDocument(
            id: 'd1',
            documentType: 'vehicle_insurance',
            status: DocumentStatus.pending)));

    final c = container();
    await c.read(uploadControllerProvider.notifier).upload(
        'vehicle_insurance', bytes, 'insurance.jpg',
        expiresAt: expires);

    verify(() => repo.confirm(
        documentType: 'vehicle_insurance',
        fileUrl: 'https://storage/file.jpg',
        expiresAt: expires)).called(1);
  });
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `cd app && flutter test test/features/documents/upload_controller_test.dart`
Expected: FAIL — `upload_controller.dart` does not exist

- [ ] **Step 4: Write the uploader and controller**

Create `app/lib/features/documents/logic/upload_controller.dart`:

```dart
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/result.dart';
import '../data/documents_repository.dart';
import '../data/models/driver_document.dart';

/// PUTs bytes to a presigned URL. Separate from [ApiClient] because the
/// destination is object storage, not the ride service — no auth header, no
/// error envelope.
abstract class FileUploader {
  Future<Result<void>> put(String url, Uint8List bytes, String contentType);
}

class DioFileUploader implements FileUploader {
  final Dio _dio;
  DioFileUploader(this._dio);

  @override
  Future<Result<void>> put(
      String url, Uint8List bytes, String contentType) async {
    try {
      final response = await _dio.put<void>(
        url,
        data: Stream.fromIterable([bytes]),
        options: Options(
          headers: {
            Headers.contentTypeHeader: contentType,
            Headers.contentLengthHeader: bytes.length,
          },
          validateStatus: (_) => true,
        ),
      );
      final status = response.statusCode ?? 500;
      if (status >= 200 && status < 300) return const Ok(null);
      return Err(ApiException('INTERNAL', 'storage rejected the file', status));
    } on DioException catch (e) {
      return Err(ApiException('INTERNAL', e.message ?? 'upload failed', 0));
    }
  }
}

final fileUploaderProvider =
    Provider<FileUploader>((ref) => DioFileUploader(Dio()));

class UploadState {
  final bool isUploading;
  final ApiException? error;
  const UploadState({this.isUploading = false, this.error});
}

class UploadController extends Notifier<UploadState> {
  @override
  UploadState build() => const UploadState();

  static String _contentType(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.pdf')) return 'application/pdf';
    return 'image/jpeg';
  }

  /// Presign, PUT, then confirm — strictly in that order.
  ///
  /// Confirming before the bytes have landed would mark the driver compliant
  /// with nothing in storage, so a failed PUT stops the sequence.
  Future<Result<DriverDocument>> upload(
    String documentType,
    Uint8List bytes,
    String filename, {
    DateTime? expiresAt,
  }) async {
    state = const UploadState(isUploading: true);
    final repo = ref.read(documentsRepositoryProvider);

    final presigned = await repo.uploadUrl(documentType);
    if (!presigned.isOk) {
      state = UploadState(error: presigned.errorOrNull);
      return Err(presigned.errorOrNull!);
    }

    final urls = presigned.valueOrNull!;
    final uploadUrl = (urls['upload_url'] ?? urls['url']) as String;
    final fileUrl = (urls['file_url'] ?? urls['bucket_file_url']) as String;

    final put = await ref
        .read(fileUploaderProvider)
        .put(uploadUrl, bytes, _contentType(filename));
    if (!put.isOk) {
      state = UploadState(error: put.errorOrNull);
      return Err(put.errorOrNull!);
    }

    final confirmed = await repo.confirm(
      documentType: documentType,
      fileUrl: fileUrl,
      expiresAt: expiresAt,
    );
    state = UploadState(error: confirmed.errorOrNull);
    return confirmed;
  }
}

final uploadControllerProvider =
    NotifierProvider<UploadController, UploadState>(UploadController.new);
```

- [ ] **Step 5: Wire the picker into the screen**

Create `app/lib/features/documents/ui/upload_sheet.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Camera or gallery. A driver photographing a licence at the roadside wants
/// the camera first; one who already has a scan wants the library.
class UploadSheet {
  static Future<XFile?> pick(BuildContext context) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from library'),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return null;
    return ImagePicker().pickImage(source: source, imageQuality: 85);
  }
}
```

In `app/lib/features/documents/ui/documents_screen.dart`, replace `_upload` with a `ConsumerWidget`-aware version:

```dart
  Future<void> _upload(
      BuildContext context, WidgetRef ref, String documentType) async {
    final file = await UploadSheet.pick(context);
    if (file == null || !context.mounted) return;

    final bytes = await file.readAsBytes();
    if (!context.mounted) return;

    final result = await ref
        .read(uploadControllerProvider.notifier)
        .upload(documentType, bytes, file.name);
    if (!context.mounted) return;

    result.when(
      ok: (_) {
        ref.read(documentsControllerProvider.notifier).refresh();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Uploaded — we will review it shortly.')));
      },
      err: (e) => ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(errorCopy(e)))),
    );
  }
```

Update the `onUpload` callback to `() => _upload(context, ref, slot.type.code)` and add the imports for `errorCopy`, `upload_controller.dart` and `upload_sheet.dart`.

- [ ] **Step 6: Run test to verify it passes**

Run: `cd app && flutter test test/features/documents/`
Expected: PASS, 18 tests

- [ ] **Step 7: Commit**

```bash
git add app/lib app/test app/pubspec.yaml
git commit -m "feat: add document upload via the presigned two-step flow"
```

---

### Task 4: Stats and penalties

**Files:**
- Create: `app/lib/features/stats/data/models/driver_stats.dart`
- Create: `app/lib/features/stats/data/models/penalty.dart`
- Create: `app/lib/features/stats/data/stats_repository.dart`
- Test: `app/test/features/stats/stats_repository_test.dart`

**Interfaces:**
- Consumes: `ApiClient`, `Pence`, `Result` (Batch 1)
- Produces:
  - `DriverStats(averageRating, ratingCount, tripsCompleted, tripsCancelled, onlineMinutes, penaltiesCount, balance, totalEarnings, weekEarnings, monthEarnings, acceptanceRate, completionRate)` with `.ratePercent(double?)`.
  - `Penalty(id, createdAt, amount, displayTitle, displayReason, rideId, appealable)`.
  - `StatsRepository.stats()`, `.penalties()`.
  - Provider `statsRepositoryProvider`.

- [ ] **Step 1: Write the failing test**

Create `app/test/features/stats/stats_repository_test.dart`:

```dart
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/core/api/api_client.dart';
import 'package:hoppin_driver/core/auth/token_store.dart';
import 'package:hoppin_driver/features/stats/data/models/driver_stats.dart';
import 'package:hoppin_driver/features/stats/data/stats_repository.dart';
import 'package:mocktail/mocktail.dart';

class _MockAdapter extends Mock implements HttpClientAdapter {}

void main() {
  setUpAll(() => registerFallbackValue(RequestOptions(path: '/')));

  ResponseBody body(String json, int status) =>
      ResponseBody.fromString(json, status, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      });

  late _MockAdapter adapter;
  late StatsRepository repo;

  setUp(() {
    adapter = _MockAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    repo = StatsRepository(ApiClient(dio, InMemoryTokenStore()));
  });

  group('DriverStats', () {
    test('parses the round-4 shape', () {
      final s = DriverStats.fromJson({
        'average_rating': 4.8,
        'rating_count': 5,
        'trips_completed': 15,
        'trips_cancelled': 3,
        'online_minutes': 742,
        'penalties_count': 6,
        'balance_pence': -5000,
        'earnings': {
          'total_pence': 11307,
          'this_week_pence': 2400,
          'this_month_pence': 8600,
        },
        'acceptance_rate': 0.94,
        'completion_rate': 0.83,
      });

      expect(s.averageRating, 4.8);
      expect(s.penaltiesCount, 6);
      expect(s.balance.pence, -5000);
      expect(s.weekEarnings.pence, 2400);
    });

    test('a null rate renders an em dash, never a zero', () {
      final s = DriverStats.fromJson({
        'average_rating': null,
        'acceptance_rate': null,
        'completion_rate': null,
      });

      // A driver who has had no offers has an unknown acceptance rate, not
      // a 0% one — the difference matters to someone being assessed on it.
      expect(s.ratePercent(s.acceptanceRate), '—');
      expect(s.acceptanceRate, isNull);
    });

    test('formats a real rate as a percentage', () {
      final s = DriverStats.fromJson({'acceptance_rate': 0.94});
      expect(s.ratePercent(s.acceptanceRate), '94%');
    });

    test('a driver with no reviews yet has no rating', () {
      final s = DriverStats.fromJson({'rating_count': 0});
      expect(s.averageRating, isNull);
    });
  });

  test('penalties come from the ledger and carry the appeal flag', () async {
    when(() => adapter.fetch(any(), any(), any())).thenAnswer((_) async => body(
        '{"penalties":[{"id":"p1","created_at":"2026-08-26T09:12:00Z",'
        '"amount_pence":1000,"display_title":"Complaint penalty",'
        '"display_reason":"A penalty following a rider complaint.",'
        '"ride_id":"r1","appealable":true}],"count":6}',
        200));

    final r = await repo.penalties();

    expect(r.valueOrNull!.count, 6);
    final p = r.valueOrNull!.penalties.single;
    expect(p.displayTitle, 'Complaint penalty');
    expect(p.amount.pence, 1000);
    expect(p.appealable, isTrue);
  });

  test('an unappealable penalty says so', () async {
    when(() => adapter.fetch(any(), any(), any())).thenAnswer((_) async => body(
        '{"penalties":[{"id":"p2","created_at":"2026-08-26T09:12:00Z",'
        '"amount_pence":300,"display_title":"Late arrival",'
        '"appealable":false}],"count":1}',
        200));

    final r = await repo.penalties();

    expect(r.valueOrNull!.penalties.single.appealable, isFalse);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/features/stats/`
Expected: FAIL — files do not exist

- [ ] **Step 3: Write the models and repository**

Create `app/lib/features/stats/data/models/driver_stats.dart`:

```dart
import '../../../../core/money.dart';

class DriverStats {
  final double? averageRating;
  final int ratingCount;
  final int tripsCompleted;

  /// Only cancels the driver themselves made. Rider cancels, admin
  /// force-cancels and watchdog timeouts are excluded server-side, so this
  /// figure is one the driver is fairly accountable for.
  final int tripsCancelled;

  final int onlineMinutes;
  final int penaltiesCount;
  final Pence balance;
  final Pence totalEarnings;
  final Pence weekEarnings;
  final Pence monthEarnings;

  /// Null until there is anything to compute from.
  final double? acceptanceRate;
  final double? completionRate;

  const DriverStats({
    this.averageRating,
    this.ratingCount = 0,
    this.tripsCompleted = 0,
    this.tripsCancelled = 0,
    this.onlineMinutes = 0,
    this.penaltiesCount = 0,
    this.balance = const Pence(0),
    this.totalEarnings = const Pence(0),
    this.weekEarnings = const Pence(0),
    this.monthEarnings = const Pence(0),
    this.acceptanceRate,
    this.completionRate,
  });

  /// "94%", or an em dash when the rate is unknown. Rendering 0% for a
  /// driver who has simply had no offers would misrepresent them.
  String ratePercent(double? rate) =>
      rate == null ? '—' : '${(rate * 100).round()}%';

  String get onlineHours {
    final hours = onlineMinutes ~/ 60;
    final minutes = onlineMinutes % 60;
    return hours == 0 ? '${minutes}m' : '${hours}h ${minutes}m';
  }

  factory DriverStats.fromJson(Map<String, dynamic> json) {
    final earnings = (json['earnings'] as Map?) ?? const {};
    Pence pence(dynamic v) => Pence((v as num?)?.toInt() ?? 0);

    return DriverStats(
      averageRating: (json['average_rating'] as num?)?.toDouble(),
      ratingCount: (json['rating_count'] as num?)?.toInt() ?? 0,
      tripsCompleted: (json['trips_completed'] as num?)?.toInt() ?? 0,
      tripsCancelled: (json['trips_cancelled'] as num?)?.toInt() ?? 0,
      onlineMinutes: (json['online_minutes'] as num?)?.toInt() ?? 0,
      penaltiesCount: (json['penalties_count'] as num?)?.toInt() ?? 0,
      balance: pence(json['balance_pence']),
      totalEarnings: pence(earnings['total_pence']),
      weekEarnings: pence(earnings['this_week_pence']),
      monthEarnings: pence(earnings['this_month_pence']),
      acceptanceRate: (json['acceptance_rate'] as num?)?.toDouble(),
      completionRate: (json['completion_rate'] as num?)?.toDouble(),
    );
  }
}
```

Create `app/lib/features/stats/data/models/penalty.dart`:

```dart
import '../../../../core/money.dart';

/// One penalty against the driver's account.
///
/// Both this list and `stats.penalties_count` are ledger-sourced, so the
/// count on the Stats screen and the entries behind it cannot disagree —
/// which they did before A13 was resolved.
class Penalty {
  final String id;
  final DateTime createdAt;
  final Pence amount;
  final String displayTitle;
  final String? displayReason;
  final String? rideId;
  final bool appealable;

  const Penalty({
    required this.id,
    required this.createdAt,
    required this.amount,
    required this.displayTitle,
    this.displayReason,
    this.rideId,
    this.appealable = false,
  });

  factory Penalty.fromJson(Map<String, dynamic> json) => Penalty(
        id: json['id'] as String,
        createdAt:
            DateTime.tryParse((json['created_at'] as String?) ?? '') ??
                DateTime.now(),
        amount: Pence((json['amount_pence'] as num?)?.toInt() ?? 0),
        displayTitle: (json['display_title'] as String?) ?? 'Penalty',
        displayReason: json['display_reason'] as String?,
        rideId: json['ride_id'] as String?,
        appealable: json['appealable'] as bool? ?? false,
      );
}

class PenaltyList {
  final List<Penalty> penalties;
  final int count;

  const PenaltyList({required this.penalties, required this.count});

  factory PenaltyList.fromJson(Map<String, dynamic> json) => PenaltyList(
        penalties: ((json['penalties'] as List?) ?? const [])
            .map((e) => Penalty.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        count: (json['count'] as num?)?.toInt() ?? 0,
      );
}
```

Create `app/lib/features/stats/data/stats_repository.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/result.dart';
import 'models/driver_stats.dart';
import 'models/penalty.dart';

class StatsRepository {
  final ApiClient _api;
  StatsRepository(this._api);

  Future<Result<DriverStats>> stats() async {
    final r = await _api.get<Map<String, dynamic>>('/drivers/me/stats');
    return r.when(
      ok: (json) => Ok(DriverStats.fromJson(json)),
      err: (e) => Err(e),
    );
  }

  Future<Result<PenaltyList>> penalties() async {
    final r = await _api.get<Map<String, dynamic>>('/drivers/me/penalties');
    return r.when(
      ok: (json) => Ok(PenaltyList.fromJson(json)),
      err: (e) => Err(e),
    );
  }
}

final statsRepositoryProvider = Provider<StatsRepository>(
    (ref) => StatsRepository(ref.watch(apiClientProvider)));
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd app && flutter test test/features/stats/`
Expected: PASS, 6 tests

- [ ] **Step 5: Commit**

```bash
git add app/lib/features/stats app/test/features/stats
git commit -m "feat: add driver stats and the ledger-sourced penalty list"
```

---

### Task 5: Appeals

**Files:**
- Create: `app/lib/features/stats/data/models/appeal.dart`
- Create: `app/lib/features/stats/data/appeals_repository.dart`
- Test: `app/test/features/stats/appeals_test.dart`

**Interfaces:**
- Consumes: `ApiClient`, `Result` (Batch 1)
- Produces: `AppealStatus` enum (`open`, `underReview`, `approved`, `rejected`); `Appeal(id, documentType, reason, status, reviewNote, reviewedAt, createdAt)` with `.isResolved`; `AppealsRepository.mine()`, `.file(documentType, reason)`. Provider `appealsRepositoryProvider`.

- [ ] **Step 1: Write the failing test**

Create `app/test/features/stats/appeals_test.dart`:

```dart
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/core/api/api_client.dart';
import 'package:hoppin_driver/core/auth/token_store.dart';
import 'package:hoppin_driver/features/stats/data/appeals_repository.dart';
import 'package:hoppin_driver/features/stats/data/models/appeal.dart';
import 'package:mocktail/mocktail.dart';

class _MockAdapter extends Mock implements HttpClientAdapter {}

void main() {
  setUpAll(() => registerFallbackValue(RequestOptions(path: '/')));

  ResponseBody body(String json, int status) =>
      ResponseBody.fromString(json, status, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      });

  late _MockAdapter adapter;
  late AppealsRepository repo;

  setUp(() {
    adapter = _MockAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    repo = AppealsRepository(ApiClient(dio, InMemoryTokenStore()));
  });

  test('a decision carries the reviewer own words', () {
    final a = Appeal.fromJson({
      'id': 'a1',
      'document_type': 'vehicle_insurance',
      'reason': 'The document was in date when I uploaded it.',
      'status': 'approved',
      'review_note': 'Confirmed — the certificate was valid. Reinstated.',
      'reviewed_at': '2026-08-29T14:00:00Z',
      'created_at': '2026-08-28T10:00:00Z',
    });

    expect(a.status, AppealStatus.approved);
    // Admins must supply a note on approve and reject alike, so an outcome
    // reaching the driver without an explanation is a backend bug.
    expect(a.reviewNote, 'Confirmed — the certificate was valid. Reinstated.');
    expect(a.isResolved, isTrue);
  });

  test('an open appeal has no note yet', () {
    final a = Appeal.fromJson({
      'id': 'a2',
      'reason': 'Please review',
      'status': 'pending',
      'created_at': '2026-08-28T10:00:00Z',
    });

    expect(a.status, AppealStatus.underReview);
    expect(a.reviewNote, isNull);
    expect(a.isResolved, isFalse);
  });

  test('a rejection is resolved too', () {
    final a = Appeal.fromJson({
      'id': 'a3',
      'reason': 'x',
      'status': 'rejected',
      'review_note': 'The expiry date had passed at the time of the trip.',
      'created_at': '2026-08-28T10:00:00Z',
    });

    expect(a.status, AppealStatus.rejected);
    expect(a.isResolved, isTrue);
  });

  test('an unknown status reads as under review', () {
    final a = Appeal.fromJson({
      'id': 'a4',
      'reason': 'x',
      'status': 'something_new',
      'created_at': '2026-08-28T10:00:00Z',
    });

    expect(a.status, AppealStatus.underReview);
  });

  test('filing sends the driver reason', () async {
    when(() => adapter.fetch(any(), any(), any())).thenAnswer((_) async => body(
        '{"id":"a5","reason":"It was valid","status":"pending",'
        '"created_at":"2026-08-30T10:00:00Z"}',
        200));

    await repo.file(
        documentType: 'vehicle_insurance', reason: 'It was valid');

    final sent = verify(() => adapter.fetch(captureAny(), any(), any()))
        .captured
        .first as RequestOptions;
    expect(sent.data['reason'], 'It was valid');
    expect(sent.data['document_type'], 'vehicle_insurance');
  });

  test('reads the appeal history', () async {
    when(() => adapter.fetch(any(), any(), any())).thenAnswer((_) async => body(
        '[{"id":"a1","reason":"x","status":"approved",'
        '"review_note":"Reinstated.","created_at":"2026-08-28T10:00:00Z"}]',
        200));

    final r = await repo.mine();

    expect(r.valueOrNull!.single.reviewNote, 'Reinstated.');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/features/stats/appeals_test.dart`
Expected: FAIL — files do not exist

- [ ] **Step 3: Write the model and repository**

Create `app/lib/features/stats/data/models/appeal.dart`:

```dart
enum AppealStatus { underReview, approved, rejected }

/// A driver's challenge to a compliance decision.
///
/// `reviewNote` is the admin's reason, mandatory on both approve and reject.
/// It is rendered verbatim as the outcome — an appeal answered with silence
/// is the problem this field exists to solve.
class Appeal {
  final String id;
  final String? documentType;
  final String reason;
  final AppealStatus status;
  final String? reviewNote;
  final DateTime? reviewedAt;
  final DateTime createdAt;

  const Appeal({
    required this.id,
    required this.reason,
    required this.status,
    required this.createdAt,
    this.documentType,
    this.reviewNote,
    this.reviewedAt,
  });

  bool get isResolved =>
      status == AppealStatus.approved || status == AppealStatus.rejected;

  factory Appeal.fromJson(Map<String, dynamic> json) => Appeal(
        id: json['id'] as String,
        documentType: json['document_type'] as String?,
        reason: (json['reason'] as String?) ?? '',
        status: switch (json['status'] as String?) {
          'approved' || 'upheld' => AppealStatus.approved,
          'rejected' || 'denied' => AppealStatus.rejected,
          // Anything else is still in flight; claiming a decision we do not
          // have would be worse than saying it is under review.
          _ => AppealStatus.underReview,
        },
        reviewNote: json['review_note'] as String?,
        reviewedAt: json['reviewed_at'] == null
            ? null
            : DateTime.tryParse(json['reviewed_at'] as String),
        createdAt:
            DateTime.tryParse((json['created_at'] as String?) ?? '') ??
                DateTime.now(),
      );
}
```

Create `app/lib/features/stats/data/appeals_repository.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/result.dart';
import 'models/appeal.dart';

class AppealsRepository {
  final ApiClient _api;
  AppealsRepository(this._api);

  Future<Result<List<Appeal>>> mine() async {
    final r = await _api.get<dynamic>('/drivers/me/compliance-appeals');
    return r.when(
      ok: (data) {
        final list = data is Map
            ? ((data['appeals'] as List?) ?? const [])
            : (data as List? ?? const []);
        return Ok(list
            .map((e) => Appeal.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList());
      },
      err: (e) => Err(e),
    );
  }

  Future<Result<Appeal>> file({
    String? documentType,
    required String reason,
  }) async {
    final r = await _api
        .post<Map<String, dynamic>>('/drivers/me/compliance-appeals', body: {
      'reason': reason,
      if (documentType != null) 'document_type': documentType,
    });
    return r.when(
      ok: (json) => Ok(Appeal.fromJson(json)),
      err: (e) => Err(e),
    );
  }
}

final appealsRepositoryProvider = Provider<AppealsRepository>(
    (ref) => AppealsRepository(ref.watch(apiClientProvider)));
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd app && flutter test test/features/stats/`
Expected: PASS, 12 tests

- [ ] **Step 5: Commit**

```bash
git add app/lib/features/stats app/test/features/stats
git commit -m "feat: add compliance appeals carrying the reviewer decision"
```

---

### Task 6: The Stats screen

**Files:**
- Create: `app/lib/features/stats/logic/stats_controller.dart`
- Create: `app/lib/features/stats/ui/stats_screen.dart`
- Create: `app/lib/features/stats/ui/widgets/stat_tile.dart`
- Create: `app/lib/features/stats/ui/widgets/penalties_section.dart`
- Modify: `app/lib/app.dart`
- Test: `app/test/features/stats/stats_screen_test.dart`

**Interfaces:**
- Consumes: `StatsRepository` (Task 4), `AppealsRepository` (Task 5)
- Produces: `StatsState(stats, penalties, appeals)`; `StatsController`; `StatsScreen`; `StatTile(label, value, {trend})`; `PenaltiesSection(penalties, appeals, {onAppeal})`. Replaces the Stats placeholder route.

- [ ] **Step 1: Write the failing test**

Create `app/test/features/stats/stats_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/core/money.dart';
import 'package:hoppin_driver/core/result.dart';
import 'package:hoppin_driver/features/stats/data/appeals_repository.dart';
import 'package:hoppin_driver/features/stats/data/models/appeal.dart';
import 'package:hoppin_driver/features/stats/data/models/driver_stats.dart';
import 'package:hoppin_driver/features/stats/data/models/penalty.dart';
import 'package:hoppin_driver/features/stats/data/stats_repository.dart';
import 'package:hoppin_driver/features/stats/ui/stats_screen.dart';
import 'package:mocktail/mocktail.dart';

class MockStatsRepo extends Mock implements StatsRepository {}

class MockAppealsRepo extends Mock implements AppealsRepository {}

Widget wrap(MockStatsRepo stats, MockAppealsRepo appeals) => ProviderScope(
      overrides: [
        statsRepositoryProvider.overrideWithValue(stats),
        appealsRepositoryProvider.overrideWithValue(appeals),
      ],
      child: const MaterialApp(home: StatsScreen()),
    );

void main() {
  late MockStatsRepo stats;
  late MockAppealsRepo appeals;

  setUp(() {
    stats = MockStatsRepo();
    appeals = MockAppealsRepo();
    when(() => appeals.mine()).thenAnswer((_) async => const Ok([]));
    when(() => stats.penalties()).thenAnswer(
        (_) async => const Ok(PenaltyList(penalties: [], count: 0)));
  });

  testWidgets('shows the rating and trip counts', (tester) async {
    when(() => stats.stats()).thenAnswer((_) async => const Ok(DriverStats(
        averageRating: 4.8,
        ratingCount: 5,
        tripsCompleted: 15,
        acceptanceRate: 0.94)));

    await tester.pumpWidget(wrap(stats, appeals));
    await tester.pumpAndSettle();

    expect(find.text('4.8'), findsOneWidget);
    expect(find.text('15'), findsOneWidget);
    expect(find.text('94%'), findsOneWidget);
  });

  testWidgets('an unknown rate shows an em dash, not 0%', (tester) async {
    when(() => stats.stats()).thenAnswer((_) async => const Ok(DriverStats()));

    await tester.pumpWidget(wrap(stats, appeals));
    await tester.pumpAndSettle();

    expect(find.text('—'), findsWidgets);
    expect(find.text('0%'), findsNothing);
  });

  testWidgets('says whose cancellations are being counted', (tester) async {
    when(() => stats.stats()).thenAnswer(
        (_) async => const Ok(DriverStats(tripsCancelled: 3)));

    await tester.pumpWidget(wrap(stats, appeals));
    await tester.pumpAndSettle();

    // Rider and admin cancels are excluded server-side; the driver needs to
    // know the number is theirs alone.
    expect(find.textContaining('you cancelled'), findsOneWidget);
  });

  testWidgets('never puts a currency symbol on a trip count', (tester) async {
    when(() => stats.stats()).thenAnswer(
        (_) async => const Ok(DriverStats(tripsCompleted: 1247)));

    await tester.pumpWidget(wrap(stats, appeals));
    await tester.pumpAndSettle();

    expect(find.text('1247'), findsOneWidget);
    expect(find.text('£1247'), findsNothing);
  });

  testWidgets('the penalty count opens the list', (tester) async {
    when(() => stats.stats())
        .thenAnswer((_) async => const Ok(DriverStats(penaltiesCount: 2)));
    when(() => stats.penalties()).thenAnswer((_) async => Ok(PenaltyList(
          count: 2,
          penalties: [
            Penalty(
              id: 'p1',
              createdAt: DateTime.utc(2026, 8, 26),
              amount: const Pence(1000),
              displayTitle: 'Complaint penalty',
              displayReason: 'A penalty following a rider complaint.',
              appealable: true,
            ),
          ],
        )));

    await tester.pumpWidget(wrap(stats, appeals));
    await tester.pumpAndSettle();

    expect(find.text('Complaint penalty'), findsOneWidget);
    expect(find.text('A penalty following a rider complaint.'), findsOneWidget);
    expect(find.text('£10.00'), findsOneWidget);
  });

  testWidgets('offers Appeal only where the server allows it', (tester) async {
    when(() => stats.stats())
        .thenAnswer((_) async => const Ok(DriverStats(penaltiesCount: 2)));
    when(() => stats.penalties()).thenAnswer((_) async => Ok(PenaltyList(
          count: 2,
          penalties: [
            Penalty(
                id: 'p1',
                createdAt: DateTime.utc(2026, 8, 26),
                amount: const Pence(1000),
                displayTitle: 'Appealable',
                appealable: true),
            Penalty(
                id: 'p2',
                createdAt: DateTime.utc(2026, 8, 26),
                amount: const Pence(300),
                displayTitle: 'Not appealable',
                appealable: false),
          ],
        )));

    await tester.pumpWidget(wrap(stats, appeals));
    await tester.pumpAndSettle();

    expect(find.text('Appeal'), findsOneWidget);
  });

  testWidgets('a resolved appeal shows the reviewer note', (tester) async {
    when(() => stats.stats()).thenAnswer((_) async => const Ok(DriverStats()));
    when(() => appeals.mine()).thenAnswer((_) async => Ok([
          Appeal(
            id: 'a1',
            reason: 'It was in date',
            status: AppealStatus.approved,
            reviewNote: 'Confirmed — the certificate was valid. Reinstated.',
            createdAt: DateTime.utc(2026, 8, 28),
          )
        ]));

    await tester.pumpWidget(wrap(stats, appeals));
    await tester.pumpAndSettle();

    expect(find.text('Confirmed — the certificate was valid. Reinstated.'),
        findsOneWidget);
  });

  testWidgets('an appeal under review says so without inventing an outcome',
      (tester) async {
    when(() => stats.stats()).thenAnswer((_) async => const Ok(DriverStats()));
    when(() => appeals.mine()).thenAnswer((_) async => Ok([
          Appeal(
            id: 'a2',
            reason: 'Please review',
            status: AppealStatus.underReview,
            createdAt: DateTime.utc(2026, 8, 28),
          )
        ]));

    await tester.pumpWidget(wrap(stats, appeals));
    await tester.pumpAndSettle();

    expect(find.textContaining('Under review'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/features/stats/stats_screen_test.dart`
Expected: FAIL — screen files do not exist

- [ ] **Step 3: Write the controller**

Create `app/lib/features/stats/logic/stats_controller.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../data/appeals_repository.dart';
import '../data/models/appeal.dart';
import '../data/models/driver_stats.dart';
import '../data/models/penalty.dart';
import '../data/stats_repository.dart';

class StatsState {
  final DriverStats? stats;
  final PenaltyList? penalties;
  final List<Appeal> appeals;
  final ApiException? error;

  const StatsState({
    this.stats,
    this.penalties,
    this.appeals = const [],
    this.error,
  });
}

class StatsController extends AsyncNotifier<StatsState> {
  bool _disposed = false;

  @override
  Future<StatsState> build() async {
    ref.onDispose(() => _disposed = true);
    return _fetch();
  }

  Future<StatsState> _fetch() async {
    final statsRepo = ref.read(statsRepositoryProvider);
    final stats = await statsRepo.stats();
    final penalties = await statsRepo.penalties();
    final appeals = await ref.read(appealsRepositoryProvider).mine();

    return StatsState(
      stats: stats.valueOrNull,
      penalties: penalties.valueOrNull,
      appeals: appeals.valueOrNull ?? const [],
      error: stats.errorOrNull,
    );
  }

  Future<void> refresh() async {
    final next = await _fetch();
    if (_disposed) return;
    state = AsyncData(next);
  }
}

final statsControllerProvider =
    AsyncNotifierProvider<StatsController, StatsState>(StatsController.new);
```

- [ ] **Step 4: Write the tile, section and screen**

Create `app/lib/features/stats/ui/widgets/stat_tile.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/typography.dart';

class StatTile extends StatelessWidget {
  final IconData icon;
  final Color tint;
  final String label;
  final String value;
  final String? note;

  const StatTile({
    super.key,
    required this.icon,
    required this.tint,
    required this.label,
    required this.value,
    this.note,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: tint, size: 22),
            const SizedBox(height: 10),
            Text(label, style: AppText.caption),
            const SizedBox(height: 2),
            Text(value, style: AppText.title),
            if (note != null) ...[
              const SizedBox(height: 2),
              Text(note!, style: AppText.caption),
            ],
          ],
        ),
      );
}
```

Create `app/lib/features/stats/ui/widgets/penalties_section.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/typography.dart';
import '../../data/models/appeal.dart';
import '../../data/models/penalty.dart';

/// Penalties and the appeals against them, in one place — they are one
/// story, and splitting them would leave a driver checking two screens to
/// learn what happened to a challenge they filed.
class PenaltiesSection extends StatelessWidget {
  final PenaltyList? penalties;
  final List<Appeal> appeals;
  final void Function(Penalty)? onAppeal;

  const PenaltiesSection({
    super.key,
    required this.penalties,
    this.appeals = const [],
    this.onAppeal,
  });

  @override
  Widget build(BuildContext context) {
    final items = penalties?.penalties ?? const <Penalty>[];
    final underReview = appeals.where((a) => !a.isResolved).toList();
    final resolved = appeals.where((a) => a.isResolved).toList();

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Penalties and appeals', style: AppText.heading),
          const SizedBox(height: 4),
          Text('Track your account status and any penalties',
              style: AppText.caption),
          const SizedBox(height: 12),
          if (items.isEmpty && appeals.isEmpty)
            Text('No penalties on your account.', style: AppText.bodySecondary)
          else ...[
            ...items.map(_penaltyRow),
            if (underReview.isNotEmpty) ...[
              const Divider(height: 24, color: AppColors.border),
              Text('Under review (${underReview.length})',
                  style: AppText.body),
              ...underReview.map(_appealRow),
            ],
            if (resolved.isNotEmpty) ...[
              const Divider(height: 24, color: AppColors.border),
              Text('Resolved (${resolved.length})', style: AppText.body),
              ...resolved.map(_appealRow),
            ],
          ],
        ],
      ),
    );
  }

  Widget _penaltyRow(Penalty p) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(p.displayTitle, style: AppText.body)),
                Text(p.amount.format(),
                    style: AppText.body.copyWith(color: AppColors.negative)),
              ],
            ),
            if (p.displayReason != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(p.displayReason!, style: AppText.caption),
              ),
            Row(
              children: [
                Text(DateFormat('d MMM yyyy').format(p.createdAt),
                    style: AppText.caption),
                const Spacer(),
                // Appeal appears only where the server says the penalty can
                // be appealed at all.
                if (p.appealable && onAppeal != null)
                  TextButton(
                    onPressed: () => onAppeal!(p),
                    child: const Text('Appeal'),
                  ),
              ],
            ),
          ],
        ),
      );

  Widget _appealRow(Appeal a) {
    final (label, colour) = switch (a.status) {
      AppealStatus.approved => ('Approved', AppColors.positive),
      AppealStatus.rejected => ('Rejected', AppColors.negative),
      AppealStatus.underReview => ('Under review', AppColors.warning),
    };

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colour.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(a.reason, style: AppText.body)),
              Text(label, style: AppText.caption.copyWith(color: colour)),
            ],
          ),
          // The reviewer's own words. An appeal answered with a bare status
          // is what this field exists to prevent.
          if (a.reviewNote != null) ...[
            const SizedBox(height: 6),
            Text(a.reviewNote!, style: AppText.caption),
          ],
        ],
      ),
    );
  }
}
```

Create `app/lib/features/stats/ui/stats_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../shared/widgets/app_error_state.dart';
import '../../../shared/widgets/app_loading.dart';
import '../logic/stats_controller.dart';
import 'widgets/penalties_section.dart';
import 'widgets/stat_tile.dart';

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(statsControllerProvider);
    final controller = ref.read(statsControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Stats')),
      body: async.when(
        loading: () => const AppLoading(),
        error: (e, _) => Center(child: Text('$e', style: AppText.body)),
        data: (state) {
          final stats = state.stats;
          if (stats == null && state.error != null) {
            return AppErrorState(
                error: state.error!, onRetry: controller.refresh);
          }
          return RefreshIndicator(
            onRefresh: controller.refresh,
            child: ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.5,
                    children: [
                      StatTile(
                        icon: Icons.directions_car_outlined,
                        tint: AppColors.primary,
                        label: 'Trips completed',
                        // A count, never a currency figure.
                        value: '${stats?.tripsCompleted ?? 0}',
                      ),
                      StatTile(
                        icon: Icons.star_outline,
                        tint: AppColors.warning,
                        label: 'Rating',
                        value: stats?.averageRating?.toStringAsFixed(1) ?? '—',
                        note: (stats?.ratingCount ?? 0) > 0
                            ? '${stats!.ratingCount} reviews'
                            : 'No reviews yet',
                      ),
                      StatTile(
                        icon: Icons.check_circle_outline,
                        tint: AppColors.positive,
                        label: 'Acceptance rate',
                        value: stats?.ratePercent(stats.acceptanceRate) ?? '—',
                      ),
                      StatTile(
                        icon: Icons.cancel_outlined,
                        tint: AppColors.negative,
                        label: 'Cancellations',
                        value: '${stats?.tripsCancelled ?? 0}',
                        note: 'Trips you cancelled',
                      ),
                    ],
                  ),
                ),
                PenaltiesSection(
                  penalties: state.penalties,
                  appeals: state.appeals,
                  onAppeal: (penalty) => ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(
                          content:
                              Text('Appealing "${penalty.displayTitle}"'))),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
```

- [ ] **Step 5: Register the route**

In `app/lib/app.dart`, replace the Stats placeholder:

```dart
          GoRoute(path: Routes.stats, builder: (_, __) => const StatsScreen()),
```

- [ ] **Step 6: Run the whole suite**

Run: `cd app && flutter test && flutter analyze`
Expected: all PASS, analyzer clean

- [ ] **Step 7: Commit**

```bash
git add app/lib app/test
git commit -m "feat: add the stats screen with penalties and appeal outcomes"
```

---

## Batch 6 done when

- `flutter test` passes and `flutter analyze` is clean.
- A rejected document shows the admin's reason in full, and the driver can re-upload from that card.
- An operator-run document shows its status with no upload affordance.
- A document expiring within thirty days is flagged before it blocks the driver.
- Stats renders an em dash for any unknown rate, never 0%, and never puts a currency symbol on a count.
- The penalty count and the penalty list agree, because both read the ledger.
- An appeal decision shows the reviewer's own note; one still open says so without inventing an outcome.

**Next:** Batch 7 (Account) — profile, settings, notifications, support, delete account, payment.
