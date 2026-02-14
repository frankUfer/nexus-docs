//
//  SessionPlanning.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 04.06.25.
//

// MARK: - SessionPlanningContext

import Foundation

struct SessionPlanningContext {
    let plan: TherapyPlan
    let sessionDuration: Int
    let updatedPatientAddress: Address
    let updatedPracticeAddress: Address
    let therapistAvailability: [AvailabilitySlot]
    let ownSessions: [TreatmentSessions]
    let otherSessions: [TreatmentSessions]
    let preferredRange: TimeRange
    let frequencyDays: Int
    let planningStartDate: Date

    static func create(
        plan: TherapyPlan,
        services: [TreatmentService],
        patientAddress: Address,
        therapistAvailability: [AvailabilitySlot],
        ownSessions: [TreatmentSessions],
        otherSessions: [TreatmentSessions]
    ) async -> SessionPlanningContext? {
        guard let planStart = plan.startDate,
              let frequencyDays = plan.frequency?.intervalInDays,
              let preferredTime = plan.preferredTimeOfDay else {
            return nil
        }

        let sessionDuration = plan.treatmentServiceIds.compactMap { id in
            services.first(where: { $0.internalId == id })
        }.filter { $0.unit == "Min" }
         .compactMap { $0.quantity }
         .reduce(0, +)

        let updatedPatientAddress = await GeocodingService.shared.geocodeIfNeeded(patientAddress)
        let updatedPracticeAddress = await GeocodingService.shared.geocodeIfNeeded(AppGlobals.shared.practiceInfo.startAddress)

        // Bestimme erstes verfügbares Datum anhand der Verfügbarkeiten
        let earliestAvailableDate = therapistAvailability.map { Calendar.current.startOfDay(for: $0.start) }.min() ?? planStart
        let planningStartDate = max(earliestAvailableDate, planStart)

        return SessionPlanningContext(
            plan: plan,
            sessionDuration: sessionDuration,
            updatedPatientAddress: updatedPatientAddress,
            updatedPracticeAddress: updatedPracticeAddress,
            therapistAvailability: therapistAvailability,
            ownSessions: ownSessions,
            otherSessions: otherSessions,
            preferredRange: preferredTime.timeRange,
            frequencyDays: frequencyDays,
            planningStartDate: planningStartDate
        )
    }
}

// MARK: - SlotValidator

struct SlotValidator {
    let availability: [AvailabilitySlot]
    let sessionsOnSameDay: [TreatmentSessions]

    func isSlotAvailable(start: Date, end: Date) -> Bool {
        isWithinAvailability(start: start, end: end) && !hasOverlap(start: start, end: end)
    }

    private func isWithinAvailability(start: Date, end: Date) -> Bool {
        availability.contains { $0.start <= start && $0.end >= end }
    }

    private func hasOverlap(start: Date, end: Date) -> Bool {
        sessionsOnSameDay.contains {
            let existingEnd = $0.startTime.addingTimeInterval($0.duration)
            return existingEnd > start && $0.startTime < end
        }
    }
}

// MARK: - Session patterns
struct SessionPattern {
    var title: String
    var address: Address
    var serviceIds: [UUID]
    var therapistId: UUID
    var duration: TimeInterval
    var preferredStartTime: DateComponents
    var startDate: Date
    var rhythmDays: Int
    var weekday: Int?
}

struct NextSessionPattern {
    let weekdays: [Int]
    let startTimes: [DateComponents]
    let intervalWeeks: [Int]
}

// MARK: - SessionBuilder

func buildSession(on startTime: Date, context: SessionPlanningContext, therapistId: UUID) -> TreatmentSessions {
    return TreatmentSessions(
        id: UUID(),
        date: Calendar.current.startOfDay(for: startTime),
        startTime: startTime,
        endTime: startTime.addingTimeInterval(TimeInterval(context.sessionDuration * 60)),
        address: context.updatedPatientAddress,
        title: context.plan.title ?? NSLocalizedString("session", comment: "Session"),
        draft: true,
        isPlanned: false,
        isScheduled: false,
        isDone: false,
        isInvoiced: false,
        treatmentServiceIds: context.plan.treatmentServiceIds,
        therapistId: therapistId,
        reevaluationEntryIds: [],
        notes: nil
    )
}

