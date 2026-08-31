import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/core/money.dart';
import 'package:hoppin_driver/core/result.dart';
import 'package:hoppin_driver/core/theme/app_theme.dart';
import 'package:hoppin_driver/features/documents/data/documents_repository.dart';
import 'package:hoppin_driver/features/documents/data/models/driver_document.dart';
import 'package:hoppin_driver/features/documents/ui/documents_screen.dart';
import 'package:hoppin_driver/features/stats/data/appeals_repository.dart';
import 'package:hoppin_driver/features/stats/data/models/appeal.dart';
import 'package:hoppin_driver/features/stats/data/models/driver_stats.dart';
import 'package:hoppin_driver/features/stats/data/models/penalty.dart';
import 'package:hoppin_driver/features/stats/data/stats_repository.dart';
import 'package:hoppin_driver/features/stats/ui/stats_screen.dart';
import 'package:mocktail/mocktail.dart';

class _StatsRepo extends Mock implements StatsRepository {}

class _AppealsRepo extends Mock implements AppealsRepository {}

class _DocsRepo extends Mock implements DocumentsRepository {}

/// Renders the Stats and Documents screens at the Figma artboard size and
/// writes them to `test/visual/goldens/`, so the build can be held against
/// the design by eye rather than by assertion.
///
/// Run with `flutter test --update-goldens test/visual/stats_docs_golden_test.dart`.
void main() {
  setUpAll(() => registerFallbackValue(StatsPeriod.month));

  Future<void> capture(
    WidgetTester tester,
    Widget child,
    String name, {
    List<Override> overrides = const [],
  }) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        theme: appTheme(),
        home: child,
      ),
    ));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/$name.png'),
    );
  }

  DriverStats theStats() => DriverStats(
        period: StatsPeriod.month,
        from: DateTime.utc(2026, 8, 1),
        to: DateTime.utc(2026, 8, 31),
        averageRating: 4.7,
        ratingCount: 128,
        tripsCompleted: 1247,
        tripsCancelled: 4,
        penaltiesActive: 1,
        acceptanceRate: 0.96,
        cancellationRate: 0.04,
      );

  PenaltyList thePenalties() => PenaltyList(
        count: 1,
        penalties: [
          Penalty(
            id: 'p1',
            createdAt: DateTime.utc(2026, 2, 18),
            amount: const Pence(1200),
            displayTitle: 'Cancellation after arrival',
            appealable: true,
          ),
        ],
      );

  List<Appeal> theAppeals() => [
        Appeal(
          id: 'a1',
          reason: '3 Star rating from passenger',
          status: AppealStatus.underReview,
          createdAt: DateTime.utc(2026, 2, 18),
        ),
        Appeal(
          id: 'a2',
          reason: 'Cancellation after arrival',
          status: AppealStatus.approved,
          reviewNote: 'Traffic evidence accepted. Penalty reversed.',
          reviewedAt: DateTime.utc(2026, 2, 20),
          createdAt: DateTime.utc(2026, 2, 18),
        ),
        Appeal(
          id: 'a3',
          reason: 'Late arrival at pickup',
          status: AppealStatus.rejected,
          reviewNote: 'No evidence supplied within the window.',
          reviewedAt: DateTime.utc(2026, 2, 21),
          createdAt: DateTime.utc(2026, 2, 18),
        ),
      ];

  List<Override> statsOverrides({
    DriverStats? stats,
    PenaltyList? penalties,
    List<Appeal>? appeals,
  }) {
    final s = _StatsRepo();
    final a = _AppealsRepo();
    when(() => s.stats(period: any(named: 'period')))
        .thenAnswer((_) async => Ok(stats ?? theStats()));
    when(() => s.penalties())
        .thenAnswer((_) async => Ok(penalties ?? thePenalties()));
    when(() => a.mine()).thenAnswer((_) async => Ok(appeals ?? theAppeals()));
    return [
      statsRepositoryProvider.overrideWithValue(s),
      appealsRepositoryProvider.overrideWithValue(a),
    ];
  }

  List<Override> docsOverrides(List<DocumentSlot> slots) {
    final d = _DocsRepo();
    when(() => d.slots()).thenAnswer((_) async => Ok(slots));
    return [documentsRepositoryProvider.overrideWithValue(d)];
  }

  DocumentSlot docSlot(
    String code,
    String label, {
    DocumentStatus status = DocumentStatus.approved,
    DateTime? expiresAt,
    String? rejectionReason,
    bool uploadable = true,
  }) =>
      DocumentSlot(
        type: DocumentType(code: code, label: label, uploadable: uploadable),
        document: status == DocumentStatus.missing
            ? null
            : DriverDocument(
                id: code,
                documentType: code,
                status: status,
                expiresAt: expiresAt ?? DateTime.utc(2027, 1, 15),
                rejectionReason: rejectionReason,
                uploadedAt: DateTime.utc(2026, 1, 2),
              ),
      );

  testWidgets(
    'stats',
    (t) => capture(t, const StatsScreen(), 'stats',
        overrides: statsOverrides()),
  );

  testWidgets(
    'stats with no penalties',
    (t) => capture(
      t,
      const StatsScreen(),
      'stats_clean',
      overrides: statsOverrides(
        penalties: const PenaltyList(penalties: [], count: 0),
        appeals: const [],
      ),
    ),
  );

  testWidgets(
    'documents',
    (t) => capture(
      t,
      const DocumentsScreen(),
      'documents',
      overrides: docsOverrides([
        docSlot('dvla_license', 'DVLA Licence'),
        docSlot('wolverhampton_taxi_badge', 'Wolverhampton Taxi Badge'),
        docSlot('insurance_policy', 'Insurance Policy'),
        docSlot('mot_certificate', 'MOT Certificate',
            status: DocumentStatus.pending),
        docSlot('right_to_work', 'Right to Work',
            status: DocumentStatus.missing),
        docSlot('nr3s_background_check', 'NR3S Background Check',
            uploadable: false, status: DocumentStatus.pending),
      ]),
    ),
  );

  testWidgets(
    'documents with a rejection',
    (t) => capture(
      t,
      const DocumentsScreen(),
      'documents_rejected',
      overrides: docsOverrides([
        docSlot('dvla_license', 'DVLA Licence',
            status: DocumentStatus.rejected,
            rejectionReason:
                'The photo was too blurry to read the expiry date.'),
        docSlot('insurance_policy', 'Insurance Policy',
            status: DocumentStatus.expired,
            expiresAt: DateTime.utc(2026, 1, 15)),
      ]),
    ),
  );

  // The three accordion states the Figma shows one screen each for.
  for (final (label, name) in const [
    ('Active (1)', 'stats_active_open'),
    ('Under review (1)', 'stats_under_review_open'),
    ('Resolved (2)', 'stats_resolved_open'),
  ]) {
    testWidgets('$name expands', (tester) async {
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(ProviderScope(
        overrides: statsOverrides(),
        child: MaterialApp(theme: appTheme(), home: const StatsScreen()),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text(label));
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/$name.png'),
      );
    });
  }

  testWidgets('appeal penalty modal', (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ProviderScope(
      overrides: statsOverrides(),
      child: MaterialApp(theme: appTheme(), home: const StatsScreen()),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Active (1)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Appeal'));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/stats_appeal_modal.png'),
    );
  });
}
