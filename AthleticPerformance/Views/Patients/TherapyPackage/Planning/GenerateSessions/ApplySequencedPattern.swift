//
//  ApplySequencedPattern.swift
//  AthleticPerformance
//
//  Created by Frank Ufer on 11.06.25.
//

import Foundation

func applySequencedPattern(
    pattern: NextSessionPattern,
    baseDate: Date,
    drafts: [TreatmentSessions],
    base: TreatmentSessions,
    context: SessionPlanningContext,
    validator: TravelTimeValidator,
    targetCount: Int
) async -> (sessions: [TreatmentSessions], usedRelaxed: Bool) {

    let cal = Calendar.current
    let travelManager = TravelTimeManager.shared
    var results: [TreatmentSessions] = []
    var relaxedHit = false

    @inline(__always)
    func monBased(from apple: Int) -> Int { ((apple + 5) % 7) + 1 }

    let baseHm = cal.dateComponents([.hour, .minute], from: base.startTime)
    let fallbackTime = (hour: baseHm.hour ?? 9, minute: baseHm.minute ?? 0)

    var anchor = baseDate.onlyDate

    for i in 0..<targetCount {
        let appleWeekday  = pattern.weekdays[i % pattern.weekdays.count]
        let monWeekdayRaw = monBased(from: appleWeekday)
        guard let targetWeekday = Weekday(rawValue: monWeekdayRaw) else { continue }

        let rawComponents = pattern.startTimes[i % pattern.startTimes.count]
        let rawTime = (hour: rawComponents.hour, minute: rawComponents.minute)
        let prefTime = normalizeTime(rawTime, fallback: fallbackTime)

        let weekInterval = pattern.intervalWeeks[i % pattern.intervalWeeks.count]

        let advanced = cal.date(byAdding: .day, value: weekInterval * 7, to: anchor) ?? anchor

        var day = advanced
        while cal.component(.weekday, from: day) != appleWeekday {
            day = cal.date(byAdding: .day, value: 1, to: day) ?? day
        }
        day = day.onlyDate

        let existing = context.ownSessions + context.otherSessions

        // immer strict für Pattern:
        let (placed, _, usedRelaxedForThisOne) = await planOneSession(
            day: day,
            frequency: .multiplePerWeek,
            allowedWeekdays: [targetWeekday],
            title: base.title,
            preferredStartTime: prefTime,
            durationMinutes: context.sessionDuration,
            patientAddress: base.address,
            serviceIds: base.treatmentServiceIds,
            therapistAvailability: context.therapistAvailability,
            ownSessions: context.ownSessions,
            existing: existing,
            newlyPlanned: results,
            draftSessions: drafts,
            validator: validator,
            therapistId: base.therapistId,
            travelManager: travelManager,
            strategy: .strict
        )

        if let s = placed {
            results.append(s)
            anchor = s.startTime.onlyDate
        } else {
            anchor = day
        }

        if usedRelaxedForThisOne { relaxedHit = true }
    }

    return (results, relaxedHit)
}
