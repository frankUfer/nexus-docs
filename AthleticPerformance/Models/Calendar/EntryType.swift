//
//  EntryType.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 12.04.25.
//

import Foundation
import SwiftUI

/// Represents the type of a calendar entry, such as availability, vacation, therapy, or holiday.
enum EntryType: String, Codable, CaseIterable, Identifiable {
    /// Therapist or resource is available.
    case availability

    /// Vacation period.
    case vacation

    /// Therapy session or appointment.
    case therapy

    /// Suggested or proposed entry.
    case suggestion

    /// Public holiday.
    case holiday

    /// Training or continuing education.
    case training

    /// Blocked time (not available for scheduling).
    case blocked

    /// Unique identifier for the entry type (required for Identifiable protocol).
    var id: String { rawValue }

    /// Localized display name for the entry type.
    var displayName: String {
        switch self {
        case .availability: return NSLocalizedString("Verfügbarkeit", comment: "")
        case .vacation: return NSLocalizedString("Urlaub", comment: "")
        case .therapy: return NSLocalizedString("Therapie", comment: "")
        case .suggestion: return NSLocalizedString("Vorschlag", comment: "")
        case .holiday: return NSLocalizedString("Feiertag", comment: "")
        case .training: return NSLocalizedString("Schulung", comment: "")
        case .blocked: return NSLocalizedString("Geblockt", comment: "")
        }
    }

    /// Color associated with the entry type (for UI representation).
    var color: Color {
        switch self {
        case .availability: return .green.opacity(0.3)
        case .vacation: return .blue.opacity(0.4)
        case .therapy: return .orange.opacity(0.5)
        case .suggestion: return .purple.opacity(0.5)
        case .holiday: return .red.opacity(0.4)
        case .training: return .yellow.opacity(0.4)
        case .blocked: return .gray.opacity(0.3)
        }
    }

    /// System icon name associated with the entry type (for UI representation).
    var systemIcon: String {
        switch self {
        case .availability: return "checkmark.circle"
        case .vacation: return "beach.umbrella"
        case .therapy: return "cross.case"
        case .suggestion: return "calendar.badge.plus"
        case .holiday: return "gift"
        case .training: return "book"
        case .blocked: return "nosign"
        }
    }
}

