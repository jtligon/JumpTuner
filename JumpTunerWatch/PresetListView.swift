// PresetListView.swift
//
// Main Watch screen: a scrollable list of saved presets. Tapping one sends
// an activation request to the paired iPhone.

import SwiftUI

struct PresetListView: View {
    @EnvironmentObject private var store: WatchPresetStore

    var body: some View {
        Group {
            if store.presets.isEmpty {
                emptyState
            } else {
                presetList
            }
        }
        .navigationTitle("JumpTuner")
    }

    private var presetList: some View {
        List(store.presets) { preset in
            Button {
                store.activate(preset)
            } label: {
                HStack {
                    Text(preset.name)
                        .font(.body)
                    Spacer()
                    if store.lastActivatedID == preset.id {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: store.isConnected ? "tray" : "iphone.slash")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text(store.isConnected ? "No saved presets" : "Connect to iPhone")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}
