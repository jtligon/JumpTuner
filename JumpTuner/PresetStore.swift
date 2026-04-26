// PresetStore.swift
//
// Persistence layer for saved jump presets.
//
// Storage strategy: a single JSON file in the app's Documents directory.
// This is the right choice for a flat list of small structs — no schema
// migration, easy to inspect/debug, survives app updates cleanly.
//
// Core Data would be appropriate if we later needed relational queries,
// CloudKit sync, or large datasets. For now this is deliberate overkill
// avoidance.

import Foundation
import SwiftUI   // needed for remove(atOffsets:), which is a SwiftUI Array extension
import Combine   // needed for @Published

/// Observable store that owns the canonical list of saved presets.
///
/// Inject as a `@StateObject` at the root and pass down as
/// `@ObservedObject` to child views that need read/write access.
///
/// All mutations go through `save(_:)` and `delete(...)` which
/// automatically persist to disk after each change.
final class PresetStore: ObservableObject {

    /// The live list of presets. Mutating this triggers SwiftUI re-renders.
    @Published var presets: [Preset]

    private let fileURL: URL

    init() {
        let url = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("jump_presets.json")
        self.fileURL = url
        // Load from disk on init. If the file doesn't exist yet (first launch)
        // or can't be decoded, start with an empty list.
        if let data = try? Data(contentsOf: url),
           let saved = try? JSONDecoder().decode([Preset].self, from: data) {
            self.presets = saved
        } else {
            self.presets = []
        }
    }

    /// Saves a preset, overwriting any existing entry with the same name.
    /// - Parameter preset: The preset to save or update.
    func save(_ preset: Preset) {
        if let idx = presets.firstIndex(where: { $0.name == preset.name }) {
            presets[idx] = preset  // update in place
        } else {
            presets.append(preset)
        }
        persist()
    }

    /// Deletes presets at the given index set. Used by SwiftUI's `.onDelete`.
    func delete(at offsets: IndexSet) {
        presets.remove(atOffsets: offsets)
        persist()
    }

    /// Deletes a preset by its stable UUID. Used by the trash button in rows.
    func delete(id: UUID) {
        if let idx = presets.firstIndex(where: { $0.id == id }) {
            presets.remove(at: idx)
            persist()
        }
    }

    // MARK: - Private

    /// Writes the current preset list to disk atomically.
    /// Atomic write means a crash mid-save won't corrupt the existing file —
    /// the OS swaps in the new file only after it's fully written.
    private func persist() {
        do {
            let data = try JSONEncoder().encode(presets)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("PresetStore save error: \(error)")
        }
    }
}
