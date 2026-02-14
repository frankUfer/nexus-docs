//
//  PlanOneSession.swift
//  AthleticPerformance
//
//  Created by Frank Ufer on 23.10.25.
//

import Foundation

@inline(__always)
func normalizeTime(_ t: (hour: Int?, minute: Int?),
                   fallback: (hour: Int, minute: Int)) -> (hour: Int, minute: Int) {
    (t.hour ?? fallback.hour, t.minute ?? fallback.minute)
}

// MARK: - Weekday/Calendar Helpers

/// Weekday (Mo=1…So=7) -> Apple weekday (So=1…Sa=7)
@inline(__always)
func appleWeekday(from weekday: Weekday) -> Int {
    return weekday.rawValue
}

/// Ist der Tag für multiplePerWeek erlaubt?
@inline(__always)
func isAllowedWeekday(_ date: Date, frequency: TherapyFrequency, allowed: [Weekday]?, calendar: Calendar) -> Bool {
    guard case .multiplePerWeek = frequency, let allowed, !allowed.isEmpty else { return true }
    let todayApple = calendar.component(.weekday, from: date)          // So=1…Sa=7
    let allowedApple = Set(allowed.map(appleWeekday))
    return allowedApple.contains(todayApple)
}

/// Rhythmus in Tagen (für .daily/.weekly/.biweekly; .multiplePerWeek = tageweise)
@inline(__always)
func rhythmDays(for f: TherapyFrequency) -> Int {
    switch f {
    case .daily:            return 1
    case .weekly:           return 7
    case .biweekly:         return 14
    case .multiplePerWeek:  return 1
    }
}

/// Nächster Kandidaten-Tag
@inline(__always)
func nextCandidateDate(from current: Date, placed: TreatmentSessions?, frequency: TherapyFrequency, calendar: Calendar) -> Date {
    if case .multiplePerWeek = frequency {
        return calendar.date(byAdding: .day, value: 1, to: current) ?? current
    }
    let step = rhythmDays(for: frequency)
    let anchor = placed?.startTime.onlyDate ?? current
    return calendar.date(byAdding: .day, value: step, to: anchor) ?? anchor
}

// MARK: - Tageskontext

@inline(__always)
func sameDaySessions(on day: Date,
                     existing: [TreatmentSessions],
                     newlyPlanned: [TreatmentSessions],
                     calendar: Calendar) -> [TreatmentSessions] {
    let all = existing + newlyPlanned
    return all.filter { calendar.isDate($0.startTime, inSameDayAs: day) }
}

// MARK: - Planungsstrategie

enum PlanningStrategy {
    case strict   // Wunschzeit + Frequenz einhalten
    case relaxed  // Frühestmöglich / beste Lücken
}

// MARK: - Orchestrator für EINEN Tag

