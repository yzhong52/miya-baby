/// JSON export of everything the app tracks, for share/export in Settings.
library;

import '../models/activity_event.dart';
import '../models/baby_profile.dart';

Map<String, dynamic> exportJson(
  BabyProfile profile,
  List<ActivityEvent> events,
) =>
    {
      'app': 'miya_baby',
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'profile': profile.toJson(),
      'events': events.map((e) => e.toJson()).toList(),
    };
