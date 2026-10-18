/// Storage interfaces the notifiers read and write through.
///
/// Reads are streams, so a change made anywhere (this phone, or another
/// parent's phone once the stores are backed by Firestore) reaches the UI
/// the same way. Hive implementations live in `hive_stores.dart`.
library;

import '../models/activity_event.dart';
import '../models/baby_profile.dart';

abstract interface class EventStore {
  /// Every event, newest first. Emits the current list on listen, then
  /// again after every change.
  Stream<List<ActivityEvent>> watchEvents();

  /// Insert or replace the event with [ActivityEvent.id].
  ///
  /// Callers shouldn't wait on this to update the UI: a networked store
  /// may only complete once the write reaches the server, which never
  /// happens while offline. [watchEvents] reflects the write either way.
  Future<void> save(ActivityEvent event);

  /// Delete the event with [id]; a missing id is not an error. Completes
  /// as late as [save] does.
  Future<void> delete(String id);
}

abstract interface class ProfileStore {
  /// The baby profile, or defaults when none is saved. Emits the current
  /// profile on listen, then again after every change.
  Stream<BabyProfile> watchProfile();

  /// Replace the profile. Completes as late as [EventStore.save] does.
  Future<void> save(BabyProfile profile);
}
