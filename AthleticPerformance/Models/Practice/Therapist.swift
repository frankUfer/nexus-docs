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
    var id: UUID

    /// UUID linking to a calendar layer for scheduling.
    var calendarLayerId: UUID

    /// List of availability time slots for the therapist.
    var availability: [AvailabilityEntry] = []

    /// List of therapy plans associated with the therapist.
    var therapyPlans: [TherapyPlan] = []

    enum CodingKeys: String, CodingKey {
        case id, calendarLayerId, availability, therapyPlans
    }

    init(id: UUID = UUID(), calendarLayerId: UUID, availability: [AvailabilityEntry] = [], therapyPlans: [TherapyPlan] = []) {
        self.id = id
        self.calendarLayerId = calendarLayerId
        self.availability = availability
        self.therapyPlans = therapyPlans
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try decodeTherapistId(from: container, forKey: .id)
        calendarLayerId = try container.decode(UUID.self, forKey: .calendarLayerId)
        availability = try container.decodeIfPresent([AvailabilityEntry].self, forKey: .availability) ?? []
        therapyPlans = try container.decodeIfPresent([TherapyPlan].self, forKey: .therapyPlans) ?? []
    }

    /// Checks if the therapist is available on a specific date.
    func availableOn(_ date: Date) -> Bool {
        availability.contains {
            $0.type == .available &&
            $0.startDate <= date &&
            $0.endDate >= date
        }
    }
}

