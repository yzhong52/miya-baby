import 'package:flutter_test/flutter_test.dart';
import 'package:miya_baby/models/activity_event.dart';
import 'package:miya_baby/services/stats.dart';

ActivityEvent _event(
  EventType type,
  DateTime start, {
  DateTime? end,
  Map<String, dynamic> data = const {},
}) {
  return ActivityEvent(
    id: '${type.name}-${start.toIso8601String()}',
    type: type,
    startTime: start,
    endTime: end,
    data: data,
    createdAt: start,
  );
}

void main() {
  final now = DateTime(2026, 9, 27, 12, 0); // a Sunday

  List<ActivityEvent> sample() => [
        // Today: 2 bottles, 1 nursing (20 min), 1 diaper, 90 min sleep.
        _event(EventType.feeding, DateTime(2026, 9, 27, 8, 0),
            end: DateTime(2026, 9, 27, 8, 0),
            data: {'feedKind': 'bottle', 'amountMl': 120.0}),
        _event(EventType.feeding, DateTime(2026, 9, 27, 11, 0),
            end: DateTime(2026, 9, 27, 11, 0),
            data: {'feedKind': 'bottle', 'amountMl': 150.0}),
        _event(EventType.feeding, DateTime(2026, 9, 27, 9, 0),
            end: DateTime(2026, 9, 27, 9, 20),
            data: {'feedKind': 'nursing', 'side': 'left'}),
        _event(EventType.diaper, DateTime(2026, 9, 27, 10, 0),
            end: DateTime(2026, 9, 27, 10, 0), data: {'diaperKind': 'wet'}),
        _event(EventType.sleep, DateTime(2026, 9, 27, 13, 0),
            end: DateTime(2026, 9, 27, 14, 30)),
        // Yesterday: 1 diaper.
        _event(EventType.diaper, DateTime(2026, 9, 26, 10, 0),
            end: DateTime(2026, 9, 26, 10, 0), data: {'diaperKind': 'dirty'}),
        // 10 days ago: outside the window, must be ignored.
        _event(EventType.feeding, DateTime(2026, 9, 17, 8, 0),
            end: DateTime(2026, 9, 17, 8, 0),
            data: {'feedKind': 'bottle', 'amountMl': 999.0}),
        // Growth + note today: counted in feeds? No — ignored by stats.
        _event(EventType.growth, DateTime(2026, 9, 27, 15, 0),
            end: DateTime(2026, 9, 27, 15, 0), data: {'weightKg': 8.5}),
        _event(EventType.note, DateTime(2026, 9, 27, 16, 0),
            end: DateTime(2026, 9, 27, 16, 0)),
      ];

  test('aggregates a day correctly and ignores out-of-window events', () {
    final stats = computeDayStats(sample(), now: now);
    expect(stats.length, 7);

    final today = stats[DateTime(2026, 9, 27)]!;
    expect(today.feeds, 3);
    expect(today.bottleMl, 270.0);
    expect(today.nursingMin, 20);
    expect(today.diapers, 1);
    expect(today.sleepMin, 90);

    final yesterday = stats[DateTime(2026, 9, 26)]!;
    expect(yesterday.feeds, 0);
    expect(yesterday.diapers, 1);

    // Oldest day in window has nothing.
    final oldest = stats[DateTime(2026, 9, 21)]!;
    expect(oldest.feeds, 0);
    expect(oldest.bottleMl, 0);
    expect(oldest.sleepMin, 0);
    expect(oldest.diapers, 0);
  });

  test('ongoing timers do not inflate minute totals', () {
    final events = [
      _event(EventType.sleep, DateTime(2026, 9, 27, 11, 30),
          data: {'active': true}),
    ];
    final today = computeDayStats(events, now: now)[DateTime(2026, 9, 27)]!;
    expect(today.sleepMin, 0);
  });

  test('empty event list yields zeroed days', () {
    final stats = computeDayStats([], now: now);
    expect(stats.length, 7);
    expect(stats.values.every((s) => s.feeds == 0 && s.diapers == 0), isTrue);
  });
}
