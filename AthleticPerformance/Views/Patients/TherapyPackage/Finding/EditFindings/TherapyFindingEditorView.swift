//
//  TherapyFindingView.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 09.05.25.
//

import SwiftUI

struct TherapyFindingEditorView: View {
    @Binding var therapy: Therapy
    @Binding var patient: Patient
    @Binding var finding: Finding
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var patientStore: PatientStore
    @Environment(\.scenePhase) private var scenePhase

    @State private var title: String = ""
    @State private var date: Date = Date()
    @State private var notes: String = ""
    @State private var goals: String = ""
    @State private var risks: String = ""

    @State private var symptomEntries: [SymptomsStatusEntry] = []
    @State private var jointEntries: [JointStatusEntry] = []
    @State private var muscleEntries: [MuscleStatusEntry] = []
    @State private var tissueEntries: [TissueStatusEntry] = []
    @State private var assessmentEntries: [AssessmentStatusEntry] = []
    @State private var anomaliesEntries: [OtherAnomalieStatusEntry] = []

    @State private var showAnamnesis: Bool = false
    @State private var showAnamnesisEditor = false

    @State private var isDirty = false

    @State private var isSaving = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // 🔽 Anamnese
                DisclosureGroup(isExpanded: $showAnamnesis) {
                    if let anamnesis = patient.anamnesis {
                        AnamnesisView(
                            anamnesis: anamnesis,
                            onEdit: { showAnamnesisEditor = true }
                        )
                        .padding(.top, 8)
                    } else {
                        Text(
                            NSLocalizedString(
                                "noAnamnesisData",
                                comment: "No anamnesis data available"
                            )
                        )
                        .foregroundColor(.secondary)
                        .italic()
                    }
                } label: {
                    HStack {
                        Text(
                            NSLocalizedString("anamnesis", comment: "Anamnesis")
                        )
                        .font(.headline)
                    }
                    .padding(.vertical, 8)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12).stroke(
                        Color(.separator),
                        lineWidth: 1
                    )
                )

                generalSection
                Divider()
                symptomsSection
                Divider()
                jointsSection
                Divider()
                musclesSection
                Divider()
                tissuesSection
                Divider()
                assessmentsSection
                Divider()
                anomaliesSection
            }
            .padding()
        }
        .sheet(isPresented: $showAnamnesisEditor) {
            if let anamnesis = patient.anamnesis {
                NavigationStack {
                    AnamnesisEditView(
                        initialAnamnesis: anamnesis,
                        patient: patient,
                        onSave: { updatedAnamnesis in
                            patient.anamnesis = updatedAnamnesis
                            isDirty = true
                        }
                    )
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .onAppear {
            title = finding.title
            date = finding.date
            notes = finding.notes ?? ""
            goals = therapy.goals
            risks = therapy.risks
            symptomEntries = finding.symptoms
            jointEntries = finding.joints
            muscleEntries = finding.muscles
            tissueEntries = finding.tissues
            assessmentEntries = finding.assessments
            anomaliesEntries = finding.otherAnomalies
            isDirty = false
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .inactive || newPhase == .background {
                commitIfDirty(trigger: "scenePhase(\(newPhase))")
            }
        }
        .onDisappear {
            commitIfDirty(trigger: "onDisappear")
        }
        .onChange(of: title) { _, _ in isDirty = true }
        .onChange(of: date) { _, _ in isDirty = true }
        .onChange(of: notes) { _, _ in isDirty = true }
        .onChange(of: goals) { _, _ in isDirty = true }
        .onChange(of: risks) { _, _ in isDirty = true }
    }

    // MARK: - Sections

    private var generalSection: some View {
        DisplaySectionBox(
            title: NSLocalizedString(
                "goalsAndRisks",
                comment: "Goals and risks"
            ),
            lightAccentColor: .accentColor,
            darkAccentColor: .accentColor
        ) {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(NSLocalizedString("history", comment: "History"))
                        .font(.subheadline).foregroundColor(.secondary)
                    TextEditor(text: $notes)
                        .frame(minHeight: 80)
                        .padding(4)
                        .background(
                            RoundedRectangle(cornerRadius: 8).stroke(
                                Color.secondary
                            )
                        )
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(NSLocalizedString("goal", comment: "Goal"))
                        .font(.subheadline).foregroundColor(.secondary)
                    TextEditor(text: $goals)
                        .frame(minHeight: 80)
                        .padding(4)
                        .background(
                            RoundedRectangle(cornerRadius: 8).stroke(
                                Color.secondary
                            )
                        )
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(NSLocalizedString("risks", comment: "Risks"))
                        .font(.subheadline).foregroundColor(.secondary)
                    TextEditor(text: $risks)
                        .frame(minHeight: 80)
                        .padding(4)
                        .background(
                            RoundedRectangle(cornerRadius: 8).stroke(
                                Color.secondary
                            )
                        )
                }
            }
        }
    }

    private var symptomsSection: some View {
        SymptomsEntryList(
            entries: $symptomEntries,
            titleKey: NSLocalizedString("symptoms", comment: "Symptoms"),
            availableBodyRegions: AppGlobals.shared.bodyRegionGroups,
            availablePainQualities: AppGlobals.shared.painQualities,
            availablePainStructures: AppGlobals.shared.painStructure,
            onEdited: { markDirty() }
        )
    }

    private var jointsSection: some View {
        JointStatusEntryList(
            entries: $jointEntries,
            titleKey: NSLocalizedString("joints", comment: "Joints"),
            availableJoints: AppGlobals.shared.jointsData,
            availableMovements: AppGlobals.shared.jointMovementPatterns,
            availablePainQualities: AppGlobals.shared.painQualities,
            availableEndFeelings: AppGlobals.shared.endFeelings,
            onEdited: { markDirty() }
        )
    }

    private var musclesSection: some View {
        MuscleStatusEntryList(
            entries: $muscleEntries,
            titleKey: NSLocalizedString("muscles", comment: "Muscles"),
            availableMuscleGroups: AppGlobals.shared.muscleGroupsData,
            availablePainQualities: AppGlobals.shared.painQualities,
            onEdited: { markDirty() }
        )
    }

    private var tissuesSection: some View {
        TissueStatusEntryList(
            entries: $tissueEntries,
            titleKey: NSLocalizedString("tissues", comment: "Tissues"),
            availableTissues: AppGlobals.shared.tissuesData,
            availableTissueStates: AppGlobals.shared.tissueStatesData,
            availablePainQualities: AppGlobals.shared.painQualities,
            onEdited: { markDirty() }
        )
    }

    private var assessmentsSection: some View {
        AssessmentStatusEntryList(
            entries: $assessmentEntries,
            titleKey: NSLocalizedString("assessments", comment: "Assessments"),
            availableAssessments: AppGlobals.shared.assessments,
            onEdited: { markDirty() }
        )
    }

    private var anomaliesSection: some View {
        OtherAnomalieStatusEntryList(
            entries: $anomaliesEntries,
            titleKey: NSLocalizedString("anomalies", comment: "Anomalies"),
            availableBodyRegions: AppGlobals.shared.bodyRegionGroups,
            availablePainQualities: AppGlobals.shared.painQualities,
            availablePainStructures: AppGlobals.shared.painStructure,
            onEdited: { markDirty() }
        )
    }

    // MARK: - Commit/Save
    /// Zentraler Save-Entry-Point mit Reentrancy-Guard und Tastatur-Dismiss.
    private func commitIfDirty(trigger: String) {
        guard isDirty, !isSaving else { return }
        isSaving = true

        // 1) Fokus/Tastatur schließen, damit Text-Controls committen
        endEditing()

        // 2) Nächste Runloop abwarten → vermeidet Rennen mit UI-Updates
        DispatchQueue.main.async {
            saveBack(waitUntilSaved: true)
            isSaving = false
        }
    }

    // MARK: - Save / Dirty
    private func saveBack(waitUntilSaved: Bool) {
        var updatedPatient = patient

        guard
            let therapyIndex = updatedPatient.therapies.firstIndex(where: {
                $0?.id == therapy.id
            }),
            var currentTherapy = updatedPatient.therapies[therapyIndex],
            let findingIndex = currentTherapy.findings.firstIndex(where: {
                $0.id == finding.id
            })
        else { return }

        var updatedFinding = finding
        updatedFinding.title = title
        updatedFinding.date = date
        updatedFinding.notes = notes
        updatedFinding.symptoms = symptomEntries
        updatedFinding.joints = jointEntries
        updatedFinding.muscles = muscleEntries
        updatedFinding.tissues = tissueEntries
        updatedFinding.assessments = assessmentEntries
        updatedFinding.otherAnomalies = anomaliesEntries

        currentTherapy.goals = goals
        currentTherapy.risks = risks

        currentTherapy.findings[findingIndex] = updatedFinding
        updatedPatient.therapies[therapyIndex] = currentTherapy

        patient = updatedPatient
        patientStore.updatePatient(
            updatedPatient,
            waitUntilSaved: waitUntilSaved
        )
        isDirty = false
    }

    @MainActor
    private func markDirty() { isDirty = true }
}

// MARK: - Kleine UIKit-Hilfe zum Beenden der Bearbeitung
#if canImport(UIKit)
    private func endEditing() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }
#else
    private func endEditing() {}
#endif
