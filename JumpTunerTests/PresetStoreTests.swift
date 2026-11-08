// PresetStoreTests.swift
// Tests for PresetStore: save, delete, persistence, and legacy JSON migration.

import Testing
import Foundation
@testable import JumpTuner

@Suite("PresetStore", .serialized)
@MainActor
struct PresetStoreTests {

    /// Each test instance gets its own scratch directory, so tests never
    /// share a SQLite store or a legacy JSON file.
    private let dir: URL
    private var storeURL: URL { dir.appendingPathComponent("Presets.sqlite") }
    private var jsonURL: URL { dir.appendingPathComponent("jump_presets.json") }

    init() throws {
        dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("PresetStoreTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    /// Local-only store (no CloudKit) at this test's scratch location.
    private func makeStore() -> PresetStore {
        PresetStore(storeURL: storeURL, cloudKitContainerID: nil, legacyJSONURL: jsonURL)
    }

    // MARK: - init

    @Test func freshStoreStartsEmpty() {
        let store = makeStore()
        #expect(store.presets.isEmpty)
    }

    @Test func initLoadsFromDisk() {
        let store1 = makeStore()
        store1.save(Preset(name: "Persisted", params: .defaults))

        let store2 = makeStore()
        #expect(store2.presets.count == 1)
        #expect(store2.presets.first?.name == "Persisted")
    }

    // MARK: - save

    @Test func saveAppendsNewPreset() {
        let store = makeStore()
        store.save(Preset(name: "Alpha", params: .defaults))
        #expect(store.presets.count == 1)
        #expect(store.presets.first?.name == "Alpha")
    }

    @Test func saveOverwritesExistingName() {
        let store = makeStore()
        store.save(Preset(name: "Alpha", params: .defaults))

        var modified = JumpParams.defaults
        modified.jumpHeight = 200
        store.save(Preset(name: "Alpha", params: modified))

        #expect(store.presets.count == 1)
        #expect(store.presets.first?.params.jumpHeight == 200)
    }

    // MARK: - delete(at:)

    @Test func deleteAtIndexSet() {
        let store = makeStore()
        store.save(Preset(name: "A", params: .defaults))
        store.save(Preset(name: "B", params: .defaults))
        store.delete(at: IndexSet(integer: 0))
        #expect(store.presets.count == 1)
        #expect(store.presets.first?.name == "B")
    }

    // MARK: - delete(id:)

    @Test func deleteByIDFound() {
        let store = makeStore()
        let preset = Preset(name: "C", params: .defaults)
        store.save(preset)
        store.delete(id: preset.id)
        #expect(store.presets.isEmpty)
    }

    @Test func deleteByIDNotFoundIsNoop() {
        let store = makeStore()
        store.save(Preset(name: "D", params: .defaults))
        store.delete(id: UUID())
        #expect(store.presets.count == 1)
    }

    // MARK: - JSON migration

    @Test func migratesLegacyJSONAndRemovesFile() throws {
        let legacy = [Preset(name: "Old", params: .defaults)]
        try JSONEncoder().encode(legacy).write(to: jsonURL)

        let store = makeStore()
        #expect(store.presets.map(\.name) == ["Old"])
        #expect(store.presets.first?.id == legacy[0].id)
        #expect(!FileManager.default.fileExists(atPath: jsonURL.path))
    }
}
