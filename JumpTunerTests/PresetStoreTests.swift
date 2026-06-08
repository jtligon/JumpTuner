// PresetStoreTests.swift
// Tests for PresetStore: save, delete, and disk persistence.

import Testing
import Foundation
@testable import JumpTuner

@Suite("PresetStore", .serialized)
@MainActor
struct PresetStoreTests {

    private let fileURL: URL = FileManager.default
        .urls(for: .documentDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("jump_presets.json")

    private func deleteFile() {
        try? FileManager.default.removeItem(at: fileURL)
    }

    // MARK: - init

    @Test func freshStoreStartsEmpty() {
        deleteFile()
        defer { deleteFile() }
        let store = PresetStore()
        #expect(store.presets.isEmpty)
    }

    @Test func initLoadsFromDisk() {
        deleteFile()
        defer { deleteFile() }
        let store1 = PresetStore()
        store1.save(Preset(name: "Persisted", params: .defaults))

        let store2 = PresetStore()
        #expect(store2.presets.count == 1)
        #expect(store2.presets[0].name == "Persisted")
    }

    // MARK: - save

    @Test func saveAppendsNewPreset() {
        deleteFile()
        defer { deleteFile() }
        let store = PresetStore()
        store.save(Preset(name: "Alpha", params: .defaults))
        #expect(store.presets.count == 1)
        #expect(store.presets[0].name == "Alpha")
    }

    @Test func saveOverwritesExistingName() {
        deleteFile()
        defer { deleteFile() }
        let store = PresetStore()
        store.save(Preset(name: "Alpha", params: .defaults))

        var modified = JumpParams.defaults
        modified.jumpHeight = 200
        store.save(Preset(name: "Alpha", params: modified))

        #expect(store.presets.count == 1)
        #expect(store.presets[0].params.jumpHeight == 200)
    }

    // MARK: - delete(at:)

    @Test func deleteAtIndexSet() {
        deleteFile()
        defer { deleteFile() }
        let store = PresetStore()
        store.save(Preset(name: "A", params: .defaults))
        store.save(Preset(name: "B", params: .defaults))
        store.delete(at: IndexSet(integer: 0))
        #expect(store.presets.count == 1)
        #expect(store.presets[0].name == "B")
    }

    // MARK: - delete(id:)

    @Test func deleteByIDFound() {
        deleteFile()
        defer { deleteFile() }
        let store = PresetStore()
        let preset = Preset(name: "C", params: .defaults)
        store.save(preset)
        store.delete(id: preset.id)
        #expect(store.presets.isEmpty)
    }

    @Test func deleteByIDNotFoundIsNoop() {
        deleteFile()
        defer { deleteFile() }
        let store = PresetStore()
        store.save(Preset(name: "D", params: .defaults))
        store.delete(id: UUID())
        #expect(store.presets.count == 1)
    }
}
