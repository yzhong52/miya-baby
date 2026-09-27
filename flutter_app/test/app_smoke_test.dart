import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miya_baby/data/repository.dart';
import 'package:miya_baby/main.dart';
import 'package:miya_baby/models/activity_event.dart';
import 'package:miya_baby/models/baby_profile.dart';
import 'package:miya_baby/services/watch_service.dart';
import 'package:miya_baby/state/providers.dart';

/// In-memory stand-in for [AppRepository] (which needs Hive).
class FakeRepository extends AppRepository {
  BabyProfile _profile = const BabyProfile();

  @override
  List<ActivityEvent> getAllEvents() => const [];

  @override
  Future<void> saveEvent(ActivityEvent event) async {}

  @override
  Future<void> deleteEvent(String id) async {}

  @override
  BabyProfile getProfile() => _profile;

  @override
  Future<void> saveProfile(BabyProfile profile) async {
    _profile = profile;
  }
}

/// WatchService whose pushSnapshot is a no-op (no platform channel).
class FakeWatch extends WatchService {
  @override
  Future<void> pushSnapshot(Map<String, dynamic> payload) async {}
}

Widget _app() => ProviderScope(
      overrides: [
        repositoryProvider.overrideWithValue(FakeRepository()),
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
