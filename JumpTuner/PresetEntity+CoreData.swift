// PresetEntity+CoreData.swift
// NSManagedObject subclass for the PresetEntity Core Data entity.

import CoreData
import Foundation

@objc(PresetEntity)
class PresetEntity: NSManagedObject {
    @NSManaged var id: UUID?
    @NSManaged var name: String?
    @NSManaged var paramsJSON: String?
    @NSManaged var createdAt: Date?
}

extension PresetEntity {
    static func fetchRequest() -> NSFetchRequest<PresetEntity> {
        NSFetchRequest<PresetEntity>(entityName: "PresetEntity")
    }
}

// MARK: - Conversion

extension Preset {
    init?(_ entity: PresetEntity) {
        guard let id = entity.id,
              let name = entity.name,
              let json = entity.paramsJSON,
              let params = try? JumpParams.decoded(from: json) else { return nil }
        self.init(id: id, name: name, params: params)
    }
}