func planOneSession(
    day: Date,
    frequency: TherapyFrequency,
    allowedWeekdays: [Weekday]?,
    title: String,
    preferredStartTime: (hour: Int, minute: Int),
    durationMinutes: Int,
    patientAddress: Address,
    serviceIds: [UUID],
    therapistAvailability: [AvailabilitySlot],
    ownSessions: [TreatmentSessions],
    existing: [TreatmentSessions],
    newlyPlanned: [TreatmentSessions],
    draftSessions: [TreatmentSessions],
    validator: TravelTimeValidator,
    therapistId: UUID,
    calendar: Calendar = .current,
    travelManager: TravelTimeManager,
    strategy: PlanningStrategy
) async -> (placed: TreatmentSessions?, nextDate: Date, usedRelaxed: Bool) {

    // strict respektiert allowedWeekdays; relaxed ignoriert das
    if strategy == .strict {
        guard isAllowedWeekday(day, frequency: frequency, allowed: allowedWeekdays, calendar: calendar) else {
            let next = calendar.date(byAdding: .day, value: 1, to: day) ?? day
            return (nil, next, false)
        }
    }

    // Kontext heute
    let sameDay = sameDaySessions(
        on: day,
        existing: existing,
        newlyPlanned: newlyPlanned,
        calendar: calendar
    )

    // 1. Wochen-Merge
    if let wk = await tryMergeInWeek(
        targetWeekOf: day,
        durationMinutes: durationMinutes,
        patientAddress: patientAddress,
        serviceIds: serviceIds,
        ownSessions: ownSessions,
        existing: existing,
        newlyPlanned: newlyPlanned,
        newlyPlannedCount: newlyPlanned.count,
        draftSessions: draftSessions,
        title: title,
        therapistAvailability: therapistAvailability,
        validator: validator,
        therapistId: therapistId,
        calendar: calendar,
        travelManager: travelManager
    ) {
        let next = nextCandidateDate(from: day, placed: wk, frequency: frequency, calendar: calendar)
        // Wochen-Merge ist nie "entspannt" per se – ist sogar optimal
        return (wk, next, false)
    }

    // 2. Tages-Merge
    if let merged = await tryMergeOnDay(
        day: day,
        durationMinutes: durationMinutes,
        patientAddress: patientAddress,
        serviceIds: serviceIds,
        sameDay: sameDay,
        newlyPlannedCount: newlyPlanned.count,
        draftSessions: draftSessions,
        title: title,
        therapistAvailability: therapistAvailability,
        validator: validator,
        therapistId: therapistId,
        calendar: calendar,
        travelManager: travelManager
    ) {
        let next = nextCandidateDate(from: day, placed: merged, frequency: frequency, calendar: calendar)
        return (merged, next, false)
    }

    // Ab hier unterscheidet sich strict vs relaxed

    if strategy == .strict {
        // 3. Exakte Wunschzeit
        if let exact = await tryExactPreferredOnDay(
            day: day,
            preferredStartTime: preferredStartTime,
            durationMinutes: durationMinutes,
            patientAddress: patientAddress,
            serviceIds: serviceIds,
            sameDay: sameDay,
            newlyPlannedCount: newlyPlanned.count,
            draftSessions: draftSessions,
            title: title,
            therapistAvailability: therapistAvailability,
            validator: validator,
            therapistId: therapistId,
            calendar: calendar,
            travelManager: travelManager
        ) {
            let next = nextCandidateDate(from: day, placed: exact, frequency: frequency, calendar: calendar)
            return (exact, next, false)
        }

        // 4. Radiale Suche um preferredStartTime herum
        if let radial = await findSlotRadialOnDay(
            day: day,
            preferredStartTime: preferredStartTime,
            durationMinutes: durationMinutes,
            patientAddress: patientAddress,
            serviceIds: serviceIds,
            sameDay: sameDay,
            newlyPlannedCount: newlyPlanned.count,
            draftSessions: draftSessions,
            title: title,
            therapistAvailability: therapistAvailability,
            validator: validator,
            therapistId: therapistId,
            calendar: calendar,
            travelManager: travelManager
        ) {
            let next = nextCandidateDate(from: day, placed: radial, frequency: frequency, calendar: calendar)
            return (radial, next, false)
        }

        // nichts gefunden im strict mode
        let nextStrict = nextCandidateDate(from: day, placed: nil, frequency: frequency, calendar: calendar)
        return (nil, nextStrict, false)
    } else {
        // RELAXED MODE

        // Relaxed ignoriert Wunschzeit komplett.
        // Wir versuchen irgendein freies Fenster an diesem Tag (frühestes möglich),
        // mit gleicher Availability-/Fahrtzeit-Logik.
        if let anyFeasible = await findAnyFeasibleOnDay(
            day: day,
            durationMinutes: durationMinutes,
            patientAddress: patientAddress,
            serviceIds: serviceIds,
            sameDay: sameDay,
            newlyPlannedCount: newlyPlanned.count,
            draftSessions: draftSessions,
            title: title,
            therapistAvailability: therapistAvailability,
            validator: validator,
            therapistId: therapistId,
            calendar: calendar,
            travelManager: travelManager
        ) {
            // Nach relaxed Fund: nächster Tag einfach day+1,
            // Frequenz ist jetzt egal (das Tag+1 machst du in scheduleDraftSessions eh noch mal final,
            // aber wir geben hier trotzdem etwas Sinnvolles zurück)
            let nextLoose = calendar.date(byAdding: .day, value: 1, to: day) ?? day
            return (anyFeasible, nextLoose, true)
        }

        // gar nichts am Tag → geh einfach zum nächsten Kalendertag
        let nextLooseNoHit = calendar.date(byAdding: .day, value: 1, to: day) ?? day
        return (nil, nextLooseNoHit, false)
    }
}
// MARK: - Draft-Bau

