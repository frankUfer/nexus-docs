//
//  CheckTherapistAvailabilityHorizon.swift
//  AthleticPerformance
//
//  Created by Frank Ufer on 24.10.25.
//

import Foundation

func checkTherapistAvailabilityHorizon(
    startDate: Date,
    numberOfSessions: Int,
    availability: [AvailabilitySlot],
    calendar: Calendar = .current
) -> (missingFrom: Date, missingUntil: Date)? {

    // 1. Geschätztes Therapie-Ende berechnen
    let totalDurationDays = max(0, numberOfSessions * 14)

    guard let plannedEndDate = calendar.date(
        byAdding: .day,
        value: totalDurationDays,
        to: startDate.onlyDate
    ) else {
        return nil
    }

    // 2. Letztes Datum finden, an dem der Therapeut Availability gepflegt hat.
    //    Wir nehmen pro Slot das spätere der beiden Zeiten (start vs. end),
    //    und dann insgesamt das Maximum aller Slots.
    let latestAvailabilityDate: Date? = availability
        .map { slot in
            // spätestes Datum dieses Slots
            max(slot.start.onlyDate, slot.end.onlyDate)
        }
        .max()

    // 3. Wenn es gar keine Availability gibt:
    //    dann fehlt alles ab Start bis zum geplanten Ende.
    guard let latestAvailabilityDate else {
        return (
            missingFrom: startDate.onlyDate,
            missingUntil: plannedEndDate.onlyDate
        )
    }

    // 4. Check: deckt die letzte bekannte Availability unser geplantes Ende ab?
    if plannedEndDate.onlyDate <= latestAvailabilityDate.onlyDate {
        // alles gut, wir haben Availability bis mindestens zum geplanten Ende
        return nil
    }

    // 5. Nein → Lücke.
    //    Lücke beginnt am Tag NACH der letzten Availability.
    guard let firstMissingDay = calendar.date(
        byAdding: .day,
        value: 1,
        to: latestAvailabilityDate.onlyDate
    ) else {
        // falls das schiefgeht, sagen wir einfach ab latestAvailabilityDate fehlt's
        return (
            missingFrom: latestAvailabilityDate.onlyDate,
            missingUntil: plannedEndDate.onlyDate
        )
    }

    return (
        missingFrom: firstMissingDay.onlyDate,
        missingUntil: plannedEndDate.onlyDate
    )
}
