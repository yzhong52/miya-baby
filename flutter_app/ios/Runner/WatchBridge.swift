/// WatchBridge: relays messages between the Apple Watch (WCSession)
/// and Dart (FlutterMethodChannel "miya_baby/watch").
///
/// - Watch -> iPhone: `sendMessage` with {action, ...} is forwarded to Dart
///   via the method channel as `watchMessage`.
/// - Watch -> iPhone (background): `transferUserInfo` deliveries arrive via
///   `didReceiveUserInfo` and are forwarded to Dart as `watchMessage` too.
/// - Dart -> Watch: `pushSnapshot` calls update the application context so
///   the watch always has the latest status even when not reachable.
///
/// Wire-up: AppDelegate creates the bridge once the implicit Flutter engine
/// is initialized and hands it the engine's binary messenger
/// (see AppDelegate.swift).
import Flutter
import UIKit
import WatchConnectivity

final class WatchBridge: NSObject {
    static let channelName = "miya_baby/watch"

    private var channel: FlutterMethodChannel?
    private var session: WCSession? { WCSession.isSupported() ? WCSession.default : nil }

    func attach(to messenger: FlutterBinaryMessenger) {
        channel = FlutterMethodChannel(
            name: Self.channelName,
            binaryMessenger: messenger)
        channel?.setMethodCallHandler(handleMethodCall)

        if let session = session {
            session.delegate = self
            session.activate()
        }
    }

    private func handleMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "pushSnapshot":
            // Dart -> Watch: refresh the watch's cached status snapshot.
            // updateApplicationContext queues the latest payload and delivers it
            // when the watch is reachable, so the watch face shows current data
            // even if it was asleep or out of range when Dart sent the update.
            if let payload = call.arguments as? [String: Any] {
                pushSnapshot(payload)
            }
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func pushSnapshot(_ payload: [String: Any]) {
        guard let session = session else { return }
        do {
            try session.updateApplicationContext(payload)
        } catch {
            // Watch may not be paired; snapshots are best-effort.
        }
    }
}

// MARK: - WCSessionDelegate

extension WatchBridge: WCSessionDelegate {
    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {}

    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {}

    /// Watch -> phone (foreground): forward to Dart, then reply with an ack.
    func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        channel?.invokeMethod("watchMessage", arguments: message)
        replyHandler(["ok": true])
    }

    /// Watch -> phone (background): `transferUserInfo` payloads are queued by
    /// the system and delivered here even if the app was not running.
    /// Forward to Dart best-effort; there is no reply handler.
    func session(
        _ session: WCSession,
        didReceiveUserInfo userInfo: [String: Any] = [:]
    ) {
        channel?.invokeMethod("watchMessage", arguments: userInfo)
    }
}
