import Foundation
import LibreGlucoseCore
import SwiftUI
import WidgetKit

@MainActor
final class AppModel: ObservableObject {
    struct DashboardState: Equatable {
        let reading: ReadingPresentation
        let profileName: String
        let isCached: Bool
    }

    enum Phase: Equatable {
        case signedOut
        case loading
        case connected(DashboardState)
        case needsAttention(message: String, lastReading: DashboardState?)
    }

    @Published private(set) var phase: Phase

    private let coordinator: ReadingCoordinator?
    private let credentialStore: (any CredentialStoreProtocol)?
    private let setupMessage: String?

    static func live() -> AppModel {
        do {
            let credentialStore = try SharedContainer.makeCredentialStore()
            let readingCache = try SharedContainer.makeReadingCache()
            let coordinator = ReadingCoordinator(
                dataSource: LibreLinkUpDataSource(),
                credentialStore: credentialStore,
                readingCache: readingCache
            )
            return AppModel(coordinator: coordinator, credentialStore: credentialStore)
        } catch {
            return AppModel(
                coordinator: nil,
                credentialStore: nil,
                setupMessage: "Secure shared storage is unavailable. Check the App Group and Keychain signing capabilities."
            )
        }
    }

    init(
        coordinator: ReadingCoordinator?,
        credentialStore: (any CredentialStoreProtocol)?,
        setupMessage: String? = nil
    ) {
        self.coordinator = coordinator
        self.credentialStore = credentialStore
        self.setupMessage = setupMessage
        if let setupMessage {
            self.phase = .needsAttention(message: setupMessage, lastReading: nil)
        } else {
            self.phase = .loading
        }
    }

    func signIn(email: String, password: String) async {
        guard let coordinator, let credentialStore else {
            showSetupFailure()
            return
        }

        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedEmail.isEmpty, !password.isEmpty else {
            phase = .needsAttention(message: "Enter your LibreLinkUp email and password.", lastReading: nil)
            return
        }

        phase = .loading
        guard await coordinator.signOut() == .signedOut else {
            phase = .needsAttention(message: "Secure storage could not be reset.", lastReading: nil)
            return
        }

        do {
            try await credentialStore.saveCredentials(
                Credentials(email: normalizedEmail, password: password)
            )
        } catch {
            phase = .needsAttention(message: "Your sign-in details could not be saved securely.", lastReading: nil)
            return
        }

        await refresh()
    }

    func refresh() async {
        guard let coordinator else {
            showSetupFailure()
            return
        }

        let previous = currentDashboard
        phase = .loading
        switch await coordinator.refresh() {
        case let .updated(reading):
            phase = .connected(await dashboard(for: reading, isCached: false))
            WidgetCenter.shared.reloadTimelines(ofKind: SharedContainer.widgetKind)
        case let .cached(reading):
            phase = .connected(await dashboard(for: reading, isCached: true))
        case .signedOut:
            phase = .signedOut
        case let .failed(failure):
            phase = .needsAttention(
                message: failure.userMessage,
                lastReading: previous
            )
        }
    }

    func signOut() async {
        guard let coordinator else {
            showSetupFailure()
            return
        }

        phase = .loading
        if await coordinator.signOut() == .signedOut {
            phase = .signedOut
            WidgetCenter.shared.reloadTimelines(ofKind: SharedContainer.widgetKind)
        } else {
            phase = .needsAttention(message: "The account could not be removed from secure storage.", lastReading: nil)
        }
    }

    private var currentDashboard: DashboardState? {
        switch phase {
        case let .connected(state): state
        case let .needsAttention(_, state): state
        default: nil
        }
    }

    private func dashboard(for reading: GlucoseReading, isCached: Bool) async -> DashboardState {
        let profileName: String
        do {
            profileName = try await credentialStore?.connection()?.displayName ?? "Shared profile"
        } catch {
            profileName = "Shared profile"
        }
        return DashboardState(
            reading: ReadingPresentation.make(reading: reading),
            profileName: profileName,
            isCached: isCached
        )
    }

    private func showSetupFailure() {
        phase = .needsAttention(
            message: setupMessage ?? "Secure shared storage is unavailable.",
            lastReading: nil
        )
    }
}
