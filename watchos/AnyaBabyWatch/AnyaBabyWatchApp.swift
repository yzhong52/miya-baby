/// Entry point for the Anya Baby watchOS companion app.
import SwiftUI

@main
struct AnyaBabyWatchApp: App {
    @StateObject private var session = WatchSessionManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(session)
        }
    }
}
