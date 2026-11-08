// JumpTunerApp.swift

import SwiftUI

@main
struct JumpTunerApp: App {
    @StateObject private var presetStore = PresetStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(presetStore)
                .onAppear {
                    // Wire the shared session manager to the live store so preset
                    // changes are pushed to the Watch automatically.
                    WatchSessionManager.shared.observeStore(presetStore)
                }
        }
    }
}
