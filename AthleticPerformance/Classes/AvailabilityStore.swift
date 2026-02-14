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
    
    func setTherapist(id: Int) {
            therapistId = "\(id)"
            load()
        }
}
