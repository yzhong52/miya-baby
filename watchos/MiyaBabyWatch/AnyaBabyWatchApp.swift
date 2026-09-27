/// Entry point for the Miya Baby watchOS companion app.
import SwiftUI

@main
struct MiyaBabyWatchApp: App {
    @StateObject private var session = WatchSessionManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(session)
        }
    }
}
