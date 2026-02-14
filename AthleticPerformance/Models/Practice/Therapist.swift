//
//  Therapist.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 12.04.25.
//

import Foundation

/// Represents a therapist with scheduling and therapy plan information.
struct Therapist: Codable, Equatable, Hashable, Identifiable {
    /// Unique identifier for the therapist (matches `Therapists.id`).
    var id: Int

    /// UUID linking to a calendar layer for scheduling.
    var calendarLayerId: UUID

    /// List of availability time slots for the therapist.
    var availability: [AvailabilityEntry] = []

    /// List of therapy plans associated with the therapist.
    var therapyPlans: [TherapyPlan] = []

    /// Checks if the therapist is available on a specific date.
    /// - Parameter date: The date to check for availability.
    /// - Returns: `true` if the therapist has an availability entry covering the date.
    func availableOn(_ date: Date) -> Bool {
        availability.contains {
            $0.type == .available &&
            $0.startDate <= date &&
            $0.endDate >= date
        }
    }
}

