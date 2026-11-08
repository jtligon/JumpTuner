// WatchPresetStore.swift
//
// Receives the preset list from the iOS app via WatchConnectivity and
// exposes it to the Watch UI. Also sends activation requests back to iOS.

import Combine
import Foundation
import WatchConnectivity

struct WatchPreset: Identifiable, Codable {
    var id: UUID
    var name: String
}

@MainActor
final class WatchPresetStore: NSObject, ObservableObject {

    @Published private(set) var presets: [WatchPreset] = []
    @Published private(set) var isConnected = false
    @Published private(set) var lastActivatedID: UUID?
    @Published private(set) var activationError: String?

    override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    /// Tell the iOS app to apply this preset.
    func activate(_ preset: WatchPreset) {
        lastActivatedID = preset.id
        let message = ["activatePresetID": preset.id.uuidString]
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(message, replyHandler: nil) { [weak self] error in
                Task { @MainActor in
                    self?.activationError = error.localizedDescription
                }
            }
        } else {
            // Queue for delivery when iPhone becomes reachable.
            WCSession.default.transferUserInfo(message)
        }
    }

    private func applyPresets(from userInfo: [String: Any]) {
        guard let data = userInfo["presets"] as? Data,
              let decoded = try? JSONDecoder().decode([WatchPreset].self, from: data) else { return }
        presets = decoded
    }
}

// MARK: - WCSessionDelegate

extension WatchPresetStore: WCSessionDelegate {

    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        Task { @MainActor in
            isConnected = activationState == .activated
            if let context = session.receivedApplicationContext["presets"] as? Data,
               let decoded = try? JSONDecoder().decode([WatchPreset].self, from: context) {
                presets = decoded
            }
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            isConnected = session.isReachable
        }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveUserInfo userInfo: [String: Any]
    ) {
        Task { @MainActor in
            applyPresets(from: userInfo)
        }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveApplicationContext applicationContext: [String: Any]
    ) {
        Task { @MainActor in
            applyPresets(from: applicationContext)
        }
    }
}
