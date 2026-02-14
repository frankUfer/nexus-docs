//
//  AvailabilityStore.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 16.04.25.
//

import Foundation

class AvailabilityStore: ObservableObject {
    @Published var slots: [AvailabilitySlot] = []
    
    private var therapistId: String
    private let baseURL: URL
    
    init(therapistId: String, baseDirectory: URL) {
        self.therapistId = therapistId
        self.baseURL = baseDirectory
        load()
    }
    
    private var fileURL: URL {
        baseURL.appendingPathComponent("availability_\(therapistId).json")
    }

    func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            self.slots = []
            return
        }
        do {
            let data = try Data(contentsOf: fileURL)
            let file = try JSONDecoder().decode(AvailabilitySlotFile.self, from: data)
            self.slots = file.items
        } catch {
            let message = String(format: NSLocalizedString("errorLoadingAvailability", comment: "Error loading availability: %@"), error.localizedDescription)
            showErrorAlert(errorMessage: message)
            self.slots = []
        }
    }

    func save() {
        do {
            let file = AvailabilitySlotFile(version: 1, items: slots)
            let data = try JSONEncoder().encode(file)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            let message = String(format: NSLocalizedString("errorSavingAvailability", comment: "Error saving availability: %@"), error.localizedDescription)
            showErrorAlert(errorMessage: message)
        }
    }

    func addOrUpdate(_ newSlot: AvailabilitySlot) {
        if let index = slots.firstIndex(where: { $0.id == newSlot.id }) {
            slots[index] = newSlot
        } else {
            slots.append(newSlot)
        }
    }

    func delete(_ slot: AvailabilitySlot) {
        slots.removeAll { $0.id == slot.id }
    }

    func deleteInRange(from start: Date, to end: Date) {
        slots.removeAll { $0.start >= start && $0.end <= end }
    }
    
    func setTherapist(id: UUID) {
        therapistId = id.uuidString
        // Migration: if UUID-based file doesn't exist but legacy Int-based file does, rename it
        migrateFromIntBasedFile(uuid: id)
        load()
    }

    private func migrateFromIntBasedFile(uuid: UUID) {
        let fm = FileManager.default
        let uuidFile = baseURL.appendingPathComponent("availability_\(uuid.uuidString).json")
        guard !fm.fileExists(atPath: uuidFile.path) else { return }

        // Check for legacy Int-based files (e.g., availability_1.json)
        do {
            let files = try fm.contentsOfDirectory(at: baseURL, includingPropertiesForKeys: nil)
            for file in files where file.lastPathComponent.hasPrefix("availability_") && file.pathExtension == "json" {
                let name = file.deletingPathExtension().lastPathComponent
                let suffix = name.replacingOccurrences(of: "availability_", with: "")
                // If suffix is a number (legacy Int ID), try mapping it
                if let intId = Int(suffix), therapistUUIDFromInt(intId) == uuid {
                    try fm.moveItem(at: file, to: uuidFile)
                    return
                }
            }
        } catch {
            // Migration is best-effort; don't block app startup
        }
    }
}
