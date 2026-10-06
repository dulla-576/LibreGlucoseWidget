import SwiftUI

struct RootView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        NavigationStack {
            switch model.phase {
            case .signedOut:
                SignInView { email, password in
                    Task { await model.signIn(email: email, password: password) }
                }

            case .loading:
                VStack(spacing: 16) {
                    ProgressView()
                    Text("Updating glucose reading…")
                        .foregroundStyle(.secondary)
                }
                .navigationTitle("Libre Glucose")

            case let .connected(state):
                dashboard(state)

            case let .needsAttention(message, lastReading):
                if let lastReading {
                    dashboard(lastReading)
                        .safeAreaInset(edge: .top) {
                            attentionBanner(message)
                        }
                } else {
                    ContentUnavailableView {
                        Label("Needs attention", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(message)
                    } actions: {
                        Button("Try again") {
                            Task { await model.refresh() }
                        }
                        Button("Reconnect account") {
                            Task { await model.signOut() }
                        }
                    }
                    .navigationTitle("Libre Glucose")
                }
            }
        }
        .task {
            if model.phase == .loading {
                await model.refresh()
            }
        }
    }

    @ViewBuilder
    private func dashboard(_ state: AppModel.DashboardState) -> some View {
        DashboardView(
            state: state,
            onRefresh: { Task { await model.refresh() } },
            onReconnect: { Task { await model.signOut() } },
            onSignOut: { Task { await model.signOut() } }
        )
    }

    private func attentionBanner(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle")
            Text(message)
                .font(.footnote)
            Spacer()
            Button("Retry") {
                Task { await model.refresh() }
            }
        }
        .padding()
        .background(.regularMaterial)
        .accessibilityElement(children: .combine)
    }
}
