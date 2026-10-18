import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miya_baby/data/repository.dart';
import 'package:miya_baby/models/activity_event.dart';
import 'package:miya_baby/models/baby_profile.dart';
import 'package:miya_baby/services/watch_service.dart';
import 'package:miya_baby/state/providers.dart';

/// In-memory stand-in for [AppRepository] (which needs Hive).
class FakeRepository extends AppRepository {
  final _events = <String, ActivityEvent>{};
  BabyProfile _profile = const BabyProfile();

  @override
  List<ActivityEvent> getAllEvents() {
    final list = _events.values.toList()
      ..sort((a, b) => b.startTime.compareTo(a.startTime));
    return list;
  }

  @override
  Future<void> saveEvent(ActivityEvent event) async {
    _events[event.id] = event;
  }

  @override
  Future<void> deleteEvent(String id) async {
    _events.remove(id);
  }

  @override
  BabyProfile getProfile() => _profile;

  @override
  Future<void> saveProfile(BabyProfile profile) async {
    _profile = profile;
  }
}

/// WatchService whose pushSnapshot is a no-op (no platform channel).
class FakeWatch extends WatchService {
  int snapshots = 0;

  @override
  Future<void> pushSnapshot(Map<String, dynamic> payload) async {
    snapshots++;
  }
}

ProviderContainer _container(FakeRepository repo, FakeWatch watch) {
  return ProviderContainer(
    overrides: [
      repositoryProvider.overrideWithValue(repo),
      watchServiceProvider.overrideWithValue(watch),
    ],
  );
}

