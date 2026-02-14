//
//  AvailabilitySlot.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 16.04.25.
//

import Foundation

struct AvailabilitySlotFile: Codable {
    var version: Int
    var items: [AvailabilitySlot]
}

/// Represents a time slot indicating when a resource or person is available.
struct AvailabilitySlot: Codable, Identifiable, Hashable {
    /// Unique identifier for the availability slot.
    var id: UUID

    /// Start date and time of the availability period.
    var start: Date

    /// End date and time of the availability period.
    var end: Date

    /// Initializes a new `AvailabilitySlot` with the given start and end times.
    /// - Parameters:
    ///   - id: Unique identifier for the slot (default is a new UUID).
    ///   - start: Start date and time.
    ///   - end: End date and time.
    init(id: UUID = UUID(), start: Date, end: Date) {
        self.id = id
        self.start = start
        self.end = end
    }
}

extension AvailabilitySlot {
    func contains(start: Date, end: Date) -> Bool {
        return self.start <= start && self.end >= end
    }
}

extension [AvailabilitySlot] {
    func exists(on day: Date) -> Bool {
        self.contains { Calendar.current.isDate($0.start, inSameDayAs: day) }
    }
}
