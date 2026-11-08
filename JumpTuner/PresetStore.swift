// PresetStore.swift
//
// Persistence layer for saved jump presets.
//
// Storage strategy: NSPersistentCloudKitContainer — Core Data backed by
// CloudKit so presets sync automatically across all of a user's devices
// signed into the same Apple ID.
//
// The public API (presets, save, delete) is intentionally identical to the
// previous JSON-file implementation so the rest of the app compiles
// unchanged. On first launch after updating from the JSON version, any
// existing presets are migrated automatically and the JSON file is removed.
//
// Setup required in Xcode (one-time, cannot be scripted):
//   • Target → Signing & Capabilities → + iCloud → check CloudKit
//   • Add a container named "iCloud.com.yourname.JumpTuner"
//   • Replace the container identifier string below with that name

import Combine
import CoreData
import Foundation
import SwiftUI

private let cloudKitContainerID = "iCloud.com.yourname.JumpTuner"

final class PresetStore: ObservableObject {

    @Published var presets: [Preset] = []

    private let container: NSPersistentCloudKitContainer

    init() {
        container = NSPersistentCloudKitContainer(name: "JumpTuner")

        if let description = container.persistentStoreDescriptions.first {
            let options = NSPersistentCloudKitContainerOptions(containerIdentifier: cloudKitContainerID)
            description.cloudKitContainerOptions = options
            description.setOption(
                true as NSNumber,
                forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey
            )
        }

        container.loadPersistentStores { [weak self] _, error in
            if let error {
                print("PresetStore CoreData load error: \(error)")
                return
            }
            guard let self else { return }
            container.viewContext.automaticallyMergesChangesFromParent = true
            container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
            migrateFromJSON()
            fetchPresets()
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRemoteChange),
            name: .NSPersistentStoreRemoteChange,
            object: container.persistentStoreCoordinator
        )
    }

    // MARK: - Public API

    func save(_ preset: Preset) {
        let ctx = container.viewContext
        let request = PresetEntity.fetchRequest()
        request.predicate = NSPredicate(format: "name == %@", preset.name)
        let entity = (try? ctx.fetch(request))?.first ?? PresetEntity(context: ctx)

        entity.id         = preset.id
        entity.name       = preset.name
        entity.paramsJSON = (try? preset.params.encoded()) ?? ""
        if entity.createdAt == nil { entity.createdAt = Date() }

        writeContext(ctx)
    }

    func delete(at offsets: IndexSet) {
        let ctx = container.viewContext
        offsets.forEach { idx in
            deleteEntity(id: presets[idx].id, in: ctx)
        }
        presets.remove(atOffsets: offsets)
        writeContext(ctx)
    }

    func delete(id: UUID) {
        let ctx = container.viewContext
        deleteEntity(id: id, in: ctx)
        if let idx = presets.firstIndex(where: { $0.id == id }) {
            presets.remove(at: idx)
        }
        writeContext(ctx)
    }

    // MARK: - Private

    private func fetchPresets() {
        let request = PresetEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]
        let entities = (try? container.viewContext.fetch(request)) ?? []
        DispatchQueue.main.async { [weak self] in
            self?.presets = entities.compactMap(Preset.init)
        }
    }

    private func writeContext(_ ctx: NSManagedObjectContext) {
        guard ctx.hasChanges else { return }
        do {
            try ctx.save()
            fetchPresets()
        } catch {
            print("PresetStore save error: \(error)")
        }
    }

    private func deleteEntity(id: UUID, in ctx: NSManagedObjectContext) {
        let request = PresetEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        (try? ctx.fetch(request))?.forEach { ctx.delete($0) }
    }

    // MARK: - One-time JSON migration

    private func migrateFromJSON() {
        let url = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("jump_presets.json")

        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let legacy = try? JSONDecoder().decode([Preset].self, from: data) else { return }

        let ctx = container.viewContext
        for preset in legacy {
            let request = PresetEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", preset.id as CVarArg)
            guard (try? ctx.fetch(request))?.isEmpty != false else { continue }
            let entity = PresetEntity(context: ctx)
            entity.id         = preset.id
            entity.name       = preset.name
            entity.paramsJSON = (try? preset.params.encoded()) ?? ""
            entity.createdAt  = Date()
        }

        if ctx.hasChanges {
            try? ctx.save()
        }
        try? FileManager.default.removeItem(at: url)
    }

    @objc private func handleRemoteChange(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            self?.container.viewContext.refreshAllObjects()
            self?.fetchPresets()
        }
    }
}