func makeDraftContainer(
    fillingIndex index: Int,
    draftSessions: [TreatmentSessions],
    start: Date,
    end: Date,
    title: String,
    patientAddress: Address,
    serviceIds: [UUID],
    therapistId: UUID
) -> TreatmentSessions {
    if draftSessions.indices.contains(index) {
        var d = draftSessions[index]
        d.startTime = start
        d.endTime   = end
        d.date      = start.onlyDate
        d.address   = patientAddress
        d.treatmentServiceIds = serviceIds
        d.therapistId = therapistId
        d.title     = d.title.isEmpty ? title : d.title
        d.draft     = true
        d.isPlanned = false
        d.isScheduled = false
        d.isDone    = false
        d.isInvoiced = false
        d.isPaid    = false
        return d
    } else {
        return TreatmentSessions(
            id: UUID(),
            patientId: nil,
            date: start.onlyDate,
            startTime: start,
            endTime: end,
            address: patientAddress,
            title: title,
            draft: true,
            isPlanned: false,
            isScheduled: false,
            isDone: false,
            isInvoiced: false,
            isPaid: false,
            treatmentServiceIds: serviceIds,
            therapistId: therapistId,
            reevaluationEntryIds: [],
            notes: nil,
            icsUid: nil,
            localCalendarEventId: nil,
            icsSequence: nil,
            serialNumber: nil
        )
    }
}

// MARK: - Merge-Versuche (Woche oder Tag)

