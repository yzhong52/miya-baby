/// In-memory stand-ins shared by the tests.
library;

import 'dart:async';

import 'package:miya_baby/data/stores.dart';
import 'package:miya_baby/models/activity_event.dart';
import 'package:miya_baby/models/baby_profile.dart';
import 'package:miya_baby/services/watch_service.dart';

/// [EventStore] in memory. Writing to it directly from a test plays the
/// part of a change from another device.
class InMemoryEventStore implements EventStore {
  final _events = <String, ActivityEvent>{};
  final _changes = StreamController<void>.broadcast();

  /// Everything saved, newest first.
  List<ActivityEvent> get events => _events.values.toList()
    ..sort((a, b) => b.startTime.compareTo(a.startTime));

  @override
  Stream<List<ActivityEvent>> watchEvents() async* {
    yield events;
    await for (final _ in _changes.stream) {
      yield events;
    }
  }

  @override
  Future<void> save(ActivityEvent event) async {
    _events[event.id] = event;
    _changes.add(null);
  }

  @override
  Future<void> delete(String id) async {
    _events.remove(id);
    _changes.add(null);
  }
}

/// [ProfileStore] in memory.
class InMemoryProfileStore implements ProfileStore {
  BabyProfile profile = const BabyProfile();
  final _changes = StreamController<void>.broadcast();

  @override
  Stream<BabyProfile> watchProfile() async* {
    yield profile;
    await for (final _ in _changes.stream) {
      yield profile;
    }
  }

  @override
  Future<void> save(BabyProfile profile) async {
    this.profile = profile;
    _changes.add(null);
  }
}

/// WatchService that records snapshots instead of using the platform
/// channel.
class FakeWatch extends WatchService {
  int snapshots = 0;
  Map<String, dynamic>? last;

  @override
  Future<void> pushSnapshot(Map<String, dynamic> payload) async {
    snapshots++;
    last = payload;
  }
}
