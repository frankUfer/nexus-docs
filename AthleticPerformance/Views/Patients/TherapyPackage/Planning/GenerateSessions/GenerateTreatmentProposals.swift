//
//  generateTreatmentProposals.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 27.05.25.
//

import Foundation

func generateTreatmentProposals(
    plan: TherapyPlan,
    services: [TreatmentService],
    patientAddress: Address,
    therapistId: Int,
    therapistAvailability: [AvailabilitySlot],
    ownSessions: [TreatmentSessions],
    otherSessions: [TreatmentSessions],
    validator: TravelTimeValidator,
    totalCount: Int = 10,
    patientId: UUID
) async -> (sessions: [TreatmentSessions], usedRelaxed: Bool) {

    // Kontext bauen (liefert u.a. Dauer, bereinigte Adressen, etc.)
    guard let context = await SessionPlanningContext.create(
        plan: plan,
        services: services,
        patientAddress: patientAddress,
        therapistAvailability: therapistAvailability,
        ownSessions: ownSessions,
        otherSessions: otherSessions
    ) else {
        return ([], false)
    }

    // Gruppen und Zählung
    let draftSessions     = plan.treatmentSessions.filter { $0.draft }.sorted { $0.startTime < $1.startTime }
    let plannedSessions   = plan.treatmentSessions.filter { $0.isPlanned }.sorted { $0.startTime < $1.startTime }
    let fixedSessions     = plan.treatmentSessions.filter { !$0.draft }.sorted { $0.startTime < $1.startTime }

    let remainingCount = max(totalCount - fixedSessions.count, 0)
    guard remainingCount > 0 || !draftSessions.isEmpty else {
        return ([], false)
    }
    
    // FALL A: Es gibt schon mindestens 2 geplante Sitzungen → wir leiten ein Muster ab
    if plannedSessions.count > 1 {
        if let pattern = deriveSequencePattern(from: plannedSessions) {
            let base     = plannedSessions.last!
            let baseDate = base.startTime.onlyDate

            // applySequencedPattern jetzt mit (sessions, usedRelaxed)
            let (patternDrafts, usedRelaxedPattern) = await applySequencedPattern(
                pattern: pattern,
                baseDate: baseDate,
                drafts: draftSessions,
                base: base,
                context: context,
                validator: validator,
                targetCount: remainingCount
            )

            // patientId anhängen
            let finalized = patternDrafts.map { s -> TreatmentSessions in
                var x = s
                if x.patientId == nil { x.patientId = patientId }
                return x
            }

            return (finalized, usedRelaxedPattern)
        } else {
            return ([], false)
        }
    }

    // FALL B: Frequenz-basierte Erstplanung
    // Startdatum bestimmen:
    // - Standard ist context.planningStartDate.onlyDate
    // - Falls schon fixe Sitzungen existieren (nicht-draft), starten wir frequency-basiert nach deren letztem Datum
    let cal = Calendar.current
    var planningStart = context.planningStartDate.onlyDate
    if let latestFixed = fixedSessions.max(by: { $0.startTime < $1.startTime }) {
        planningStart = cal.date(byAdding: .day,
                                 value: context.frequencyDays,
                                 to: latestFixed.startTime.onlyDate)
                        ?? planningStart
    }
    
    // Wunsch-Uhrzeit:
    // - Falls es fixe Sitzungen gibt, nimm deren Zeit (letzte bekannte Startzeit)
    // - sonst nimm plan.preferredTimeOfDay, sonst Fallback 08:00
    let preferredTime: (hour: Int, minute: Int) = {
        if let base = fixedSessions.last {
            return (
                base.startTime.timeOnly.hour    ?? 8,
                base.startTime.timeOnly.minute  ?? 0
            )
        } else {
            return plan.preferredTimeOfDay?.defaultTime ?? (8, 0)
        }
    }()
    
    // Frequency + erlaubte Tage
    let frequency        = plan.frequency ?? .weekly
    let allowedWeekdays  = (frequency == .multiplePerWeek) ? (plan.weekdays ?? []) : nil
    
    // Services aus dem Plan
    let serviceIds       = context.plan.treatmentServiceIds
    
    // Dauer
    let durationMinutes  = context.sessionDuration
    
    // scheduleDraftSessions jetzt mit (sessions, usedRelaxed)
    let (newDrafts, usedRelaxedFreq) = await scheduleDraftSessions(
        sessionTitle: context.plan.title!,
        draftSessions: draftSessions,
        startDate: planningStart,
        preferredStartTime: preferredTime,
        frequency: frequency,
        allowedWeekdays: allowedWeekdays,
        serviceIds: serviceIds,
        durationMinutes: durationMinutes,
        patientAddress: context.updatedPatientAddress,
        therapistAvailability: context.therapistAvailability,
        ownSessions: context.ownSessions,
        otherSessions: context.otherSessions,
        validator: validator,
        therapistId: therapistId,
        targetCount: remainingCount
    )
    
    // PatientId anhängen
    let finalized = newDrafts.map { s -> TreatmentSessions in
        var x = s
        if x.patientId == nil { x.patientId = patientId }
        return x
    }
    
    return (finalized, usedRelaxedFreq)
}
