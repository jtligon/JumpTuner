// PresetStore.swift
//
// Persistence layer for saved jump presets.
//
// Storage strategy: Core Data via NSPersistentCloudKitContainer. When a
// CloudKit container identifier is configured, presets sync automatically
// across all of a user's devices signed into the same Apple ID. Without one,
// the same container works as a plain local SQLite store.
//
// The public API (presets, save, delete) is intentionally identical to the
// previous JSON-file implementation so the rest of the app compiles
// unchanged. On first launch after updating from the JSON version, any
// existing presets are migrated automatically and the JSON file is removed.
//
// Enabling iCloud sync (one-time, in Xcode — cannot be scripted):
//   • Target → Signing & Capabilities → + iCloud → check CloudKit
//   • Add a container, e.g. "iCloud.visceralorigami.JumpTuner"
//   • Set `PresetStore.defaultCloudKitContainerID` below to that identifier
// Until then sync stays off. Turning on CloudKit mirroring without the
// matching entitlement makes the app fail at launch.

import Combine
import CoreData
import Foundation
import SwiftUI

final class PresetStore: ObservableObject {

    /// CloudKit container used for sync. `nil` keeps presets local-only.
    static let defaultCloudKitContainerID: String? = nil

    /// The managed object model is loaded once and shared. Loading the model
    /// separately for every container makes Core Data register the
    /// `PresetEntity` class more than once ("Multiple NSEntityDescriptions
    /// claim the NSManagedObject subclass"), and then inserts fail.
    private static let model: NSManagedObjectModel = {
        guard let url = Bundle(for: PresetEntity.self).url(forResource: "JumpTuner", withExtension: "momd"),
              let model = NSManagedObjectModel(contentsOf: url) else {
            fatalError("PresetStore: JumpTuner.momd missing from bundle")
        }
        return model
    }()

    @Published var presets: [Preset] = []

    private let container: NSPersistentCloudKitContainer
    private let legacyJSONURL: URL

    /// - Parameters:
    ///   - storeURL: SQLite file location. `nil` uses Core Data's default
    ///     location in Application Support. Tests pass a temp file.
    ///   - cloudKitContainerID: CloudKit container to mirror to, or `nil`
    ///     for a local-only store.
    ///   - legacyJSONURL: Pre-Core Data JSON file to migrate from.
    init(
        storeURL: URL? = nil,
        cloudKitContainerID: String? = PresetStore.defaultCloudKitContainerID,
        legacyJSONURL: URL = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("jump_presets.json")
    ) {
        self.legacyJSONURL = legacyJSONURL
        container = NSPersistentCloudKitContainer(name: "JumpTuner", managedObjectModel: Self.model)

        if let description = container.persistentStoreDescriptions.first {
            if let storeURL { description.url = storeURL }
            description.cloudKitContainerOptions = cloudKitContainerID.map {
                NSPersistentCloudKitContainerOptions(containerIdentifier: $0)
            }
            description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            description.setOption(true as NSNumber,
                                  forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        }

        // Stores load synchronously (shouldAddStoreAsynchronously defaults to
        // false), so the completion handler runs here, on the calling thread.
        var loadError: Error?
        container.loadPersistentStores { _, error in
            if let error { loadError = error }
        }
        if let loadError {
            print("PresetStore CoreData load error: \(loadError)")
            return
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        migrateFromJSON()
        fetchPresets()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRemoteChange),
            name: .NSPersistentStoreRemoteChange,
            object: container.persistentStoreCoordinator
        )
    }

    // MARK: - Public API

    /// Saves a preset, overwriting any existing entry with the same name.
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
        writeContext(ctx)
    }

    func delete(id: UUID) {
        let ctx = container.viewContext
        deleteEntity(id: id, in: ctx)
        writeContext(ctx)
    }

    // MARK: - Private

    /// Re-reads presets synchronously so callers (and tests) see the result
    /// of a save/delete immediately.
    private func fetchPresets() {
        let request = PresetEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]
        let entities = (try? container.viewContext.fetch(request)) ?? []
        presets = entities.compactMap(Preset.init)
    }

    private func writeContext(_ ctx: NSManagedObjectContext) {
        guard ctx.hasChanges else { return }
        do {
            try ctx.save()
        } catch {
            print("PresetStore save error: \(error)")
            ctx.rollback()
        }
        fetchPresets()
    }

    private func deleteEntity(id: UUID, in ctx: NSManagedObjectContext) {
        let request = PresetEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        (try? ctx.fetch(request))?.forEach { ctx.delete($0) }
    }

    // MARK: - One-time JSON migration

    private func migrateFromJSON() {
        let url = legacyJSONURL
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

        do {
            if ctx.hasChanges { try ctx.save() }
            // Only remove the legacy file once its contents are safely stored.
            try? FileManager.default.removeItem(at: url)
        } catch {
            print("PresetStore JSON migration error: \(error)")
            ctx.rollback()
        }
    }

    /// Core Data posts remote-change notifications on a background queue.
    /// The class is main-actor isolated (project default), so this entry
    /// point must be nonisolated and hop to the main actor itself; otherwise
    /// the runtime isolation check traps.
    @objc nonisolated private func handleRemoteChange(_ notification: Notification) {
        Task { @MainActor [weak self] in
            self?.container.viewContext.refreshAllObjects()
            self?.fetchPresets()
        }
    }
}
