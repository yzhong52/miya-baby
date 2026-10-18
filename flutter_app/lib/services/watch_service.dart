/// Bridge between Dart and the native iOS WatchConnectivity layer.
///
/// The iOS side (`ios/Runner/WatchBridge.swift`) owns the WCSession and
/// forwards watch messages here over the `miya_baby/watch` method channel.
/// Dart handles them (log actions) and pushes snapshots back to the watch.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/activity_event.dart';

typedef WatchActionHandler = Future<void> Function(Map<String, dynamic> msg);

/// Method names on the `miya_baby/watch` channel. These are a contract with
/// the iOS side and must match `WatchBridge.Method` in
/// `ios/Runner/WatchBridge.swift`.
abstract final class WatchMethod {
  /// iOS -> Dart: a watch action, `{action, ...}`; see
  /// [WatchService.buildHandler].
  static const watchMessage = 'watchMessage';

  /// Dart -> iOS: a status snapshot to send to the watch.
  static const pushSnapshot = 'pushSnapshot';

  /// Dart -> iOS: Dart's handler is wired; flush buffered watch messages.
  static const ready = 'ready';
}

class WatchService {
  /// Must match `WatchBridge.channelName` in `ios/Runner/WatchBridge.swift`.
  static const _channel = MethodChannel('miya_baby/watch');

  WatchActionHandler? _onWatchMessage;

  /// Inbox of watch messages not yet handled, oldest first, each with a
  /// completer that [receive] returns. Messages wait here when they arrive
  /// before [onWatchMessage] is set (e.g. right after a cold start) or while
  /// an earlier message is still being handled.
  final _pending = <(Map<String, dynamic>, Completer<void>)>[];

  /// Whether [_drain] is currently working through [_pending]; stops a
  /// second loop from starting and handling messages concurrently.
  bool _draining = false;

  WatchActionHandler? get onWatchMessage => _onWatchMessage;

  /// Handler for watch actions. Messages that arrived before it was set
  /// are queued and replayed, in order, as soon as it is.
  set onWatchMessage(WatchActionHandler? handler) {
    _onWatchMessage = handler;
    _drain();
  }

  /// Start listening for messages from the native watch bridge.
  ///
  /// Installed once at startup; every `watchMessage` from iOS is forwarded
  /// to [onWatchMessage]. Call [markReady] once that handler is set.
  void init() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == WatchMethod.watchMessage) {
        await receive(Map<String, dynamic>.from(call.arguments as Map));
      }
    });
  }

  /// Tell the native bridge Dart can take messages, so it flushes anything
  /// it buffered while Dart was starting (e.g. a background launch to
  /// deliver queued `transferUserInfo` actions).
  Future<void> markReady() async {
    try {
      await _channel.invokeMethod(WatchMethod.ready);
    } on PlatformException {
      // Bridge unavailable — nothing was buffered.
    } on MissingPluginException {
      // No native bridge (e.g. Android) — nothing was buffered.
    }
  }

  /// Queue [msg] and process it once [onWatchMessage] is set. Messages are
  /// handled one at a time, in arrival order; the returned future completes
  /// when this message has been handled.
  @visibleForTesting
  Future<void> receive(Map<String, dynamic> msg) {
    final done = Completer<void>();
    _pending.add((msg, done));
    _drain();
    return done.future;
  }

  /// "Drains" the [_pending] inbox: hands each queued watch message to
  /// [onWatchMessage], one at a time and in arrival order, until the inbox
  /// is empty. Called whenever a message arrives and when the handler is
  /// set. Does nothing while no handler is set, so messages stay queued.
  Future<void> _drain() async {
    if (_draining) return; // The running loop will pick up new messages.
    _draining = true;
    try {
      while (_onWatchMessage != null && _pending.isNotEmpty) {
        final (msg, done) = _pending.removeAt(0);
        try {
          await _onWatchMessage!(msg);
        } catch (e, st) {
          // Report and keep going so one bad message can't stall the queue.
          FlutterError.reportError(FlutterErrorDetails(
            exception: e,
            stack: st,
            library: 'watch_service',
            context: ErrorDescription('handling watch message $msg'),
          ));
        } finally {
          done.complete();
        }
      }
    } finally {
      _draining = false;
    }
  }

  /// Push a status snapshot to the watch via updateApplicationContext.
  Future<void> pushSnapshot(Map<String, dynamic> payload) async {
    try {
      await _channel.invokeMethod(WatchMethod.pushSnapshot, payload);
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
  ///
  /// Every action may carry `at`, the ISO 8601 time it was tapped on the
  /// watch. Actions queued while the phone was unreachable can arrive much
  /// later, so `at` (not arrival time) is used as the event / timer time.
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
      DateTime? at,
    }) startTimer,
    required Future<ActivityEvent?> Function(EventType type, {DateTime? at})
        stopTimer,
  }) {
    return (msg) async {
      final action = msg['action'] as String?;
      final at = tappedAt(msg['at']);
      switch (action) {
        case 'logDiaper':
          await logInstant(
            type: EventType.diaper,
            data: {
              'diaperKind':
                  (msg['diaperKind'] as String?) ?? DiaperKind.wet.name,
            },
            at: at,
          );
          break;
        case 'logBottle':
          await logInstant(
            type: EventType.feeding,
            data: {
              'feedKind': FeedKind.bottle.name,
              // Fall back to a typical 120 ml bottle when the watch omits it.
              'amountMl': (msg['amountMl'] as num?)?.toDouble() ?? 120.0,
            },
            at: at,
          );
          break;
        case 'startNursing':
          await startTimer(
            type: EventType.feeding,
            data: {
              'feedKind': FeedKind.nursing.name,
              // Default to the left side when the watch omits it.
              'side': (msg['side'] as String?) ?? 'left',
            },
            at: at,
          );
          break;
        case 'stopNursing':
          await stopTimer(EventType.feeding, at: at);
          break;
        case 'startSleep':
          await startTimer(type: EventType.sleep, at: at);
          break;
        case 'stopSleep':
          await stopTimer(EventType.sleep, at: at);
          break;
        case 'requestSnapshot':
          // Snapshot is pushed after every mutation anyway.
          break;
      }
    };
  }

  /// Parse the watch's `at` timestamp as local time. Missing or malformed
  /// values give null (use "now"); a time in the future, from clock skew
  /// between watch and phone, is clamped to now.
  @visibleForTesting
  static DateTime? tappedAt(Object? value) {
    if (value is! String) return null;
    final parsed = DateTime.tryParse(value)?.toLocal();
    if (parsed == null) return null;
    final now = DateTime.now();
    return parsed.isAfter(now) ? now : parsed;
  }
}
