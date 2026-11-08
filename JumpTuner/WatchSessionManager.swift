// WatchSessionManager.swift
//
// Manages WatchConnectivity between the iOS app and the Apple Watch companion.
// Push the full preset list to the Watch whenever it changes; receive preset
// activation requests from the Watch and apply them to the active JumpParams.

import Combine
import Foundation
import WatchConnectivity

/// Posted when the Watch activates a preset. The notification's object is the
/// `Preset` to apply; observers (e.g. `ContentView`) update their params state.
extension Notification.Name {
    static let watchActivatedPreset = Notification.Name("watchActivatedPreset")
}

@MainActor
final class WatchSessionManager: NSObject, ObservableObject {

    static let shared = WatchSessionManager()

    @Published private(set) var isReachable = false
    @Published private(set) var lastActivatedPresetName: String?

    // The store is injected after init because the manager is created as a
    // singleton before PresetStore is available.
    weak var presetStore: PresetStore?

    private var cancellables = Set<AnyCancellable>()

    private override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    /// Start observing PresetStore changes and push any update to the Watch.
    func observeStore(_ store: PresetStore) {
        presetStore = store
        store.$presets
            .dropFirst()
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] presets in
                self?.sendPresets(presets)
            }
            .store(in: &cancellables)
    }

    /// Encode and push the full preset list using `transferUserInfo` (queued,
    /// battery-friendly — survives app backgrounding on both sides).
    func sendPresets(_ presets: [Preset]) {
        guard WCSession.default.activationState == .activated,
              WCSession.default.isPaired,
              WCSession.default.isWatchAppInstalled else { return }

        guard let encoded = try? JSONEncoder().encode(presets) else { return }
        WCSession.default.transferUserInfo(["presets": encoded])
    }
}

// MARK: - WCSessionDelegate

extension WatchSessionManager: WCSessionDelegate {

    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        Task { @MainActor in
            isReachable = (activationState == .activated) && session.isReachable
            // Push current presets now that activation is complete.
            if let store = presetStore {
                sendPresets(store.presets)
            }
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            isReachable = session.isReachable
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        // Required on iOS to support Watch switching.
        WCSession.default.activate()
    }

    /// Receive preset activation from the Watch (via `sendMessage`).
    nonisolated func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any]
    ) {
        guard let idString = message["activatePresetID"] as? String,
              let uuid = UUID(uuidString: idString) else { return }

        Task { @MainActor in
            guard let preset = presetStore?.presets.first(where: { $0.id == uuid }) else { return }
            lastActivatedPresetName = preset.name
            NotificationCenter.default.post(
                name: .watchActivatedPreset,
                object: preset
            )
        }
    }

    /// Receive preset activation from the Watch when iPhone is not immediately
    /// reachable (sent via `transferUserInfo`).
    nonisolated func session(
        _ session: WCSession,
        didReceiveUserInfo userInfo: [String: Any]
    ) {
        if let idString = userInfo["activatePresetID"] as? String {
            self.session(session, didReceiveMessage: ["activatePresetID": idString])
        }
    }
}
