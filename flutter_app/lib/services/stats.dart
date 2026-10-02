/// Pure per-day statistics computation for Miya Baby.
///
/// Extracted from [StatsScreen] so the aggregation logic is unit-testable
/// without widgets.
library;

import '../models/activity_event.dart';

/// Aggregated counts for a single calendar day.
class DayStats {
  int feeds = 0;
  double bottleMl = 0;
  int nursingMin = 0;
  int sleepMin = 0;
  int diapers = 0;
}

/// Aggregate [events] into per-day stats for the 7 days ending at [now]
/// (inclusive). Keys are midnight-local [DateTime]s, oldest first.
Map<DateTime, DayStats> computeDayStats(
  List<ActivityEvent> events, {
  DateTime? now,
}) {
  final ref = now ?? DateTime.now();
  final days = List.generate(
      7,
      (i) => DateTime(ref.year, ref.month, ref.day)
          .subtract(Duration(days: 6 - i)));
  final stats = <DateTime, DayStats>{for (final d in days) d: DayStats()};

  for (final e in events) {
    // Bucket by local calendar day (midnight-normalized).
    final day = DateTime(e.startTime.year, e.startTime.month, e.startTime.day);
    final s = stats[day];
    if (s == null) continue;
    switch (e.type) {
      case EventType.feeding:
        s.feeds++;
        final kind =
            FeedKindX.fromName(e.data['feedKind'] as String? ?? 'nursing');
        if (kind == FeedKind.bottle) {
          s.bottleMl += (e.data['amountMl'] as num?)?.toDouble() ?? 0;
        } else if (kind == FeedKind.nursing && e.duration != null) {
          s.nursingMin += e.duration!.inMinutes;
        }
      case EventType.sleep:
        if (e.duration != null) s.sleepMin += e.duration!.inMinutes;
      case EventType.diaper:
        s.diapers++;
      case EventType.growth:
      case EventType.note:
        // Growth entries and notes don't contribute to daily totals.
        break;
    }
  }
  return stats;
}