func tryMergeInWeek(
    targetWeekOf day: Date,
    durationMinutes: Int,
    patientAddress: Address,
    serviceIds: [UUID],
    ownSessions: [TreatmentSessions],
    existing: [TreatmentSessions],
    newlyPlanned: [TreatmentSessions],
    newlyPlannedCount: Int,
    draftSessions: [TreatmentSessions],
    title: String,
    therapistAvailability: [AvailabilitySlot],
    validator: TravelTimeValidator,
    therapistId: UUID,
    calendar: Calendar,
    travelManager: TravelTimeManager
) async -> TreatmentSessions? {

    // Kalenderwoche bestimmen
    guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: day) else {
        return nil
    }

    // Eigene Sitzungen (dieser Patient) in dieser Woche
    let ownThisWeek = ownSessions
        .filter { weekInterval.contains($0.startTime) }
        .sorted { $0.startTime < $1.startTime }

    guard !ownThisWeek.isEmpty else {
        return nil
    }

    // Versuche für jede eigene Sitzung in der Woche zu mergen
    for base in ownThisWeek {

        let thatDay = base.startTime.onlyDate

        // Alle Sessions (alle Patienten, inkl. schon geplanten) an diesem Tag
        let sameDayAll = (existing + newlyPlanned)
            .filter { calendar.isDate($0.startTime, inSameDayAs: thatDay) }
            .sorted { $0.startTime < $1.startTime }

        // Wie viele Termine an dieser Adresse an diesem Tag gibt es schon?
        let sameLocCountToday = sameDayAll.filter { $0.address == patientAddress }.count
        if sameLocCountToday >= 2 {
            // Schon 2 an dieser Location → hier an diesem Tag nichts mehr legen
            continue
        }

        // Hilfsfunktion: prüft einen konkreten Slot-Kandidaten (start/end)
        func tryPlace(
            candidateStart: Date,
            candidateEnd: Date
        ) async -> TreatmentSessions? {

            // 1. Überschneidet der Slot bestehende Sessions?
            //    (sicherheitshalber, obwohl wir direkt an base hängen)
            let collides = sameDayAll.contains {
                candidateStart < $0.endTime && candidateEnd > $0.startTime
            }
            if collides {
                return nil
            }

            // 2. Finde vorherige existierende Session vor candidateStart
            let prior = sameDayAll
                .filter { $0.endTime <= candidateStart }
                .sorted { $0.endTime > $1.endTime }
                .first

            // 3. Finde nächste existierende Session nach candidateEnd
            let next = sameDayAll
                .filter { $0.startTime >= candidateEnd }
                .sorted { $0.startTime < $1.startTime }
                .first

            // 4. Anfahrt vor candidateStart
            let originAddrRaw = prior?.address ?? AppGlobals.shared.practiceInfo.startAddress
            let origin = await GeocodingService.shared.geocodeIfNeeded(originAddrRaw)

            let travelInSec = await travelManager.calculateConfirmedTravelTime(
                from: origin,
                to: patientAddress,
                validator: validator
            ) ?? 0

            let blockStart = candidateStart.addingTimeInterval(-travelInSec)

            // 5. Rückweg nach candidateEnd
            let destAfterRaw = next?.address ?? AppGlobals.shared.practiceInfo.startAddress

            let travelOutSec = await travelManager.calculateConfirmedTravelTime(
                from: patientAddress,
                to: destAfterRaw,
                validator: validator
            ) ?? 0

            let blockEnd = candidateEnd.addingTimeInterval(travelOutSec)

            // 6. Anschluss prüfen:
            //    - wir dürfen next nicht reißen
            if let next, blockEnd > next.startTime {
                return nil
            }
            //    - wir dürfen prior nicht unmöglich machen (d.h. blockStart darf nicht vor prior.startBlock liegen)
            //      Praktisch: wir müssen nur sicherstellen, dass wir prior zeitlich nicht "nach hinten" verschieben,
            //      aber prior steht ja fest. Wichtig ist eigentlich: gibt es negative Fahrzeit?
            //      travelInSec ist schon validiert durch calculateConfirmedTravelTime(), also ok.

            // 7. Tag-Limit erneut prüfen: Wenn wir diesen Slot hinzufügen,
            //    wären es dann >2 an dieser Adresse an diesem Tag?
            let wouldBeCount = sameLocCountToday + 1
            if wouldBeCount > 2 {
                return nil
            }

            // 8. Availability über den GESAMTEN Block (Anfahrt → Behandlung → Rückweg)
            let slotValidator = SlotValidator(
                availability: therapistAvailability,
                sessionsOnSameDay: sameDayAll
            )

            guard slotValidator.isSlotAvailable(start: blockStart, end: blockEnd) else {
                return nil
            }

            // 9. Draft bauen und zurück
            return makeDraftContainer(
                fillingIndex: newlyPlannedCount,
                draftSessions: draftSessions,
                start: candidateStart,
                end: candidateEnd,
                title: title,
                patientAddress: patientAddress,
                serviceIds: serviceIds,
                therapistId: therapistId
            )
        }

        // Variante A: hinten dranhängen (Start = base.endTime)
        if let afterDraft = await tryPlace(
            candidateStart: base.endTime,
            candidateEnd: base.endTime.addingTimeInterval(TimeInterval(durationMinutes * 60))
        ) {
            return afterDraft
        }

        // Variante B: davor einfügen (Ende = base.startTime)
        if let beforeDraft = await tryPlace(
            candidateStart: base.startTime.addingTimeInterval(-TimeInterval(durationMinutes * 60)),
            candidateEnd: base.startTime
        ) {
            return beforeDraft
        }
    }

    return nil
}

