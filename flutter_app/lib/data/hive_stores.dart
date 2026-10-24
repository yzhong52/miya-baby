/// Hive-backed [EventStore] and [ProfileStore], storing JSON on this device.
///
/// A Hive "box" is a named key-value table, saved as one file on disk:
///
/// * `events` box: key = event id, value = [ActivityEvent.toJson] map.
/// * `settings` box: single `profile` key with the baby profile JSON.
library;

import 'dart:async';

import 'package:hive/hive.dart';

import '../models/activity_event.dart';
import '../models/baby_profile.dart';
import 'stores.dart';

class HiveEventStore implements EventStore {
  static const _boxName = 'events';

  /// The `events` box: event id -> [ActivityEvent.toJson] map.
  final Box _box;
  HiveEventStore._(this._box);

  /// Open the `events` box. Call `Hive.initFlutter()` (or `Hive.init` in
  /// tests) first.
  static Future<HiveEventStore> open() async =>
      HiveEventStore._(await Hive.openBox(_boxName));

  @override
  Stream<List<ActivityEvent>> watchEvents() =>
      _readOnChange(_box.watch(), _all);

  /// All events, newest first. Corrupt entries are skipped rather than
  /// crashing the read.
  List<ActivityEvent> _all() {
    final list = <ActivityEvent>[];
    for (final raw in _box.values) {
      if (raw is Map) {
        try {
          list.add(ActivityEvent.fromJson(Map<String, dynamic>.from(raw)));
        } catch (_) {
          // Skip corrupt entries rather than crashing.
        }
      }
    }
    list.sort((a, b) => b.startTime.compareTo(a.startTime));
    return list;
  }

  @override
  Future<void> save(ActivityEvent event) => _box.put(event.id, event.toJson());

  @override
  Future<void> delete(String id) => _box.delete(id);
}

class HiveProfileStore implements ProfileStore {
  static const _boxName = 'settings';
  static const _profileKey = 'profile';

  /// The `settings` box; the profile JSON lives under [_profileKey].
  final Box _box;
  HiveProfileStore._(this._box);

  /// Open the `settings` box. Call `Hive.initFlutter()` (or `Hive.init` in
  /// tests) first.
  static Future<HiveProfileStore> open() async =>
      HiveProfileStore._(await Hive.openBox(_boxName));

  @override
  Stream<BabyProfile> watchProfile() =>
      _readOnChange(_box.watch(key: _profileKey), _get);

  /// The saved profile, or defaults when nothing (or corrupt data) is stored.
  BabyProfile _get() {
    final raw = _box.get(_profileKey);
    if (raw is Map) {
      try {
        return BabyProfile.fromJson(Map<String, dynamic>.from(raw));
      } catch (_) {}
    }
    return const BabyProfile();
  }

  @override
  Future<void> save(BabyProfile profile) =>
      _box.put(_profileKey, profile.toJson());
}

/// Emits [read]() on listen and again after every event on [changes].
///
/// Not an `async*` generator: cancelling one that is waiting inside
/// `await for` hangs until [changes] emits again, which for a quiet box
/// may be never.
Stream<T> _readOnChange<T>(Stream<Object?> changes, T Function() read) {
  StreamSubscription<Object?>? sub;
  late final StreamController<T> controller;
  controller = StreamController<T>(
    onListen: () {
      controller.add(read());
      sub = changes.listen((_) => controller.add(read()));
    },
    onPause: () => sub?.pause(),
    onResume: () => sub?.resume(),
    onCancel: () => sub?.cancel(),
  );
  return controller.stream;
}