void main() {
  group('EventsNotifier', () {
    late FakeRepository repo;
    late FakeWatch watch;
    late ProviderContainer container;

    setUp(() {
      repo = FakeRepository();
      watch = FakeWatch();
      container = _container(repo, watch);
    });

    tearDown(() => container.dispose());

    test('logInstant adds an event and pushes a snapshot', () async {
      final notifier = container.read(eventsProvider.notifier);
      await notifier.logInstant(
        type: EventType.diaper,
        data: {'diaperKind': 'wet'},
        at: DateTime(2026, 9, 27, 10, 0),
      );
      final events = container.read(eventsProvider);
      expect(events.length, 1);
      expect(events.single.type, EventType.diaper);
      expect(watch.snapshots, 1);
    });

    test('startTimer creates an active timer; stopTimer ends it', () async {
      final notifier = container.read(eventsProvider.notifier);
      await notifier.startTimer(
          type: EventType.sleep, data: const {}, note: null);
      expect(notifier.activeTimer(EventType.sleep)?.isActive, isTrue);

      final stopped = await notifier.stopTimer(EventType.sleep);
      expect(stopped, isNotNull);
      expect(stopped!.endTime, isNotNull);
      expect(notifier.activeTimer(EventType.sleep), isNull);
      expect(watch.snapshots, 2);
    });

    test('startTimer and stopTimer honor an explicit time', () async {
      final notifier = container.read(eventsProvider.notifier);
      final start = DateTime(2026, 10, 3, 2, 0);
      final end = DateTime(2026, 10, 3, 2, 40);
      await notifier.startTimer(type: EventType.feeding, at: start);
      expect(notifier.activeTimer(EventType.feeding)!.startTime, start);

      final stopped = await notifier.stopTimer(EventType.feeding, at: end);
      expect(stopped!.startTime, start);
      expect(stopped.endTime, end);
      expect(stopped.duration, const Duration(minutes: 40));
    });

    test('stopTimer clamps a time before the start to the start', () async {
      final notifier = container.read(eventsProvider.notifier);
      final start = DateTime(2026, 10, 3, 2, 0);
      await notifier.startTimer(type: EventType.sleep, at: start);
      final stopped = await notifier.stopTimer(EventType.sleep,
          at: start.subtract(const Duration(minutes: 5)));
      expect(stopped!.endTime, start);
      expect(stopped.duration, Duration.zero);
    });

    test('stopTimer returns null when no active timer', () async {
      final notifier = container.read(eventsProvider.notifier);
      expect(await notifier.stopTimer(EventType.feeding), isNull);
    });

    test('remove deletes the event', () async {
      final notifier = container.read(eventsProvider.notifier);
      final e = await notifier.logInstant(type: EventType.note, note: 'hi');
      expect(container.read(eventsProvider).length, 1);
      await notifier.remove(e.id);
      expect(container.read(eventsProvider), isEmpty);
    });

    test('events are newest-first', () async {
      final notifier = container.read(eventsProvider.notifier);
      await notifier.logInstant(
          type: EventType.diaper, at: DateTime(2026, 9, 27, 9, 0));
      await notifier.logInstant(
          type: EventType.diaper, at: DateTime(2026, 9, 27, 11, 0));
      final events = container.read(eventsProvider);
      expect(events[0].startTime.hour, 11);
      expect(events[1].startTime.hour, 9);
    });

    test('snapshotPayload has latest finished events and running timers',
        () async {
      final notifier = container.read(eventsProvider.notifier);
      await notifier.logInstant(
          type: EventType.diaper,
          data: {'diaperKind': 'dirty'},
          at: DateTime(2026, 9, 27, 9, 0));
      await notifier.logInstant(
          type: EventType.diaper,
          data: {'diaperKind': 'wet'},
          at: DateTime(2026, 9, 27, 11, 0));
      await notifier.startTimer(type: EventType.sleep);

      final snap = notifier.snapshotPayload();
      expect((snap['lastDiaper'] as Map)['data'], {'diaperKind': 'wet'});
      expect(snap['lastFeed'], isNull);
      // The running sleep timer isn't "last sleep"; it's activeSleepStart.
      expect(snap['lastSleep'], isNull);
      expect(snap['activeSleepStart'], isA<String>());
      expect(snap['activeNursingStart'], isNull);
      expect(snap['generatedAt'], isA<String>());
    });

    test('snapshotPayload timestamps are UTC ISO 8601 for the watch', () async {
      // Swift's ISO8601DateFormatter needs an explicit offset; see #8.
      final notifier = container.read(eventsProvider.notifier);
      final at = DateTime(2026, 10, 3, 10, 15, 30, 123, 456); // local
      await notifier.logInstant(type: EventType.diaper, at: at);
      await notifier.startTimer(type: EventType.sleep);

      final snap = notifier.snapshotPayload();
      final diaper = snap['lastDiaper'] as Map<String, dynamic>;
      final utc = RegExp(r'^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d(\.\d+)?Z$');
      for (final iso in [
        diaper['startTime'],
        diaper['endTime'],
        diaper['createdAt'],
        snap['activeSleepStart'],
        snap['generatedAt'],
      ]) {
        expect(iso, matches(utc));
      }
      // Same instant, just expressed in UTC.
      expect(
        DateTime.parse(diaper['startTime'] as String).isAtSameMomentAs(at),
        isTrue,
      );
    });

    test('pushSnapshot sends to the watch', () async {
      final notifier = container.read(eventsProvider.notifier);
      await notifier.pushSnapshot();
      expect(watch.snapshots, 1);
    });
  });

  group('eventsForDayProvider', () {
    test('returns only events for the given day', () async {
      final repo = FakeRepository();
      final watch = FakeWatch();
      final container = _container(repo, watch);
      addTearDown(container.dispose);

      final notifier = container.read(eventsProvider.notifier);
      await notifier.logInstant(
          type: EventType.diaper, at: DateTime(2026, 9, 27, 9, 0));
      await notifier.logInstant(
          type: EventType.diaper, at: DateTime(2026, 9, 26, 9, 0));

      final sept27 =
          container.read(eventsForDayProvider(DateTime(2026, 9, 27)));
      expect(sept27.length, 1);
      expect(sept27.single.startTime.day, 27);

      final sept26 =
          container.read(eventsForDayProvider(DateTime(2026, 9, 26)));
      expect(sept26.length, 1);
      expect(sept26.single.startTime.day, 26);
    });
  });

  group('ProfileNotifier', () {
    test('update persists and notifies', () async {
      final repo = FakeRepository();
      final watch = FakeWatch();
      final container = _container(repo, watch);
      addTearDown(container.dispose);

      final notifier = container.read(profileProvider.notifier);
      await notifier
          .update(const BabyProfile(name: 'Miya', metricUnits: false));
      expect(container.read(profileProvider).name, 'Miya');
      expect(container.read(profileProvider).metricUnits, isFalse);
      expect(repo.getProfile().name, 'Miya');
    });
  });
}
