import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/core/api/api_exception.dart';
import 'package:hoppin_driver/core/result.dart';
import 'package:hoppin_driver/features/trip/data/chat_repository.dart';
import 'package:hoppin_driver/features/trip/data/models/ride_message.dart';
import 'package:hoppin_driver/features/trip/ui/chat_screen.dart';
import 'package:mocktail/mocktail.dart';

class MockChatRepo extends Mock implements ChatRepository {}

Widget wrap(MockChatRepo repo) => ProviderScope(
      overrides: [chatRepositoryProvider.overrideWithValue(repo)],
      child: const MaterialApp(home: ChatScreen(rideId: 'r1')),
    );

void main() {
  late MockChatRepo repo;

  setUp(() {
    repo = MockChatRepo();
    when(() => repo.messages(any())).thenAnswer((_) async => const Ok([]));
  });

  testWidgets('a failed send keeps the text and says it failed',
      (tester) async {
    when(() => repo.send(any(), any(), replyToId: any(named: 'replyToId')))
        .thenAnswer((_) async => Err(ApiException('INTERNAL', '', 0)));

    await tester.pumpWidget(wrap(repo));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), "I'm at the blue door");
    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();

    // The driver's own words must survive a failed send. Clearing the
    // composer silently tells them the rider was informed when they
    // were not — the worst outcome for a message sent while waiting
    // outside a pickup.
    expect(find.text("I'm at the blue door"), findsOneWidget);
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('a successful send clears the composer', (tester) async {
    when(() => repo.send(any(), any(), replyToId: any(named: 'replyToId')))
        .thenAnswer((_) async => Ok(RideMessage(
              id: 'm1',
              body: 'On my way',
              senderRole: 'driver',
              createdAt: DateTime.now(),
            )));

    await tester.pumpWidget(wrap(repo));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'On my way');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, isEmpty);
    expect(find.byType(SnackBar), findsNothing);
  });
}
