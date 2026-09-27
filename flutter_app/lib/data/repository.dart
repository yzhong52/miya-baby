/// Local persistence for Miya Baby, backed by Hive boxes storing JSON.
///
/// * `events` box: key = event id, value = [ActivityEvent.toJson] map.
/// * `settings` box: single `profile` key with the baby profile JSON.
library;

import 'package:hive_flutter/hive_flutter.dart';

import '../models/activity_event.dart';
import '../models/baby_profile.dart';

class AppRepository {
  static const _eventsBox = 'events';
  static const _settingsBox = 'settings';
  static const _profileKey = 'profile';

  late final Box _events;
  late final Box _settings;

  Future<void> init() async {
    await Hive.initFlutter();
    _events = await Hive.openBox(_eventsBox);
    _settings = await Hive.openBox(_settingsBox);
  }

  // ---------------------------------------------------------------- events

  List<ActivityEvent> getAllEvents() {
    final list = <ActivityEvent>[];
    for (final key in _events.keys) {
      final raw = _events.get(key);
      if (raw is Map) {
        try {
          list.add(ActivityEvent.fromJson(
              Map<String, dynamic>.from(raw as Map)));
        } catch (_) {
          // Skip corrupt entries rather than crashing.
        }
      }
    }
    list.sort((a, b) => b.startTime.compareTo(a.startTime));
    return list;
  }

  Future<void> saveEvent(ActivityEvent event) =>
      _events.put(event.id, event.toJson());

  Future<void> deleteEvent(String id) => _events.delete(id);

  Future<void> clearAllEvents() => _events.clear();

  /// Export everything as a JSON-serializable map (for share/export).
  Map<String, dynamic> exportJson(BabyProfile profile) => {
        'app': 'miya_baby',
        'version': 1,
        'exportedAt': DateTime.now().toIso8601String(),
        'profile': profile.toJson(),
        'events': getAllEvents().map((e) => e.toJson()).toList(),
      };

  // ---------------------------------------------------------------- profile

  BabyProfile getProfile() {
    final raw = _settings.get(_profileKey);
    if (raw is Map) {
      try {
        return BabyProfile.fromJson(Map<String, dynamic>.from(raw as Map));
      } catch (_) {}
    }
    return const BabyProfile();
  }

  Future<void> saveProfile(BabyProfile profile) =>
      _settings.put(_profileKey, profile.toJson());
}