func tryMergeOnDay(
    day: Date,
    durationMinutes: Int,
    patientAddress: Address,
    serviceIds: [UUID],
    sameDay: [TreatmentSessions],
    newlyPlannedCount: Int,
    draftSessions: [TreatmentSessions],
    title: String,
    therapistAvailability: [AvailabilitySlot],
    validator: TravelTimeValidator,
    therapistId: UUID,
    calendar: Calendar,
    travelManager: TravelTimeManager
) async -> TreatmentSessions? {

    let daySessionsSorted = sameDay
        .filter { calendar.isDate($0.startTime, inSameDayAs: day) }
        .sorted { $0.startTime < $1.startTime }

    // any session mit gleicher Adresse
    let sameLocationToday = daySessionsSorted.filter { $0.address == patientAddress }
    guard !sameLocationToday.isEmpty else { return nil }

    // Limit: max 2 am Tag an dieser Adresse
    let sameLocationSameDayCount = sameLocationToday.count
    if sameLocationSameDayCount >= 2 { return nil }

    // kleine Hilfsfunktion wie in tryMergeInWeek
    func tryPlace(candidateStart: Date, candidateEnd: Date) async -> TreatmentSessions? {

        // 1. Kollisionscheck
        let collides = daySessionsSorted.contains {
            candidateStart < $0.endTime && candidateEnd > $0.startTime
        }
        if collides { return nil }

        // 2. vorherige Session relativ zu candidateStart
        let prior = daySessionsSorted
            .filter { $0.endTime <= candidateStart }
            .sorted { $0.endTime > $1.endTime }
            .first

        // 3. nächste Session relativ zu candidateEnd
        let next = daySessionsSorted
            .filter { $0.startTime >= candidateEnd }
            .sorted { $0.startTime < $1.startTime }
            .first

        // 4. Hinfahrt
        let originAddrRaw = prior?.address ?? AppGlobals.shared.practiceInfo.startAddress
        let origin = await GeocodingService.shared.geocodeIfNeeded(originAddrRaw)

        let travelInSec = await travelManager.calculateConfirmedTravelTime(
            from: origin,
            to: patientAddress,
            validator: validator
        ) ?? 0

        let blockStart = candidateStart.addingTimeInterval(-travelInSec)

        // 5. Rückfahrt
        let destAfterRaw = next?.address ?? AppGlobals.shared.practiceInfo.startAddress

        let travelOutSec = await travelManager.calculateConfirmedTravelTime(
            from: patientAddress,
            to: destAfterRaw,
            validator: validator
        ) ?? 0

        let blockEnd = candidateEnd.addingTimeInterval(travelOutSec)

        // 6. Anschluss prüfen
        if let next, blockEnd > next.startTime { return nil }

        // 7. Tag-Limit (würde dann count+1 werden)
        if sameLocationSameDayCount + 1 > 2 { return nil }

        // 8. Availability über [blockStart, blockEnd]
        let slotValidator = SlotValidator(
            availability: therapistAvailability,
            sessionsOnSameDay: sameDay
        )
        guard slotValidator.isSlotAvailable(start: blockStart, end: blockEnd) else {
            return nil
        }

        // 9. Draft bauen
        return makeDraftContainer(
            fillingIndex: newlyPlannedCount,
            draftSessions: draftSessions,
            start: candidateStart,
            end: candidateEnd,
            title: title,
            patientAddress: patientAddress,
            serviceIds: serviceIds,
            therapistId: therapistId
        )
    }

    // Versuche für jede Session mit gleicher Adresse:
    for base in sameLocationToday {
        // A) hinten dranhängen
        if let afterDraft = await tryPlace(
            candidateStart: base.endTime,
            candidateEnd: base.endTime.addingTimeInterval(TimeInterval(durationMinutes * 60))
        ) {
            return afterDraft
        }

        // B) davor einfügen
        if let beforeDraft = await tryPlace(
            candidateStart: base.startTime.addingTimeInterval(-TimeInterval(durationMinutes * 60)),
            candidateEnd: base.startTime
        ) {
            return beforeDraft
        }
    }

    return nil
}

// MARK: - Radiale Slot-Suche (+5, −5, …)

