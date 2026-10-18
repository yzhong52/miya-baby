/// WCSession manager for the watch app.
///
/// - Sends log actions to the iPhone via `sendMessage` (phone is source
///   of truth; all persistence happens there).
/// - Receives status snapshots via `updateApplicationContext` from the
///   phone (last feed/diaper/sleep + active timers).
import Combine
import WatchConnectivity

final class WatchSessionManager: NSObject, ObservableObject {
    static let shared = WatchSessionManager()

    @Published var lastFeedText: String = "—"
    @Published var lastDiaperText: String = "—"
    @Published var lastSleepText: String = "—"
    @Published var sleepActiveSince: Date?
    @Published var nursingActiveSince: Date?
    @Published var phoneReachable = false
    @Published var lastError: String?

    private override init() {
        super.init()
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
    }

    // MARK: - Actions sent to the phone

    func logDiaper(kind: String) {
        send(["action": "logDiaper", "diaperKind": kind])
    }

    func logBottle(amountMl: Double) {
        send(["action": "logBottle", "amountMl": amountMl])
    }

    func startNursing(side: String) {
        send(["action": "startNursing", "side": side])
    }

    func stopNursing() {
        send(["action": "stopNursing"])
    }

    func startSleep() {
        send(["action": "startSleep"])
    }

    func stopSleep() {
        send(["action": "stopSleep"])
    }

    func requestSnapshot() {
        send(["action": "requestSnapshot"])
    }

    private func send(_ message: [String: Any]) {
        let session = WCSession.default
        guard session.activationState == .activated else {
            lastError = "Watch session not active"
            return
        }
        // If the phone isn't reachable, queue as a background transfer instead.
        if session.isReachable {
            session.sendMessage(message, replyHandler: nil) { [weak self] error in
                DispatchQueue.main.async {
                    self?.lastError = error.localizedDescription
                }
            }
        } else {
            session.transferUserInfo(message)
        }
    }

    // MARK: - Snapshot parsing

    private func applySnapshot(_ context: [String: Any]) {
        DispatchQueue.main.async {
            if let feed = context["lastFeed"] as? [String: Any] {
                self.lastFeedText = Self.describe(feed)
            }
            if let diaper = context["lastDiaper"] as? [String: Any] {
                self.lastDiaperText = Self.describe(diaper)
            }
            if let sleep = context["lastSleep"] as? [String: Any] {
                self.lastSleepText = Self.describe(sleep)
            }
            self.sleepActiveSince = Self.parseDate(context["activeSleepStart"])
            self.nursingActiveSince = Self.parseDate(context["activeNursingStart"])
        }
    }

    // The phone sends UTC ISO 8601 from Dart, e.g. "2026-10-03T10:15:30.123456Z".
    // The default ISO8601DateFormatter rejects fractional seconds, and the
    // fractional one rejects strings without them, so try both.
    private static let isoFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    private static let isoPlain = ISO8601DateFormatter()

    static func parseDate(_ value: Any?) -> Date? {
        guard let iso = value as? String else { return nil }
        return isoFractional.date(from: iso) ?? isoPlain.date(from: iso)
    }

    private static func describe(_ event: [String: Any]) -> String {
        guard let date = parseDate(event["startTime"]) else {
            return "—"
        }
        let fmt = DateFormatter()
        fmt.timeStyle = .short
        let time = fmt.string(from: date)
        let type = event["type"] as? String ?? ""
        let data = event["data"] as? [String: Any] ?? [:]
        switch type {
        case "feeding":
            let kind = data["feedKind"] as? String ?? ""
            if kind == "bottle", let ml = data["amountMl"] as? Double {
                return "Bottle \(Int(ml)) ml · \(time)"
            }
            if kind == "nursing", let side = data["side"] as? String {
                return "Nursing \(side) · \(time)"
            }
            return "Feed · \(time)"
        case "diaper":
            let kind = data["diaperKind"] as? String ?? "wet"
            return "Diaper \(kind) · \(time)"
        case "sleep":
            return "Sleep · \(time)"
        default:
            return time
        }
    }
}

// MARK: - WCSessionDelegate

extension WatchSessionManager: WCSessionDelegate {
    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        DispatchQueue.main.async {
            self.phoneReachable = session.isReachable
            if let error = error {
                self.lastError = error.localizedDescription
            }
        }
        // Pull the latest snapshot whenever the session activates.
        applySnapshot(session.receivedApplicationContext)
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.phoneReachable = session.isReachable
        }
    }

    func session(
        _ session: WCSession,
        didReceiveApplicationContext applicationContext: [String: Any]
    ) {
        applySnapshot(applicationContext)
    }
}
