//
//  CalendarEntry.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 12.04.25.
//

import Foundation

/// Represents a single entry or event in a calendar, such as an appointment or meeting.
struct CalendarEntry: Identifiable, Codable, Hashable {
    /// Unique identifier for the calendar entry.
    var id: UUID

    /// Title or description of the entry (e.g., appointment subject).
    var title: String

    /// Start date and time of the entry.
    var start: Date

    /// End date and time of the entry.
    var end: Date

    /// Optional identifier for the person associated with this entry (e.g., patient or therapist).
    var personId: UUID?

    /// The type of calendar entry (e.g., appointment, meeting, etc.).
    var type: EntryType

    /// Optional location where the entry takes place.
    var location: String?

    /// Optional identifier for the calendar layer or category this entry belongs to.
    var layerId: UUID?

    /// Indicates whether this entry is a suggested (proposed) event.
    var isSuggested: Bool
}

