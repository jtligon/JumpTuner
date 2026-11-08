// JumpTunerWatchApp.swift
//
// Entry point for the JumpTuner Apple Watch companion app.

import SwiftUI

@main
struct JumpTunerWatchApp: App {
    @StateObject private var store = WatchPresetStore()

    var body: some Scene {
        WindowGroup {
            PresetListView()
                .environmentObject(store)
        }
    }
}