func findSlotRadialOnDay(
    day: Date,
    preferredStartTime: (hour: Int, minute: Int),
    durationMinutes: Int,
    patientAddress: Address,
    serviceIds: [UUID],
    sameDay: [TreatmentSessions],
    newlyPlannedCount: Int,
    draftSessions: [TreatmentSessions],
    title: String,
    therapistAvailability: [AvailabilitySlot],
    validator: TravelTimeValidator,
    therapistId: UUID,
    calendar: Calendar,
    travelManager: TravelTimeManager
) async -> TreatmentSessions? {

    func overlaps(_ aStart: Date, _ aEnd: Date, _ bStart: Date, _ bEnd: Date) -> Bool {
        aStart < bEnd && aEnd > bStart
    }

    func makeStartEnd(for day: Date, hour: Int, minute: Int) -> (Date, Date)? {
        var comps = calendar.dateComponents([.year, .month, .day], from: day.onlyDate)
        comps.hour = hour
        comps.minute = minute
        guard let start = calendar.date(from: comps) else { return nil }
        let end = start.addingTimeInterval(TimeInterval(durationMinutes * 60))
        return (start, end)
    }

    let preferredMinute = preferredStartTime.hour * 60 + preferredStartTime.minute
    let lastStartMinute = 24 * 60 - durationMinutes
    let step = 5
    let maxDelta = max(preferredMinute, lastStartMinute - preferredMinute)

    var searchMinutes: [Int] = []
    for delta in stride(from: 0, through: maxDelta, by: step) {
        let plus = preferredMinute + delta
        if plus <= lastStartMinute { searchMinutes.append(plus) }
        if delta > 0 {
            let minus = preferredMinute - delta
            if minus >= 0 { searchMinutes.append(minus) }
        }
    }

    for minuteOfDay in searchMinutes {
        let h = minuteOfDay / 60
        let m = minuteOfDay % 60
        guard let (candidateStart, candidateEnd) = makeStartEnd(for: day, hour: h, minute: m) else { continue }

        if sameDay.contains(where: { overlaps(candidateStart, candidateEnd, $0.startTime, $0.endTime) }) {
            continue
        }

        let prior = sameDay
            .filter { $0.endTime <= candidateStart }
            .sorted { $0.endTime > $1.endTime }
            .first

        let next = sameDay
            .filter { $0.startTime >= candidateEnd }
            .sorted { $0.startTime < $1.startTime }
            .first

        let slotValidator = SlotValidator(
            availability: therapistAvailability,
            sessionsOnSameDay: sameDay
        )

        if prior == nil && next == nil {
            if !slotValidator.isSlotAvailable(start: candidateStart, end: candidateEnd) {
                continue
            }

            return makeDraftContainer(
                fillingIndex: newlyPlannedCount,
                draftSessions: draftSessions,
                start: candidateStart,
                end: candidateEnd,
                title: title,
                patientAddress: patientAddress,
                serviceIds: serviceIds,
                therapistId: therapistId
            )
        }

        let originAddrRaw = prior?.address ?? AppGlobals.shared.practiceInfo.startAddress
        let origin = await GeocodingService.shared.geocodeIfNeeded(originAddrRaw)

        guard let travelInSec = await travelManager.calculateConfirmedTravelTime(
            from: origin,
            to: patientAddress,
            validator: validator
        ) else {
            continue
        }

        if let prior {
            let arrivalAtPatient = prior.endTime.addingTimeInterval(travelInSec)
            if arrivalAtPatient > candidateStart {
                continue
            }
        }

        let destAfterRaw = next?.address ?? AppGlobals.shared.practiceInfo.startAddress
        let destAfter = await GeocodingService.shared.geocodeIfNeeded(destAfterRaw)

        guard let travelOutSec = await travelManager.calculateConfirmedTravelTime(
            from: patientAddress,
            to: destAfter,
            validator: validator
        ) else {
            continue
        }

        if let prior, let next {
            let sessionDurationSec = candidateEnd.timeIntervalSince(candidateStart)
            let totalRequired = travelInSec + sessionDurationSec + travelOutSec
            let totalGap = next.startTime.timeIntervalSince(prior.endTime)
            if totalRequired > totalGap {
                continue
            }
        }

        let blockStart = candidateStart.addingTimeInterval(-travelInSec)
        let blockEnd   = candidateEnd.addingTimeInterval(travelOutSec)

        if let next, blockEnd > next.startTime {
            continue
        }

        if !slotValidator.isSlotAvailable(start: blockStart, end: blockEnd) {
            continue
        }

        return makeDraftContainer(
            fillingIndex: newlyPlannedCount,
            draftSessions: draftSessions,
            start: candidateStart,
            end: candidateEnd,
            title: title,
            patientAddress: patientAddress,
            serviceIds: serviceIds,
            therapistId: therapistId
        )
    }

    return nil
}

