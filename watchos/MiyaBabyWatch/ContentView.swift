/// Main watch UI: live status + one-tap logging.
import SwiftUI

struct ContentView: View {
    @EnvironmentObject var session: WatchSessionManager
    @State private var showDiaperSheet = false
    @State private var showNursingSheet = false

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                statusCard

                Button {
                    showNursingSheet = true
                } label: {
                    Label(session.nursingActiveSince == nil ? "Nurse" : "Stop nursing",
                          systemImage: "figure.child")
                }
                .buttonStyle(.borderedProminent)
                .tint(session.nursingActiveSince == nil ? .pink : .red)
                // Starting a timer needs a live phone; stopping an active one
                // stays enabled offline (the stop is queued and syncs later).
                .disabled(!session.phoneReachable && session.nursingActiveSince == nil)

                Button {
                    session.logBottle(amountMl: 120)
                } label: {
                    Label("Bottle 120 ml", systemImage: "cup.and.saucer")
                }
                .buttonStyle(.bordered)

                Button {
                    showDiaperSheet = true
                } label: {
                    Label("Diaper", systemImage: "drop")
                }
                .buttonStyle(.bordered)

                Button {
                    if session.sleepActiveSince == nil {
                        session.startSleep()
                    } else {
                        session.stopSleep()
                    }
                } label: {
                    Label(session.sleepActiveSince == nil ? "Start sleep" : "Stop sleep",
                          systemImage: "bed.double")
                }
                .buttonStyle(.bordered)
                .tint(session.sleepActiveSince == nil ? .blue : .orange)

                if let error = session.lastError {
                    Text(error)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if !session.phoneReachable {
                    Text("iPhone not reachable — logs will sync when it is.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.vertical, 8)
        }
        .sheet(isPresented: $showDiaperSheet) {
            VStack(spacing: 8) {
                Text("Diaper").font(.headline)
                ForEach(["wet", "dirty", "mixed"], id: \.self) { kind in
                    Button(kind.capitalized) {
                        session.logDiaper(kind: kind)
                        showDiaperSheet = false
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .sheet(isPresented: $showNursingSheet) {
            VStack(spacing: 8) {
                if session.nursingActiveSince == nil {
                    Text("Nursing side").font(.headline)
                    Button("Left") {
                        session.startNursing(side: "left")
                        showNursingSheet = false
                    }
                    .buttonStyle(.bordered)
                    Button("Right") {
                        session.startNursing(side: "right")
                        showNursingSheet = false
                    }
                    .buttonStyle(.bordered)
                } else {
                    Text("Nursing in progress").font(.headline)
                    if let since = session.nursingActiveSince {
                        Text("since \(since, style: .time)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Button("Stop") {
                        session.stopNursing()
                        showNursingSheet = false
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                }
            }
        }
        .onAppear {
            // Refresh from the phone's latest snapshot whenever the view appears.
            session.requestSnapshot()
        }
    }

    /// Latest feed/diaper/sleep plus any running timers.
    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            statusRow(icon: "cup.and.saucer", text: session.lastFeedText)
            statusRow(icon: "drop", text: session.lastDiaperText)
            statusRow(icon: "bed.double", text: session.lastSleepText)
            if let since = session.sleepActiveSince {
                Text("Sleeping since \(since, style: .time)")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func statusRow(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(text)
                .font(.caption2)
                .lineLimit(1)
        }
    }
}
