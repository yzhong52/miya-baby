import 'package:flutter_test/flutter_test.dart';
import 'package:miya_baby/models/activity_event.dart';
import 'package:miya_baby/services/watch_service.dart';

void main() {
  group('WatchService.buildHandler', () {
    late List<Map<String, dynamic>> logged;
    late List<Map<String, dynamic>> timersStarted;
    late List<EventType> timersStopped;
    late WatchActionHandler handler;

    setUp(() {
      logged = [];
      timersStarted = [];
      timersStopped = [];
      handler = WatchService.buildHandler(
        logInstant: ({
          required EventType type,
          Map<String, dynamic> data = const {},
          String? note,
          DateTime? at,
        }) async {
          logged.add({'type': type, 'data': data});
          return ActivityEvent(
            id: 'x',
            type: type,
            startTime: at ?? DateTime.now(),
            createdAt: DateTime.now(),
          );
        },
        startTimer: ({
          required EventType type,
          Map<String, dynamic> data = const {},
          String? note,
        }) async {
          timersStarted.add({'type': type, 'data': data});
          return ActivityEvent(
            id: 'x',
            type: type,
            startTime: DateTime.now(),
            createdAt: DateTime.now(),
          );
        },
        stopTimer: (type) async {
          timersStopped.add(type);
          return null;
        },
      );
    });

    test('logDiaper defaults to wet', () async {
      await handler({'action': 'logDiaper'});
      expect(logged.single['type'], EventType.diaper);
      expect(logged.single['data']['diaperKind'], 'wet');
    });

    test('logDiaper honors kind', () async {
      await handler({'action': 'logDiaper', 'diaperKind': 'dirty'});
      expect(logged.single['data']['diaperKind'], 'dirty');
    });

    test('logBottle defaults to 120 ml', () async {
      await handler({'action': 'logBottle'});
      expect(logged.single['type'], EventType.feeding);
      expect(logged.single['data']['feedKind'], 'bottle');
      expect(logged.single['data']['amountMl'], 120.0);
    });

    test('start/stop nursing and sleep', () async {
      await handler({'action': 'startNursing', 'side': 'right'});
      await handler({'action': 'stopNursing'});
      await handler({'action': 'startSleep'});
      await handler({'action': 'stopSleep'});
      expect(timersStarted.length, 2);
      expect(timersStarted[0]['data']['side'], 'right');
      expect(timersStopped, [EventType.feeding, EventType.sleep]);
    });

    test('unknown and snapshot actions are ignored', () async {
      await handler({'action': 'requestSnapshot'});
      await handler({'action': 'definitelyNotReal'});
      await handler({});
      expect(logged, isEmpty);
      expect(timersStarted, isEmpty);
      expect(timersStopped, isEmpty);
    });
  });
}