func tryExactPreferredOnDay(
    day: Date,
    preferredStartTime: (hour: Int, minute: Int),
    durationMinutes: Int,
    patientAddress: Address,
    serviceIds: [UUID],
    sameDay: [TreatmentSessions],
    newlyPlannedCount: Int,
    draftSessions: [TreatmentSessions],
    title: String,
    therapistAvailability: [AvailabilitySlot],
    validator: TravelTimeValidator,
    therapistId: UUID,
    calendar: Calendar,
    travelManager: TravelTimeManager
) async -> TreatmentSessions? {

    var comps = calendar.dateComponents([.year, .month, .day], from: day.onlyDate)
    comps.hour = preferredStartTime.hour
    comps.minute = preferredStartTime.minute
    guard let start = calendar.date(from: comps) else { return nil }
    let end = start.addingTimeInterval(TimeInterval(durationMinutes * 60))

    if sameDay.contains(where: { start < $0.endTime && end > $0.startTime }) {
        return nil
    }

    let prior = sameDay
        .filter { $0.endTime <= start }
        .sorted { $0.endTime > $1.endTime }
        .first

    let next = sameDay
        .filter { $0.startTime >= end }
        .sorted { $0.startTime < $1.startTime }
        .first

    let originAddrRaw = prior?.address ?? AppGlobals.shared.practiceInfo.startAddress
    let origin = await GeocodingService.shared.geocodeIfNeeded(originAddrRaw)

    let travelInSec = await travelManager.calculateConfirmedTravelTime(
        from: origin,
        to: patientAddress,
        validator: validator
    ) ?? 0

    if let prior {
        let arrivalAtPatient = prior.endTime.addingTimeInterval(travelInSec)
        if arrivalAtPatient > start { return nil }
    }

    let destAfterRaw = next?.address ?? AppGlobals.shared.practiceInfo.startAddress
    let destAfter = await GeocodingService.shared.geocodeIfNeeded(destAfterRaw)

    guard let travelOutSec = await travelManager.calculateConfirmedTravelTime(
        from: patientAddress,
        to: destAfter,
        validator: validator
    ) else {
        return nil
    }

    if let prior, let next {
        let sessionDurationSec = end.timeIntervalSince(start)
        let totalRequired = travelInSec + sessionDurationSec + travelOutSec
        let totalGap = next.startTime.timeIntervalSince(prior.endTime)
        if totalRequired > totalGap { return nil }
    }

    let blockStart = start.addingTimeInterval(-travelInSec)
    let blockEnd   = end.addingTimeInterval(travelOutSec)

    if let next, blockEnd > next.startTime { return nil }

    let slotValidator = SlotValidator(
        availability: therapistAvailability,
        sessionsOnSameDay: sameDay
    )

    guard slotValidator.isSlotAvailable(start: blockStart, end: blockEnd) else { return nil }

    return makeDraftContainer(
        fillingIndex: newlyPlannedCount,
        draftSessions: draftSessions,
        start: start,
        end: end,
        title: title,
        patientAddress: patientAddress,
        serviceIds: serviceIds,
        therapistId: therapistId
    )
}

