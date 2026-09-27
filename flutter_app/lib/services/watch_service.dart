/// Bridge between Dart and the native iOS WatchConnectivity layer.
///
/// The iOS side (`ios/Runner/WatchBridge.swift`) owns the WCSession and
/// forwards watch messages here over the `anya_baby/watch` method channel.
/// Dart handles them (log actions) and pushes snapshots back to the watch.
library;

import 'package:flutter/services.dart';

import '../models/activity_event.dart';

typedef WatchActionHandler = Future<void> Function(Map<String, dynamic> msg);

class WatchService {
  static const _channel = MethodChannel('anya_baby/watch');

  WatchActionHandler? onWatchMessage;

  void init() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'watchMessage') {
        final args = Map<String, dynamic>.from(call.arguments as Map);
        await onWatchMessage?.call(args);
      }
    });
  }

  /// Push a status snapshot to the watch via updateApplicationContext.
  Future<void> pushSnapshot(Map<String, dynamic> payload) async {
    try {
      await _channel.invokeMethod('pushSnapshot', payload);
    } on PlatformException {
      // Watch bridge unavailable (e.g. Android, or no watch paired) — fine.
    } on MissingPluginException {
      // Not wired natively yet — fine.
    }
  }

  /// Build a watch action handler bound to the app's event logic.
  ///
  /// Supported incoming actions from the watch:
  /// * `logDiaper` {diaperKind}
  /// * `logBottle` {amountMl}
  /// * `startNursing` {side}
  /// * `stopNursing`
  /// * `startSleep` / `stopSleep`
  /// * `requestSnapshot`
  static WatchActionHandler buildHandler({
    required Future<ActivityEvent> Function({
      required EventType type,
      Map<String, dynamic> data,
      String? note,
      DateTime? at,
    }) logInstant,
    required Future<ActivityEvent> Function({
      required EventType type,
      Map<String, dynamic> data,
      String? note,
    }) startTimer,
    required Future<ActivityEvent?> Function(EventType type) stopTimer,
  }) {
    return (msg) async {
      final action = msg['action'] as String?;
      switch (action) {
        case 'logDiaper':
          await logInstant(
            type: EventType.diaper,
            data: {
              'diaperKind':
                  (msg['diaperKind'] as String?) ?? DiaperKind.wet.name,
            },
          );
          break;
        case 'logBottle':
          await logInstant(
            type: EventType.feeding,
            data: {
              'feedKind': FeedKind.bottle.name,
              'amountMl': (msg['amountMl'] as num?)?.toDouble() ?? 120.0,
            },
          );
          break;
        case 'startNursing':
          await startTimer(
            type: EventType.feeding,
            data: {
              'feedKind': FeedKind.nursing.name,
              'side': (msg['side'] as String?) ?? 'left',
            },
          );
          break;
        case 'stopNursing':
          await stopTimer(EventType.feeding);
          break;
        case 'startSleep':
          await startTimer(type: EventType.sleep);
          break;
        case 'stopSleep':
          await stopTimer(EventType.sleep);
          break;
        case 'requestSnapshot':
          // Snapshot is pushed after every mutation anyway.
          break;
      }
    };
  }
}
