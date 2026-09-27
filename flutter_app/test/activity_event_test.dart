import 'package:flutter_test/flutter_test.dart';
import 'package:miya_baby/models/activity_event.dart';

ActivityEvent _event({
  String id = 'e1',
  EventType type = EventType.feeding,
  DateTime? start,
  DateTime? end,
  Map<String, dynamic> data = const {},
  String? note,
}) {
  final s = start ?? DateTime(2026, 9, 27, 10, 0);
  return ActivityEvent(
    id: id,
    type: type,
    startTime: s,
    endTime: end,
    data: data,
    note: note,
    createdAt: s,
  );
}

void main() {
  group('ActivityEvent JSON round-trip', () {
    test('serializes and deserializes all fields', () {
      final e = _event(
        end: DateTime(2026, 9, 27, 10, 30),
        data: {'feedKind': 'nursing', 'side': 'left'},
        note: 'good latch',
      );
      final restored = ActivityEvent.fromJson(e.toJson());
      expect(restored.id, e.id);
      expect(restored.type, e.type);
      expect(restored.startTime, e.startTime);
      expect(restored.endTime, e.endTime);
      expect(restored.data, e.data);
      expect(restored.note, e.note);
      expect(restored.createdAt, e.createdAt);
    });

    test('nullable fields survive a round-trip', () {
      final e = _event();
      final restored = ActivityEvent.fromJson(e.toJson());
      expect(restored.endTime, isNull);
      expect(restored.note, isNull);
    });
  });

  group('isActive / duration', () {
    test('active timer has no endTime and active flag', () {
      final e = _event(data: {'active': true});
      expect(e.isActive, isTrue);
      expect(e.duration, isNull);
    });

    test('stopped timer is not active and has duration', () {
      final e = _event(
        end: DateTime(2026, 9, 27, 10, 25),
        data: {'active': false},
      );
      expect(e.isActive, isFalse);
      expect(e.duration, const Duration(minutes: 25));
    });
  });

  group('summary()', () {
    test('nursing shows side and minutes', () {
      final e = _event(
        end: DateTime(2026, 9, 27, 10, 12),
        data: {'feedKind': 'nursing', 'side': 'left'},
      );
      expect(e.summary(), 'Nursing · Left · 12 min');
    });

    test('bottle shows ml in metric and oz in imperial', () {
      final e = _event(data: {'feedKind': 'bottle', 'amountMl': 120.0});
      expect(e.summary(), 'Bottle · 120 ml');
      expect(e.summary(metric: false), 'Bottle · 4.1 oz');
    });

    test('solids with and without food', () {
      expect(_event(data: {'feedKind': 'solids'}).summary(), 'Solids');
      expect(
        _event(data: {'feedKind': 'solids', 'food': 'banana'}).summary(),
        'Solids · banana',
      );
    });

    test('diaper shows kind', () {
      final e = _event(
        type: EventType.diaper,
        data: {'diaperKind': 'dirty'},
      );
      expect(e.summary(), 'Diaper · Dirty');
    });

    test('sleep shows minutes or ongoing', () {
      final done = _event(
        type: EventType.sleep,
        start: DateTime(2026, 9, 27, 13, 0),
        end: DateTime(2026, 9, 27, 14, 30),
      );
      expect(done.summary(), 'Sleep · 90 min');
      final ongoing = _event(type: EventType.sleep, data: {'active': true});
      expect(ongoing.summary(), 'Sleep · ongoing');
    });

    test('growth shows weight/height/head', () {
      final e = _event(
        type: EventType.growth,
        data: {'weightKg': 8.5, 'heightCm': 70.0, 'headCm': 44.0},
      );
      expect(e.summary(), 'Growth · 8.50 kg · 70.0 cm · head 44.0 cm');
      expect(
        e.summary(metric: false),
        'Growth · 18.7 lb · 27.6 in · head 17.3 in',
      );
    });

    test('note echoes trimmed text', () {
      expect(
          _event(type: EventType.note, note: '  fussy  ').summary(), 'fussy');
      expect(_event(type: EventType.note).summary(), 'Note');
    });
  });

  group('copyWith', () {
    test('replaces only provided fields', () {
      final e = _event(note: 'old');
      final c = e.copyWith(note: 'new', data: {'x': 1});
      expect(c.note, 'new');
      expect(c.data, {'x': 1});
      expect(c.id, e.id);
      expect(c.type, e.type);
    });
  });
}