func findAnyFeasibleOnDay(
    day: Date,
    durationMinutes: Int,
    patientAddress: Address,
    serviceIds: [UUID],
    sameDay: [TreatmentSessions],
    newlyPlannedCount: Int,
    draftSessions: [TreatmentSessions],
    title: String,
    therapistAvailability: [AvailabilitySlot],
    validator: TravelTimeValidator,
    therapistId: UUID,
    calendar: Calendar,
    travelManager: TravelTimeManager
) async -> TreatmentSessions? {

    func overlaps(_ aStart: Date, _ aEnd: Date, _ bStart: Date, _ bEnd: Date) -> Bool {
        aStart < bEnd && aEnd > bStart
    }

    func makeStartEnd(for day: Date, minuteOfDay: Int) -> (Date, Date)? {
        var comps = calendar.dateComponents([.year, .month, .day], from: day.onlyDate)
        comps.hour = minuteOfDay / 60
        comps.minute = minuteOfDay % 60
        guard let start = calendar.date(from: comps) else { return nil }
        let end = start.addingTimeInterval(TimeInterval(durationMinutes * 60))
        return (start, end)
    }

    let lastStartMinute = 24 * 60 - durationMinutes

    for minuteOfDay in stride(from: 0, through: lastStartMinute, by: 5) {
        guard let (candidateStart, candidateEnd) = makeStartEnd(for: day, minuteOfDay: minuteOfDay) else { continue }

        if sameDay.contains(where: { overlaps(candidateStart, candidateEnd, $0.startTime, $0.endTime) }) {
            continue
        }

        let prior = sameDay
            .filter { $0.endTime <= candidateStart }
            .sorted { $0.endTime > $1.endTime }
            .first

        let next = sameDay
            .filter { $0.startTime >= candidateEnd }
            .sorted { $0.startTime < $1.startTime }
            .first

        let slotValidator = SlotValidator(
            availability: therapistAvailability,
            sessionsOnSameDay: sameDay
        )

        if prior == nil && next == nil {
            if !slotValidator.isSlotAvailable(start: candidateStart, end: candidateEnd) {
                continue
            }

            return makeDraftContainer(
                fillingIndex: newlyPlannedCount,
                draftSessions: draftSessions,
                start: candidateStart,
                end: candidateEnd,
                title: title,
                patientAddress: patientAddress,
                serviceIds: serviceIds,
                therapistId: therapistId
            )
        }

        let originAddrRaw = prior?.address ?? AppGlobals.shared.practiceInfo.startAddress
        let origin = await GeocodingService.shared.geocodeIfNeeded(originAddrRaw)

        guard let travelInSec = await travelManager.calculateConfirmedTravelTime(
            from: origin,
            to: patientAddress,
            validator: validator
        ) else {
            continue
        }

        if let prior {
            let arrivalAtPatient = prior.endTime.addingTimeInterval(travelInSec)
            if arrivalAtPatient > candidateStart {
                continue
            }
        }

        let destAfterRaw = next?.address ?? AppGlobals.shared.practiceInfo.startAddress
        let destAfter = await GeocodingService.shared.geocodeIfNeeded(destAfterRaw)

        guard let travelOutSec = await travelManager.calculateConfirmedTravelTime(
            from: patientAddress,
            to: destAfter,
            validator: validator
        ) else {
            continue
        }

        if let prior, let next {
            let sessionDurationSec = candidateEnd.timeIntervalSince(candidateStart)
            let totalRequired = travelInSec + sessionDurationSec + travelOutSec
            let totalGap = next.startTime.timeIntervalSince(prior.endTime)
            if totalRequired > totalGap {
                continue
            }
        }

        let blockStart = candidateStart.addingTimeInterval(-travelInSec)
        let blockEnd   = candidateEnd.addingTimeInterval(travelOutSec)

        if let next, blockEnd > next.startTime {
            continue
        }

        if !slotValidator.isSlotAvailable(start: blockStart, end: blockEnd) {
            continue
        }

        return makeDraftContainer(
            fillingIndex: newlyPlannedCount,
            draftSessions: draftSessions,
            start: candidateStart,
            end: candidateEnd,
            title: title,
            patientAddress: patientAddress,
            serviceIds: serviceIds,
            therapistId: therapistId
        )
    }

    return nil
}
