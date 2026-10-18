/// WatchBridge: relays messages between the Apple Watch (WCSession)
/// and Dart (FlutterMethodChannel "miya_baby/watch").
///
/// - Watch -> iPhone: `sendMessage` with {action, ...} is forwarded to Dart
///   via the method channel as `watchMessage`.
/// - Watch -> iPhone (background): `transferUserInfo` deliveries arrive via
///   `didReceiveUserInfo` and are forwarded to Dart as `watchMessage` too.
/// - Watch messages are buffered until Dart calls `ready` (it has wired its
///   handler). A queued transfer can launch the app in the background before
///   Dart is running, and Flutter's own channel buffer keeps only one
///   message, so without this, actions could be lost on a cold start.
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
    /// Watch messages received before Dart said `ready`. Main thread only.
    private var pending: [[String: Any]] = []
    private var dartReady = false
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
        case "ready":
            // Dart has wired its watch handler: deliver anything buffered.
            dartReady = true
            let queued = pending
            pending.removeAll()
            queued.forEach(forwardToDart)
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    /// Forward a watch message to Dart, or buffer it until Dart is ready.
    /// WCSession delegate callbacks arrive on a background queue, and the
    /// channel must be used on the main thread, so always hop to main.
    private func deliver(_ message: [String: Any]) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if self.dartReady {
                self.forwardToDart(message)
            } else {
                self.pending.append(message)
            }
        }
    }

    private func forwardToDart(_ message: [String: Any]) {
        channel?.invokeMethod("watchMessage", arguments: message)
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
        deliver(message)
        replyHandler(["ok": true])
    }

    /// Watch -> phone (background): `transferUserInfo` payloads are queued by
    /// the system and delivered here even if the app was not running.
    /// Buffered until Dart is ready; there is no reply handler.
    func session(
        _ session: WCSession,
        didReceiveUserInfo userInfo: [String: Any] = [:]
    ) {
        deliver(userInfo)
    }
}
