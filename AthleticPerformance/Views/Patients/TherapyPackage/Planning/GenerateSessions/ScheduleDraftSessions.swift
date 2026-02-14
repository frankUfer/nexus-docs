//
//  scheduleDraftSessions.swift
//  AthleticPerformance
//
//  Created by Frank Ufer on 22.10.25.
//

import Foundation

func scheduleDraftSessions(
    sessionTitle: String,
    draftSessions: [TreatmentSessions],
    startDate: Date,
    preferredStartTime: (hour: Int, minute: Int),
    frequency: TherapyFrequency,
    allowedWeekdays: [Weekday]?,
    serviceIds: [UUID],
    durationMinutes: Int,
    patientAddress: Address,
    therapistAvailability: [AvailabilitySlot],
    ownSessions: [TreatmentSessions],
    otherSessions: [TreatmentSessions],
    validator: TravelTimeValidator,
    therapistId: Int,
    targetCount: Int,
    calendar: Calendar = .current
) async -> (sessions: [TreatmentSessions], didRelax: Bool) {

    var results: [TreatmentSessions] = []
    var didRelax = false

    // alle existierenden Sessions (egal welcher Patient)
    let existing = ownSessions + otherSessions

    // wir starten am gewünschten Starttag (nur Datumsteil)
    var currentDay = startDate.onlyDate

    // NEU:
    // 1. Wir zählen wie viele aufeinanderfolgende Kalendertage
    //    wir NICHTS platzieren konnten.
    var daysWithoutPlacement = 0

    // 2. Wir merken uns, ob wir schon in den "relaxed mode"
    //    umgestiegen sind. Das ersetzt cutoffDay-Logik.
    var isRelaxed = false

    let travelManager = TravelTimeManager.shared

    while results.count < targetCount {

        // Wenn wir schon in relaxed sind, planen wir *direkt* relaxed.
        if isRelaxed {
            let relaxedAttempt = await planOneSession(
                day: currentDay,
                frequency: frequency,
                allowedWeekdays: allowedWeekdays,
                title: sessionTitle,
                preferredStartTime: preferredStartTime,
                durationMinutes: durationMinutes,
                patientAddress: patientAddress,
                serviceIds: serviceIds,
                therapistAvailability: therapistAvailability,
                ownSessions: ownSessions,
                existing: existing,
                newlyPlanned: results,
                draftSessions: draftSessions,
                validator: validator,
                therapistId: therapistId,
                calendar: calendar,
                travelManager: travelManager,
                strategy: .relaxed
            )

            if let placed = relaxedAttempt.placed {
                results.append(placed)
                // Erfolg → resette daysWithoutPlacement
                daysWithoutPlacement = 0
                // nächster Tag laut relaxedAttempt
                currentDay = relaxedAttempt.nextDate.onlyDate
                // wir sind längst relaxed
                didRelax = true
                continue
            } else {
                // kein Erfolg heute im relaxed mode
                daysWithoutPlacement += 1
                // gehe einfach +1 Tag weiter, weil Frequenz nach Relax egal
                currentDay = calendar.date(byAdding: .day, value: 1, to: currentDay)?.onlyDate ?? currentDay
                continue
            }
        }

        // WIR SIND NOCH NICHT RELAXED:
        // Erst strikter Versuch.
        let strictAttempt = await planOneSession(
            day: currentDay,
            frequency: frequency,
            allowedWeekdays: allowedWeekdays,
            title: sessionTitle,
            preferredStartTime: preferredStartTime,
            durationMinutes: durationMinutes,
            patientAddress: patientAddress,
            serviceIds: serviceIds,
            therapistAvailability: therapistAvailability,
            ownSessions: ownSessions,
            existing: existing,
            newlyPlanned: results,
            draftSessions: draftSessions,
            validator: validator,
            therapistId: therapistId,
            calendar: calendar,
            travelManager: travelManager,
            strategy: .strict
        )

        if let placedStrict = strictAttempt.placed {
            // Erfolg im STRICT Modus 🎉
            results.append(placedStrict)

            // Erfolg → resette daysWithoutPlacement
            daysWithoutPlacement = 0

            // Nächster Kandidatentag ergibt sich aus strictAttempt
            currentDay = strictAttempt.nextDate.onlyDate

            // Wir sind noch nicht relaxed.
            continue
        }

        // STRICT hat nichts gefunden für currentDay.
        // Kein sofortiger Fallback auf relaxed!
        // Stattdessen zählen wir, wie lange wir erfolglos sind.
        daysWithoutPlacement += 1

        // Falls wir nun über dem 21-Tage-Limit sind,
        // schalten wir in relaxed um (ab *nächster* Iteration).
        if daysWithoutPlacement > 21 {
            isRelaxed = true
            didRelax = true
        }

        // Jetzt wie weiterspringen?
        if isRelaxed {
            // Ab jetzt (weil wir gerade eben umgeschaltet haben)
            // behandeln wir das ähnlich wie dein "nach Cutoff -> nächsten Kalendertag"
            currentDay = calendar.date(byAdding: .day, value: 1, to: currentDay)?.onlyDate ?? currentDay
        } else {
            // Noch im strict-Modus: wir halten weiter die Frequenz ein.
            currentDay = nextCandidateDate(
                from: currentDay,
                placed: nil,
                frequency: frequency,
                calendar: calendar
            ).onlyDate
        }
    }

    return (results, didRelax)
}
