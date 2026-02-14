import Foundation

/// Compares old and new Patient states and returns only entities that actually changed.
/// Uses EntityExtractor to flatten both states, then compares entity-by-entity via JSON equality.
enum ChangeDetector {

    @MainActor
    static func detectChanges(
        old: Patient?,
        new: Patient,
        versionTracker: EntityVersionTracker
    ) -> [QueuedChange] {
        let newEntities = EntityExtractor.extractAll(from: new)

        let oldEntitiesMap: [UUID: EntityExtractor.ExtractedEntity]
        if let old = old {
            let oldEntities = EntityExtractor.extractAll(from: old)
            oldEntitiesMap = Dictionary(uniqueKeysWithValues: oldEntities.map { ($0.entityId, $0) })
        } else {
            oldEntitiesMap = [:]
        }

        var changes: [QueuedChange] = []

        for entity in newEntities {
            let operation = versionTracker.operation(for: entity.entityId)

            if let oldEntity = oldEntitiesMap[entity.entityId] {
                // Entity existed before — check if data changed
                if !dataEqual(oldEntity.data, entity.data) {
                    changes.append(QueuedChange(
                        entityType: entity.entityType,
                        entityId: entity.entityId,
                        patientId: entity.patientId,
                        dataCategory: entity.dataCategory,
                        data: entity.data,
                        operation: operation
                    ))
                }
            } else {
                // New entity
                changes.append(QueuedChange(
                    entityType: entity.entityType,
                    entityId: entity.entityId,
                    patientId: entity.patientId,
                    dataCategory: entity.dataCategory,
                    data: entity.data,
                    operation: "create"
                ))
            }
        }

        // Never queue delete operations (per sync protocol)
        return changes
    }

    /// Detects changes in availability slots (not patient-scoped).
    @MainActor
    static func detectAvailabilityChanges(
        old: [AvailabilitySlot]?,
        new: [AvailabilitySlot],
        therapistId: UUID,
        versionTracker: EntityVersionTracker
    ) -> [QueuedChange] {
        let newEntities = EntityExtractor.extractAvailability(slots: new, therapistId: therapistId)

        let oldEntitiesMap: [UUID: EntityExtractor.ExtractedEntity]
        if let old = old {
            let oldEntities = EntityExtractor.extractAvailability(slots: old, therapistId: therapistId)
            oldEntitiesMap = Dictionary(uniqueKeysWithValues: oldEntities.map { ($0.entityId, $0) })
        } else {
            oldEntitiesMap = [:]
        }

        var changes: [QueuedChange] = []

        for entity in newEntities {
            let operation = versionTracker.operation(for: entity.entityId)

            if let oldEntity = oldEntitiesMap[entity.entityId] {
                if !dataEqual(oldEntity.data, entity.data) {
                    changes.append(QueuedChange(
                        entityType: entity.entityType,
                        entityId: entity.entityId,
                        patientId: nil,
                        dataCategory: entity.dataCategory,
                        data: entity.data,
                        operation: operation
                    ))
                }
            } else {
                changes.append(QueuedChange(
                    entityType: entity.entityType,
                    entityId: entity.entityId,
                    patientId: nil,
                    dataCategory: entity.dataCategory,
                    data: entity.data,
                    operation: "create"
                ))
            }
        }

        return changes
    }

    private static func dataEqual(_ a: [String: AnyCodable], _ b: [String: AnyCodable]) -> Bool {
        guard let dataA = try? JSONSerialization.data(withJSONObject: a.mapValues(\.value), options: .sortedKeys),
              let dataB = try? JSONSerialization.data(withJSONObject: b.mapValues(\.value), options: .sortedKeys)
        else { return false }
        return dataA == dataB
    }
}
