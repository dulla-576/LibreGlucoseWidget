import SwiftUI

struct DashboardView: View {
    let state: AppModel.DashboardState
    let onRefresh: () -> Void
    let onReconnect: () -> Void
    let onSignOut: () -> Void

    @State private var confirmsSignOut = false

    var body: some View {
        List {
            Section("Latest reading") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(state.reading.valueText)
                            .font(.system(size: 52, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                        Text(state.reading.trendArrow)
                            .font(.system(size: 34, weight: .semibold))
                        Text(state.reading.unitText)
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }

                    Text("Measured at \(state.reading.timestampText) · \(state.reading.ageText)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if state.reading.isStale {
                        Label("STALE — open Libre to verify", systemImage: "clock.badge.exclamationmark")
                            .font(.caption.weight(.semibold))
                    } else if state.isCached {
                        Label("Showing the last saved reading", systemImage: "wifi.slash")
                            .font(.caption)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(
                    "Glucose \(state.reading.valueText) \(state.reading.unitText), trend \(state.reading.trendArrow), measured \(state.reading.ageText)"
                )
            }

            Section("Connection") {
                LabeledContent("Profile", value: state.profileName)
                Button("Refresh now", systemImage: "arrow.clockwise", action: onRefresh)
                Button("Reconnect account", systemImage: "person.crop.circle.badge.arrow.trianglehead.counterclockwise", action: onReconnect)
                Button("Sign out", systemImage: "rectangle.portrait.and.arrow.right", role: .destructive) {
                    confirmsSignOut = true
                }
            }

            Section {
                DisclaimerView()
            }
        }
        .navigationTitle("Libre Glucose")
        .confirmationDialog(
            "Remove LibreLinkUp credentials and the saved reading?",
            isPresented: $confirmsSignOut,
            titleVisibility: .visible
        ) {
            Button("Sign out and remove data", role: .destructive, action: onSignOut)
            Button("Cancel", role: .cancel) {}
        }
    }
}
