import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miya_baby/main.dart';
import 'package:miya_baby/state/providers.dart';

import 'fakes.dart';

Widget _app() => ProviderScope(
      overrides: [
        eventStoreProvider.overrideWithValue(InMemoryEventStore()),
        profileStoreProvider.overrideWithValue(InMemoryProfileStore()),
        watchServiceProvider.overrideWithValue(FakeWatch()),
      ],
      child: const MiyaBabyApp(),
    );

void main() {
  testWidgets('app boots to the home screen', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    // Home screen greets with the default profile name.
    expect(find.text("Miya's Day"), findsOneWidget);
    expect(find.text('Quick log'), findsOneWidget);
    // Bottom navigation is present with all five destinations.
    expect(find.byType(NavigationBar), findsOneWidget);
    for (final label in ['Home', 'History', 'Stats', 'Growth', 'Settings']) {
      expect(find.text(label), findsWidgets);
    }
  });

  testWidgets('tapping Stats shows the stats screen', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Stats'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'Stats'), findsOneWidget);
  });
}
