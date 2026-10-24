import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miya_baby/models/activity_event.dart';
import 'package:miya_baby/models/baby_profile.dart';
import 'package:miya_baby/state/providers.dart';

import 'fakes.dart';

ProviderContainer _container(
  InMemoryEventStore store,
  InMemoryProfileStore profiles,
  FakeWatch watch,
) {
  return ProviderContainer(
    overrides: [
      eventStoreProvider.overrideWithValue(store),
      profileStoreProvider.overrideWithValue(profiles),
      watchServiceProvider.overrideWithValue(watch),
    ],
  );
}

void main() {
  group('EventsNotifier', () {
    late InMemoryEventStore store;
    late FakeWatch watch;
    late ProviderContainer container;

    setUp(() {
      store = InMemoryEventStore();
      watch = FakeWatch();
      container = _container(store, InMemoryProfileStore(), watch);
    });

    tearDown(() => container.dispose());

    test('logInstant adds an event, saves it and pushes a snapshot', () async {
      final notifier = container.read(eventsProvider.notifier);
      final e = await notifier.logInstant(
        type: EventType.diaper,
        data: {'diaperKind': 'wet'},
        at: DateTime(2026, 9, 27, 10, 0),
      );
      // State updates before the store's stream catches up.
      final events = container.read(eventsProvider);
      expect(events.length, 1);
      expect(events.single.type, EventType.diaper);
      expect((watch.last!['lastDiaper'] as Map)['id'], e.id);

      await pumpEventQueue();
      expect(store.events.single.id, e.id);
      expect(container.read(eventsProvider).single.id, e.id);
    });

    test('loads what the store already has', () async {
      await store.save(ActivityEvent(
        id: 'old',
        type: EventType.diaper,
        startTime: DateTime(2026, 9, 27, 9, 0),
        endTime: DateTime(2026, 9, 27, 9, 0),
        data: const {},
        createdAt: DateTime(2026, 9, 27, 9, 0),
      ));
      final c = _container(store, InMemoryProfileStore(), watch);
      addTearDown(c.dispose);
      expect(c.read(eventsProvider), isEmpty);
      await pumpEventQueue();
      expect(c.read(eventsProvider).single.id, 'old');
    });

    test('changes from elsewhere reach state and the watch', () async {
      container.read(eventsProvider); // start listening
      await pumpEventQueue();
      final before = watch.snapshots;

      // Another parent's phone starts a sleep timer.
      await store.save(ActivityEvent(
        id: 'remote',
        type: EventType.sleep,
        startTime: DateTime(2026, 10, 3, 1, 0),
        data: const {'active': true},
        createdAt: DateTime(2026, 10, 3, 1, 0),
      ));
      await pumpEventQueue();

      expect(container.read(eventsProvider).single.id, 'remote');
      expect(watch.snapshots, greaterThan(before));
      expect(watch.last!['activeSleepStart'], isNotNull);
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
      expect(watch.last!['activeSleepStart'], isNull);
      expect((watch.last!['lastSleep'] as Map)['id'], stopped.id);
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
      await pumpEventQueue();
      expect(store.events, isEmpty);
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
      await pumpEventQueue(); // let the store's first emission land
      final before = watch.snapshots;
      await notifier.pushSnapshot();
      expect(watch.snapshots, before + 1);
    });
  });

  group('eventsForDayProvider', () {
    test('returns only events for the given day', () async {
      final container =
          _container(InMemoryEventStore(), InMemoryProfileStore(), FakeWatch());
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
      final profiles = InMemoryProfileStore();
      final container = _container(InMemoryEventStore(), profiles, FakeWatch());
      addTearDown(container.dispose);

      final notifier = container.read(profileProvider.notifier);
      await notifier.update(const BabyProfile(name: 'Kai', metricUnits: false));
      expect(container.read(profileProvider).name, 'Kai');
      expect(container.read(profileProvider).metricUnits, isFalse);
      await pumpEventQueue();
      expect(profiles.profile.name, 'Kai');
      expect(container.read(profileProvider).name, 'Kai');
    });

    test('loads the saved profile', () async {
      final profiles = InMemoryProfileStore()
        ..profile = const BabyProfile(name: 'Kai');
      final container = _container(InMemoryEventStore(), profiles, FakeWatch());
      addTearDown(container.dispose);

      expect(container.read(profileProvider).name, 'Miya'); // default first
      await pumpEventQueue();
      expect(container.read(profileProvider).name, 'Kai');
    });
  });
}
