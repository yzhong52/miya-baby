/// JSON export of everything the app tracks.
///
/// Settings > "Export data (JSON)" turns this into indented text and opens
/// the system share sheet, so a parent can save it to Files, email it, etc.
/// It is the only way to get data out of the app: a manual backup today,
/// and still useful after the move to Firestore for keeping a copy outside
/// Firebase or moving to another tracker. Nothing is written to disk here.
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
