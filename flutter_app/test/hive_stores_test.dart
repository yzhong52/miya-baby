import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:miya_baby/data/hive_stores.dart';
import 'package:miya_baby/models/activity_event.dart';
import 'package:miya_baby/models/baby_profile.dart';

ActivityEvent _event(String id, DateTime at) => ActivityEvent(
      id: id,
      type: EventType.diaper,
      startTime: at,
      endTime: at,
      data: const {'diaperKind': 'wet'},
      createdAt: at,
    );

List<String> _ids(List<ActivityEvent> events) => [for (final e in events) e.id];

void main() {
  late Directory dir;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('hive_stores_test');
    Hive.init(dir.path);
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    dir.deleteSync(recursive: true);
  });

  group('HiveEventStore', () {
    test('emits the current events, newest first, then each change', () async {
      final store = await HiveEventStore.open();
      await store.save(_event('a', DateTime(2026, 10, 1, 9)));

      final emitted = <List<String>>[];
      final sub = store.watchEvents().listen((l) => emitted.add(_ids(l)));
      await pumpEventQueue();
      await store.save(_event('b', DateTime(2026, 10, 1, 11)));
      await pumpEventQueue();
      await store.delete('a');
      await pumpEventQueue();
      await sub.cancel();

      expect(emitted, [
        ['a'],
        ['b', 'a'],
        ['b'],
      ]);
    });

    test('skips corrupt entries', () async {
      final store = await HiveEventStore.open();
      final box = Hive.box('events'); // the box the store just opened
      await box.put('junk', {'type': 'nope'});
      await box.put('text', 'not a map');
      await store.save(_event('ok', DateTime(2026, 10, 1)));

      expect(_ids(await store.watchEvents().first), ['ok']);
    });
  });

  group('HiveProfileStore', () {
    test('defaults until saved, then emits the saved profile', () async {
      final store = await HiveProfileStore.open();
      final names = <String>[];
      final sub = store.watchProfile().listen((p) => names.add(p.name));
      await pumpEventQueue();
      await store.save(const BabyProfile(name: 'Kai'));
      await pumpEventQueue();
      await sub.cancel();

      expect(names, ['Miya', 'Kai']);
    });
  });
}
