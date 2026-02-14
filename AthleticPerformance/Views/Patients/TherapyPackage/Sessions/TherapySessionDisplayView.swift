//
//  TherapySessionDisplayView.swift
//  AthleticPerformance
//
//  Created by Frank Ufer on 25.10.25.
//

import SwiftUI

struct TherapySessionDisplayView: View {
    @Binding var therapy: Therapy
    @Binding var patient: Patient
    @EnvironmentObject var patientStore: PatientStore

    @State private var showAnamnesis = false
    @State private var expandedPlanIDs: Set<UUID> = []
    @State private var expandedSessionIDs: Set<UUID> = []

    @State private var editingContext: EditingContext?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {

                anamnesisSection

                goalsAndRisksSection

                ForEach(sortedPlans, id: \.id) { plan in
                    planDisclosure(plan)
                }
            }
            .padding()
        }
        .fullScreenCover(item: $editingContext) { ctx in
            let planRef = therapy.therapyPlans[ctx.planIndex]

            SimpleSessionEditor(
                session: planRef.treatmentSessions[ctx.sessionIndex],
                plan: planRef,
                initialDoc: ctx.initialDoc,
                onCommit: { finalDoc in
                    applyEdits(
                        finalDoc: finalDoc,
                        planIndex: ctx.planIndex,
                        sessionIndex: ctx.sessionIndex
                    )
                    editingContext = nil
                },
                onCancel: {
                    // <- NEU: erst Regel durchsetzen, dann Sheet schließen
                    handleCancelFromEditor(
                        planIndex: ctx.planIndex,
                        sessionIndex: ctx.sessionIndex
                    )
                    editingContext = nil
                },
                onToggleStatus: {
                    // Benutzer will Status aktiv ändern.
                    // Diese Entscheidung respektieren wir, denn das darf er nur bei ausreichender Doku
                    toggleSessionStatus(
                        planIndex: ctx.planIndex,
                        sessionIndex: ctx.sessionIndex
                    )
                }
            )
        }
    }
    
    private func handleCancelFromEditor(planIndex: Int,
                                        sessionIndex: Int) {

        // Safety: Indizes checken
        guard therapy.therapyPlans.indices.contains(planIndex),
              therapy.therapyPlans[planIndex].treatmentSessions.indices.contains(sessionIndex)
        else { return }

        // 1. Session holen (aktueller Status)
        var session = therapy.therapyPlans[planIndex]
            .treatmentSessions[sessionIndex]

        // 2. Dokumentation holen, aber NUR die persistierte Version
        let sessionId = session.id
        let persistedDoc = therapy.therapyPlans[planIndex]
            .sessionDocs
            .first(where: { $0.sessionId == sessionId })

        let persistedNotes = persistedDoc?.notes
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        let persistedNotesAreValid = persistedNotes.count >= 10

        // 3. Regel: Ist die Doku (persistiert) unzureichend?
        // Dann darf der Termin nicht "done" bleiben.
        if !persistedNotesAreValid {
            session.isDone = false
            session.isScheduled = true

            therapy.therapyPlans[planIndex]
                .treatmentSessions[sessionIndex] = session

            updateCompletionStatus(forPlanIndex: planIndex)
            updateTherapyCompletionStatus()
            persistToStore()
        }
    }

    // MARK: - EditingContext
    private struct EditingContext: Identifiable {
        let id = UUID()
        let planIndex: Int
        let sessionIndex: Int
        let initialDoc: TherapySessionDocumentation
    }

    // MARK: Anamnese (Anzeige)
    private var anamnesisSection: some View {
        DisclosureGroup(isExpanded: $showAnamnesis) {
            if let anamnesis = patient.anamnesis {
                // Nur Anzeige, kein Edit
                AnamnesisView(anamnesis: anamnesis, onEdit: { })
                    .padding(.top, 8)
            } else {
                Text(NSLocalizedString("noAnamnesisData", comment: "No anamnesis data available"))
                    .foregroundColor(.secondary)
                    .italic()
            }
        } label: {
            Text(NSLocalizedString("anamnesis", comment: "Anamnesis"))
                .font(.headline)
                .padding(.vertical, 8)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.separator), lineWidth: 1))
    }

    // MARK: Ziele / Risiken / Notes (Anzeige)
    private var goalsAndRisksSection: some View {
        let goalsTrimmed = therapy.goals.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasGoals = !goalsTrimmed.isEmpty

        let risksTrimmed = therapy.risks.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasRisks = !risksTrimmed.isEmpty

        let firstFindingNotesTrimmed: String? = {
            if let raw = therapy.findings.first?.notes?
                .trimmingCharacters(in: .whitespacesAndNewlines),
               !raw.isEmpty {
                return raw
            } else {
                return nil
            }
        }()

        let hasNotes = firstFindingNotesTrimmed != nil

        if !hasGoals && !hasRisks && !hasNotes {
            return AnyView(EmptyView())
        }

        return AnyView(
            DisplaySectionBox(
                title: NSLocalizedString("goalsAndRisks", comment: "Goals and risks"),
                lightAccentColor: .accentColor,
                darkAccentColor: .accentColor
            ) {
                VStack(alignment: .leading, spacing: 8) {

                    if hasGoals {
                        KeyValueRow(
                            key: NSLocalizedString("goal", comment: "Goal"),
                            value: goalsTrimmed
                        )
                    }

                    if hasRisks {
                        KeyValueRow(
                            key: NSLocalizedString("risks", comment: "Risks"),
                            value: risksTrimmed
                        )
                    }

                    if let notesText = firstFindingNotesTrimmed {
                        KeyValueRow(
                            key: NSLocalizedString("notes", comment: "Notes"),
                            value: notesText
                        )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        )
    }

    // MARK: Pläne & Sessions (Anzeige + Edit-Button pro Session)

    private var sortedPlans: [TherapyPlan] {
        therapy.therapyPlans.sorted {
            ($0.startDate ?? .distantPast) > ($1.startDate ?? .distantPast)
        }
    }

    private func sortedSessions(for plan: TherapyPlan) -> [TreatmentSessions] {
        plan.treatmentSessions.sorted { $0.startTime < $1.startTime }
    }

    @ViewBuilder
    private func planDisclosure(_ plan: TherapyPlan) -> some View {
        if plan.treatmentSessions.isEmpty {
            EmptyView()
        } else {
            DisclosureGroup(
                isExpanded: Binding(
                    get: { expandedPlanIDs.contains(plan.id) },
                    set: { isExpanded in
                        if isExpanded {
                            _ = expandedPlanIDs.insert(plan.id)
                        } else {
                            expandedPlanIDs.remove(plan.id)
                        }
                    }
                )
            ) {
                VStack(alignment: .leading, spacing: 20) {
                    // Wir brauchen Indexe fürs Editieren
                    if let planIdx = therapy.therapyPlans.firstIndex(where: { $0.id == plan.id }) {

                        let sorted = sortedSessions(for: plan)

                        ForEach(Array(sorted.enumerated()), id: \.element.id) { (sessionIdxInSorted, session) in

                            // mapping von sessionIdxInSorted -> echter Index im Plan
                            // wir brauchen den echten Index im Plan-Array für persistente Updates
                            if let realSessionIdx = therapy.therapyPlans[planIdx]
                                .treatmentSessions
                                .firstIndex(where: { $0.id == session.id }) {

                                sessionBlock(
                                    planIndex: planIdx,
                                    sessionIndex: realSessionIdx
                                )
                            }
                        }
                    }
                }
                .padding(.horizontal)
            } label: {
                HStack {
                    Text((plan.title ?? "").isEmpty
                         ? NSLocalizedString("untitledPlan", comment: "")
                         : (plan.title ?? "")
                    )
                    .font(.headline)

                    Spacer()

                    if let period = formattedPeriod(for: plan) {
                        Text(period)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(.separator), lineWidth: 1)
            )
        }
    }

    // Ein einzelner Session-Block inklusive Edit-Button
    @ViewBuilder
    private func sessionBlock(planIndex: Int, sessionIndex: Int) -> some View {
        let plan = therapy.therapyPlans[planIndex]
        let session = plan.treatmentSessions[sessionIndex]
        let doc = plan.sessionDocs.first(where: { $0.sessionId == session.id })
            ?? TherapySessionDocumentation(sessionId: session.id)

        DisclosureGroup(
            isExpanded: Binding(
                get: { expandedSessionIDs.contains(session.id) },
                set: { isExpanded in
                    if isExpanded {
                        _ = expandedSessionIDs.insert(session.id)
                    } else {
                        expandedSessionIDs.remove(session.id)
                    }
                }
            )
        ) {
            VStack(alignment: .leading, spacing: 16) {
                
                // NEU: Header-Reihe im aufgeklappten Bereich
                HStack(alignment: .top) {
                    // Links: Status (damit man den aktuellen Zustand sofort sieht)
                    StatusDisplayRow(session: session)

                    Spacer()

                    // Rechts: Edit-Button (nur Icon)
                    Button {
                        let seeded = seededDocForSession(
                            session: session,
                            in: plan
                        )

                        editingContext = EditingContext(
                            planIndex: planIndex,
                            sessionIndex: sessionIndex,
                            initialDoc: seeded
                        )
                    } label: {
                        Image(systemName: "pencil.circle.fill")
                            .font(.title3)
                            .foregroundColor(.accentColor)
                            .accessibilityLabel(
                                Text(NSLocalizedString("edit", comment: "Edit"))
                            )
                    }
                }

                // NOTES
                if !doc.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    NotesDisplayBox(text: doc.notes)
                }

                // APPLIED TREATMENTS
                AppliedTreatmentsList(
                    treatmentServiceIds: plan.treatmentServiceIds,
                    appliedTreatmentsForSession: doc.appliedTreatments,
                    allServices: AppGlobals.shared.treatmentServices
                )

                // SYMPTOMS
                if !doc.symptoms.isEmpty {
                    SymptomsStatusDisplayList(
                        entries: doc.symptoms,
                        titleKey: NSLocalizedString("symptoms", comment: "Symptoms")
                    )
                }

                // JOINTS
                if !doc.joints.isEmpty {
                    JointStatusDisplayList(
                        entries: doc.joints,
                        titleKey: NSLocalizedString("joints", comment: "Joints"),
                        availableMovements: AppGlobals.shared.jointMovementPatterns,
                        availablePainQualities: AppGlobals.shared.painQualities,
                        availableEndFeelings: AppGlobals.shared.endFeelings
                    )
                }

                // MUSCLES
                if !doc.muscles.isEmpty {
                    MuscleStatusDisplayList(
                        entries: doc.muscles,
                        titleKey: NSLocalizedString("muscles", comment: "Muscles")
                    )
                }

                // TISSUES
                if !doc.tissues.isEmpty {
                    TissueStatusDisplayList(
                        entries: doc.tissues,
                        titleKey: NSLocalizedString("tissues", comment: "Tissues")
                    )
                }

                // ASSESSMENTS
                if !doc.assessments.isEmpty {
                    AssessmentStatusDisplayList(
                        entries: doc.assessments,
                        titleKey: NSLocalizedString("assessments", comment: "Assessments"),
                        availableAssessments: AppGlobals.shared.assessments
                    )
                }

                // ANOMALIES
                if !doc.otherAnomalies.isEmpty {
                    OtherAnomalieStatusDisplayList(
                        entries: doc.otherAnomalies,
                        titleKey: NSLocalizedString("anomalies", comment: "Anomalies"),
                        availableBodyRegions: AppGlobals.shared.bodyRegionGroups,
                        availablePainQualities: AppGlobals.shared.painQualities,
                        availablePainStructures: AppGlobals.shared.painStructure
                    )
                }
            }
            .padding(.vertical, 4)
        } label: {
            Text(session.startTime.formatted(.dateTime.day().month().year()))
                .font(.subheadline)
                .foregroundColor(session.statusColor)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.separator))
        )
        .padding(.vertical, 4)
    }

    private func formattedPeriod(for plan: TherapyPlan) -> String? {
        let start = plan.treatmentSessions.map(\.startTime).min()
        let end = plan.treatmentSessions.map(\.endTime).max()
        guard let start else { return nil }
        let s = start.formatted(date: .abbreviated, time: .omitted)
        if let end {
            return "\(s) – \(end.formatted(date: .abbreviated, time: .omitted))"
        }
        return s
    }

    // MARK: Anzeige-Helfer lokal

    private struct StatusDisplayRow: View {
        let session: TreatmentSessions
        var body: some View {
            HStack {
                Text("\(NSLocalizedString("status", comment: "Status")):")
                    .foregroundColor(.secondary)
                Text(session.currentStatusText).bold()
                Image(systemName: session.currentStatusIcon)
            }
            .foregroundColor(session.statusColor)
        }
    }

    private struct NotesDisplayBox: View {
        let text: String
        var body: some View {
            DisplaySectionBox(
                title: NSLocalizedString("notes", comment: "Notes"),
                lightAccentColor: .accentColor,
                darkAccentColor: .accentColor
            ) {
                Text(text)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private struct KeyValueRow: View {
        let key: String
        let value: String
        var body: some View {
            HStack(alignment: .top, spacing: 8) {
                Text(key + ":")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(width: 120, alignment: .leading)
                Text(value)
                    .font(.body)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - Aktionen aus dem Editor

    /// Save gedrückt: finalDoc muss ins Modell geschrieben und persistiert werden.
    private func applyEdits(finalDoc: TherapySessionDocumentation,
                            planIndex: Int,
                            sessionIndex: Int) {

        // 1. Session ID
        let sessionId = therapy.therapyPlans[planIndex]
            .treatmentSessions[sessionIndex].id

        // 2. Doc setzen/anhängen
        if let existingIdx = therapy.therapyPlans[planIndex]
            .sessionDocs
            .firstIndex(where: { $0.sessionId == sessionId }) {

            therapy.therapyPlans[planIndex].sessionDocs[existingIdx] = finalDoc
        } else {
            therapy.therapyPlans[planIndex].sessionDocs.append(finalDoc)
        }

        // 3. Completion-Status aktualisieren
        updateCompletionStatus(forPlanIndex: planIndex)
        updateTherapyCompletionStatus()

        // 4. persistieren
        persistToStore()
    }

    /// Toggle Status aus dem Editor
    private func toggleSessionStatus(planIndex: Int,
                                     sessionIndex: Int) {

        var session = therapy.therapyPlans[planIndex]
            .treatmentSessions[sessionIndex]

        if session.isDone {
            session.isDone = false
            session.isScheduled = true
        } else {
            session.isDone = true
            session.isScheduled = false
        }

        therapy.therapyPlans[planIndex].treatmentSessions[sessionIndex] = session

        updateCompletionStatus(forPlanIndex: planIndex)
        updateTherapyCompletionStatus()

        persistToStore()
    }
    
    private func attemptToggleSessionStatus(planIndex: Int,
                                            sessionIndex: Int) {
        // 1. Erst normalen Toggle fahren (das ist dein bestehender Mechanismus)
        toggleSessionStatus(planIndex: planIndex,
                            sessionIndex: sessionIndex)

        // 2. Danach prüfen, ob die Session jetzt "done" ist, aber keine ausreichende Dokumentation hat
        guard therapy.therapyPlans.indices.contains(planIndex),
              therapy.therapyPlans[planIndex].treatmentSessions.indices.contains(sessionIndex)
        else { return }

        // Hole aktuelle Session nach dem Toggle
        var session = therapy.therapyPlans[planIndex]
            .treatmentSessions[sessionIndex]

        // Hole die aktuelle Dokumentation für diese Session
        let sessionId = session.id
        let doc = therapy.therapyPlans[planIndex]
            .sessionDocs
            .first(where: { $0.sessionId == sessionId })

        let notesText = doc?.notes
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        let notesAreValid = notesText.count >= 10

        // Business-Regel:
        // "Eine Session darf nur done bleiben, wenn genug Notes vorhanden sind."
        if session.isDone && !notesAreValid {
            // Sofort wieder zurück auf 'scheduled'
            session.isDone = false
            session.isScheduled = true

            therapy.therapyPlans[planIndex]
                .treatmentSessions[sessionIndex] = session

            // Completion-Status / Persist wieder aktualisieren
            updateCompletionStatus(forPlanIndex: planIndex)
            updateTherapyCompletionStatus()
            persistToStore()
        }
    }

    private func updateCompletionStatus(forPlanIndex idx: Int) {
        let allDone = therapy.therapyPlans[idx]
            .treatmentSessions
            .allSatisfy { $0.isDone }
        therapy.therapyPlans[idx].isCompleted = allDone
    }

    private func updateTherapyCompletionStatus() {
        let allSessions = therapy.therapyPlans.flatMap { $0.treatmentSessions }
        let allDone = !allSessions.isEmpty && allSessions.allSatisfy { $0.isDone }
        let allPlansDone = therapy.therapyPlans.allSatisfy { $0.isCompleted }

        if allDone && allPlansDone, therapy.endDate == nil {
            therapy.endDate = allSessions.map(\.endTime).max() ?? Date()
        }
    }

    private func persistToStore() {
        // Therapie in den Patient zurückschreiben
        var updatedTherapy = therapy
        updatedTherapy.patientId = patient.id

        var found = false
        patient.therapies = patient.therapies.compactMap { opt in
            guard let t = opt else { return nil }
            if t.id == updatedTherapy.id {
                found = true
                return updatedTherapy
            }
            return t
        }
        if !found {
            patient.therapies.append(updatedTherapy)
        }

        patient.changedDate = Date()

        patientStore.updatePatient(patient, waitUntilSaved: true)
    }
    
    // MARK: - Helper: Seeds aus re-evaluation in initialDoc einmischen
    private func seededDocForSession(
        session: TreatmentSessions,
        in plan: TherapyPlan
    ) -> TherapySessionDocumentation {

        // Basis-Dokument dieser Session
        var doc = plan.sessionDocs.first(where: { $0.sessionId == session.id })
            ?? TherapySessionDocumentation(sessionId: session.id)

        // Seeds aus allen Findings der Therapy (reevaluation == true)
        let seedSymptoms    = therapy.findings.flatMap { $0.symptoms.filter    { $0.reevaluation } }
        let seedJoints      = therapy.findings.flatMap { $0.joints.filter      { $0.reevaluation } }
        let seedMuscles     = therapy.findings.flatMap { $0.muscles.filter     { $0.reevaluation } }
        let seedTissues     = therapy.findings.flatMap { $0.tissues.filter     { $0.reevaluation } }
        let seedAssessments = therapy.findings.flatMap { $0.assessments.filter { $0.reevaluation } }
        let seedAnomalies   = therapy.findings.flatMap { $0.otherAnomalies.filter { $0.reevaluation } }

        func merge<T: Identifiable & Equatable>(_ into: inout [T], seeds: [T]) {
            for s in seeds where !into.contains(where: { $0.id == s.id }) {
                into.append(s)
            }
        }

        merge(&doc.symptoms,       seeds: seedSymptoms)
        merge(&doc.joints,         seeds: seedJoints)
        merge(&doc.muscles,        seeds: seedMuscles)
        merge(&doc.tissues,        seeds: seedTissues)
        merge(&doc.assessments,    seeds: seedAssessments)
        merge(&doc.otherAnomalies, seeds: seedAnomalies)

        return doc
    }
}
