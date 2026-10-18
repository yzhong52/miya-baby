/// Riverpod state for Miya Baby.
///
/// The base providers below are overridden in main() with real instances;
/// the [UnimplementedError] makes a missing override fail fast instead of
/// silently running with a dummy.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../data/stores.dart';
import '../models/activity_event.dart';
import '../models/baby_profile.dart';
import '../services/watch_service.dart';

const _uuid = Uuid();

final eventStoreProvider = Provider<EventStore>((ref) {
  throw UnimplementedError('eventStoreProvider must be overridden at startup');
});

final profileStoreProvider = Provider<ProfileStore>((ref) {
  throw UnimplementedError(
      'profileStoreProvider must be overridden at startup');
});

final watchServiceProvider = Provider<WatchService>((ref) {
  throw UnimplementedError('watchServiceProvider must be overridden');
});

/// Start a store write without waiting for it, and report it if it fails.
///
/// Notifiers update their own state first, so the UI never waits on the
/// store; see [EventStore.save] for why waiting could hang offline.
void _write(Future<void> write, String what) {
  write.catchError((Object e, StackTrace st) {
    FlutterError.reportError(FlutterErrorDetails(
      exception: e,
      stack: st,
      library: 'providers',
      context: ErrorDescription(what),
    ));
  });
}

// ------------------------------------------------------------------ profile

/// Holds the baby profile, kept in sync with the [ProfileStore].
class ProfileNotifier extends StateNotifier<BabyProfile> {
  final ProfileStore _store;
  late final StreamSubscription<BabyProfile> _sub;

  /// Starts on the default profile until the store's first emission.
  ProfileNotifier(this._store) : super(const BabyProfile()) {
    _sub = _store.watchProfile().listen((p) => state = p);
  }

  Future<void> update(BabyProfile profile) async {
    state = profile;
    _write(_store.save(profile), 'saving the profile');
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

final profileProvider =
    StateNotifierProvider<ProfileNotifier, BabyProfile>((ref) {
  return ProfileNotifier(ref.watch(profileStoreProvider));
});

// ------------------------------------------------------------------- events

/// Owns the event list, kept in sync with the [EventStore]. Every state
/// change, local or from the store, pushes a fresh snapshot to the watch.
class EventsNotifier extends StateNotifier<List<ActivityEvent>> {
  final EventStore _store;
  final WatchService _watch;
  late final StreamSubscription<List<ActivityEvent>> _sub;

  /// Starts empty until the store's first emission.
  EventsNotifier(this._store, this._watch) : super(const []) {
    _sub = _store.watchEvents().listen(_set);
  }

  void _set(List<ActivityEvent> events) {
    state = events;
    pushSnapshot();
  }

  /// Put [event] into state right away (newest first), ahead of the store.
  void _upsert(ActivityEvent event) {
    _set([
      for (final e in state)
        if (e.id != event.id) e,
      event,
    ]..sort((a, b) => b.startTime.compareTo(a.startTime)));
  }

  /// Add an event: update state, notify the watch, and save it.
  Future<ActivityEvent> add(ActivityEvent event) async {
    _upsert(event);
    _write(_store.save(event), 'saving event ${event.id}');
    return event;
  }

  Future<void> update(ActivityEvent event) async {
    _upsert(event);
    _write(_store.save(event), 'saving event ${event.id}');
  }

  Future<void> remove(String id) async {
    _set([
      for (final e in state)
        if (e.id != id) e,
    ]);
    _write(_store.delete(id), 'deleting event $id');
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }

  /// Start a timer event (nursing or sleep), started [at] (default now).
  /// Returns the created event.
  Future<ActivityEvent> startTimer({
    required EventType type,
    Map<String, dynamic> data = const {},
    String? note,
    DateTime? at,
  }) {
    final now = DateTime.now();
    return add(ActivityEvent(
      id: _uuid.v4(),
      type: type,
      startTime: at ?? now,
      endTime: null,
      // 'active' flags a running timer; see ActivityEvent.isActive.
      data: {...data, 'active': true},
      note: note,
      createdAt: now,
    ));
  }

  /// Stop the most recent active timer of [type] [at] (default now). An
  /// [at] before the timer's start is clamped to the start.
  Future<ActivityEvent?> stopTimer(EventType type, {DateTime? at}) async {
    final active = state.where((e) => e.type == type && e.isActive);
    if (active.isEmpty) return null;
    final event = active.first;
    final end = at ?? DateTime.now();
    final stopped = event.copyWith(
      endTime: end.isBefore(event.startTime) ? event.startTime : end,
      clearEndTime: false,
      clearNote: false,
      data: {...event.data, 'active': false},
    );
    await update(stopped);
    return stopped;
  }

  /// The running timer of [type], if any.
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

  /// Send the current [snapshotPayload] to the watch.
  Future<void> pushSnapshot() => _watch.pushSnapshot(snapshotPayload());

  /// Snapshot the watch renders: latest finished events of each kind,
  /// plus the start times of any running timers.
  ///
  /// All timestamps are UTC ISO 8601 (`...Z`). A local DateTime's
  /// toIso8601String() has no offset, which Swift's ISO8601DateFormatter
  /// rejects (see watchos/MiyaBabyWatch/WatchSessionManager.swift).
  Map<String, dynamic> snapshotPayload() {
    ActivityEvent? lastOf(EventType t) {
      for (final e in state) {
        if (e.type == t && !e.isActive) return e;
      }
      return null;
    }

    String utcIso(DateTime t) => t.toUtc().toIso8601String();

    Map<String, dynamic>? eventJson(ActivityEvent? e) => e == null
        ? null
        : {
            ...e.toJson(),
            'startTime': utcIso(e.startTime),
            'endTime': e.endTime == null ? null : utcIso(e.endTime!),
            'createdAt': utcIso(e.createdAt),
          };

    String? startOrNull(ActivityEvent? e) =>
        e == null ? null : utcIso(e.startTime);

    return {
      'lastFeed': eventJson(lastOf(EventType.feeding)),
      'lastDiaper': eventJson(lastOf(EventType.diaper)),
      'lastSleep': eventJson(lastOf(EventType.sleep)),
      'activeSleepStart': startOrNull(activeTimer(EventType.sleep)),
      'activeNursingStart': startOrNull(activeTimer(EventType.feeding)),
      'generatedAt': utcIso(DateTime.now()),
    };
  }
}

final eventsProvider =
    StateNotifierProvider<EventsNotifier, List<ActivityEvent>>((ref) {
  return EventsNotifier(
    ref.watch(eventStoreProvider),
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
      .where((e) => !e.startTime.isBefore(start) && e.startTime.isBefore(end))
      .toList();
});

String newId() => _uuid.v4();
