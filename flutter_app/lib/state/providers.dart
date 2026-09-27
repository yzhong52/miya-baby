/// Riverpod state for Miya Baby.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../data/repository.dart';
import '../models/activity_event.dart';
import '../models/baby_profile.dart';
import '../services/watch_service.dart';

const _uuid = Uuid();

final repositoryProvider = Provider<AppRepository>((ref) {
  throw UnimplementedError('repositoryProvider must be overridden at startup');
});

final watchServiceProvider = Provider<WatchService>((ref) {
  throw UnimplementedError('watchServiceProvider must be overridden');
});

// ------------------------------------------------------------------ profile

class ProfileNotifier extends StateNotifier<BabyProfile> {
  final AppRepository _repo;
  ProfileNotifier(this._repo) : super(_repo.getProfile());

  Future<void> update(BabyProfile profile) async {
    state = profile;
    await _repo.saveProfile(profile);
  }
}

final profileProvider =
    StateNotifierProvider<ProfileNotifier, BabyProfile>((ref) {
  return ProfileNotifier(ref.watch(repositoryProvider));
});

// ------------------------------------------------------------------- events

class EventsNotifier extends StateNotifier<List<ActivityEvent>> {
  final AppRepository _repo;
  final WatchService _watch;

  EventsNotifier(this._repo, this._watch) : super(_repo.getAllEvents());

  void _refresh() => state = _repo.getAllEvents();

  Future<ActivityEvent> add(ActivityEvent event) async {
    await _repo.saveEvent(event);
    _refresh();
    _watch.pushSnapshot(_snapshotPayload());
    return event;
  }

  Future<void> update(ActivityEvent event) async {
    await _repo.saveEvent(event);
    _refresh();
    _watch.pushSnapshot(_snapshotPayload());
  }

  Future<void> remove(String id) async {
    await _repo.deleteEvent(id);
    _refresh();
    _watch.pushSnapshot(_snapshotPayload());
  }

  /// Start a timer event (nursing or sleep). Returns the created event.
  Future<ActivityEvent> startTimer({
    required EventType type,
    Map<String, dynamic> data = const {},
    String? note,
  }) {
    final now = DateTime.now();
    return add(ActivityEvent(
      id: _uuid.v4(),
      type: type,
      startTime: now,
      endTime: null,
      data: {...data, 'active': true},
      note: note,
      createdAt: now,
    ));
  }

  /// Stop the most recent active timer of [type].
  Future<ActivityEvent?> stopTimer(EventType type) async {
    final active = state.where((e) => e.type == type && e.isActive);
    if (active.isEmpty) return null;
    final event = active.first;
    final stopped = event.copyWith(
      endTime: DateTime.now(),
      data: {...event.data, 'active': false},
    );
    await update(stopped);
    return stopped;
  }

  ActivityEvent? activeTimer(EventType type) {
    for (final e in state) {
      if (e.type == type && e.isActive) return e;
    }
    return null;
  }

  /// Log an instant event (diaper, bottle, solids, growth, note).
  Future<ActivityEvent> logInstant({
    required EventType type,
    Map<String, dynamic> data = const {},
    String? note,
    DateTime? at,
  }) {
    final now = at ?? DateTime.now();
    return add(ActivityEvent(
      id: _uuid.v4(),
      type: type,
      startTime: now,
      endTime: now,
      data: data,
      note: note,
      createdAt: DateTime.now(),
    ));
  }

  Map<String, dynamic> _snapshotPayload() {
    ActivityEvent? lastOf(EventType t) {
      for (final e in state) {
        if (e.type == t && !e.isActive) return e;
      }
      return null;
    }

    String? isoOrNull(ActivityEvent? e) =>
        e?.startTime.toIso8601String();

    return {
      'lastFeed': lastOf(EventType.feeding)?.toJson(),
      'lastDiaper': lastOf(EventType.diaper)?.toJson(),
      'lastSleep': lastOf(EventType.sleep)?.toJson(),
      'activeSleepStart': isoOrNull(activeTimer(EventType.sleep)),
      'activeNursingStart': isoOrNull(activeTimer(EventType.feeding)),
      'generatedAt': DateTime.now().toIso8601String(),
    };
  }
}

final eventsProvider =
    StateNotifierProvider<EventsNotifier, List<ActivityEvent>>((ref) {
  return EventsNotifier(
    ref.watch(repositoryProvider),
    ref.watch(watchServiceProvider),
  );
});

// ----------------------------------------------------------------- derived

/// Events for a given calendar day (local time).
final eventsForDayProvider =
    Provider.family<List<ActivityEvent>, DateTime>((ref, day) {
  final events = ref.watch(eventsProvider);
  final start = DateTime(day.year, day.month, day.day);
  final end = start.add(const Duration(days: 1));
  return events
      .where((e) =>
          !e.startTime.isBefore(start) && e.startTime.isBefore(end))
      .toList();
});

String newId() => _uuid.v4();
