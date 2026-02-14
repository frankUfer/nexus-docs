//
//  CalendarLayer.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 12.04.25.
//

import SwiftUI

/// Represents a calendar layer or category, used to organize and display calendar entries.
struct CalendarLayer: Identifiable, Codable, Hashable {
    /// Unique identifier for the calendar layer.
    var id: UUID

    /// Name of the calendar layer (e.g., "Therapists", "Rooms").
    var name: String

    /// Color for visual representation, as a hex string (e.g., "#FF5733").
    var colorHex: String

    /// Indicates whether this calendar layer is currently visible.
    var isVisible: Bool

    /// Optional identifier for a person associated with this layer (e.g., a therapist or resource).
    var associatedPersonId: UUID?
}

