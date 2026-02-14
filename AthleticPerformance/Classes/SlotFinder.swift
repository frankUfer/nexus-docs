//
//  SlotFinder.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 04.06.25.
//

import Foundation

final class SlotFinder {
    func findClusteredSlot(
        currentDate: Date,
        context: SessionPlanningContext,
        therapistId: Int,
        sessionsToday: [TreatmentSessions]
    ) async -> Date? {
        let sessionDurationSec = context.sessionDuration * 60
        let weekRange = Calendar.current.dateInterval(of: .weekOfYear, for: currentDate)
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none

        let candidates = context.ownSessions.filter {
            $0.treatmentServiceIds != context.plan.treatmentServiceIds &&
            $0.address.isSameLocation(as: context.updatedPatientAddress) &&
            (weekRange?.contains($0.startTime) ?? false)
        }

        for existing in candidates {
            let validator = SlotValidator(
                availability: context.therapistAvailability,
                sessionsOnSameDay: sessionsToday
            )

            let windowMinutes = 30
            var bestSlot: Date?
            var smallestOffset: TimeInterval = .infinity

            let midpoint = existing.startTime.addingTimeInterval(existing.duration / 2)

            for offsetMin in stride(from: -windowMinutes, through: windowMinutes, by: 5) {
                let candidate = midpoint.addingTimeInterval(Double(offsetMin * 60))
                let roundedCandidate = roundToFullMinute(candidate)
                let endTime = roundedCandidate.addingTimeInterval(TimeInterval(sessionDurationSec))

                let inPreferred = isInPreferredTime(roundedCandidate, context: context)
                let slotOK = validator.isSlotAvailable(start: roundedCandidate, end: endTime)

                if inPreferred && slotOK {
                    let offset = abs(candidate.timeIntervalSince(midpoint))
                    if offset < smallestOffset {
                        bestSlot = roundedCandidate
                        smallestOffset = offset
                    }
                }
            }

            if let result = bestSlot {
                return result
            }
        }

        return nil
    }

    private func roundToFullMinute(_ date: Date) -> Date {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        return cal.date(from: comps)!
    }

    private func isInPreferredTime(_ date: Date, context: SessionPlanningContext) -> Bool {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        let minutes = (components.hour ?? 0) * 60 + (components.minute ?? 0)
        return minutes >= context.preferredRange.startMinutes &&
               minutes <= context.preferredRange.endMinutes - context.sessionDuration
    }
}
