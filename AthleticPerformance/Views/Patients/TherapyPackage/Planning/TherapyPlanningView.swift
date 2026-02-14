//
//  TherapyPlanningView.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 21.05.25.
//

import SwiftUI

struct TherapyPlanningView: View {
    @Binding var therapy: Therapy
    let patient: Patient
    let allDiagnoses: [Diagnosis]
    let allServices: [TreatmentService]
    @EnvironmentObject var patientStore: PatientStore

    @State private var selectedPlan: TherapyPlan?
    @State private var expandedPlanIds: Set<UUID> = []
    @State private var planToDelete: TherapyPlan?
    @State private var showDeleteConfirmation = false
    @State private var isDirty = false

    @MainActor
    private var therapyPlansBinding: Binding<[TherapyPlan]> {
        Binding(
            get: { therapy.therapyPlans },
            set: { therapy.therapyPlans = $0 }
        )
    }

    var body: some View {
        VStack(alignment: .center, spacing: 16) {
            Button {
                createNewPlan()
            } label: {
                Label(
                    NSLocalizedString(
                        "addTherapyPlan",
                        comment: "Add therapy plan"
                    ),
                    systemImage: "plus"
                )
                .foregroundColor(.addButton)
            }
            .padding()

            ScrollView {
                VStack(spacing: 12) {
                    let sortedPlans = therapyPlansBinding.wrappedValue.sorted {
                        ($0.startDate ?? .distantPast)
                            > ($1.startDate ?? .distantPast)
                    }

                    ForEach(sortedPlans, id: \.id) { plan in
                        if let binding = binding(for: plan) {
                            planDisclosureGroup(for: binding)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .onAppear(perform: initializeIfNeeded)
        .sheet(item: $selectedPlan) { selected in
            if let binding = binding(for: selected) {
                planDetailSection(for: binding)
            }
        }
        .alert(
            NSLocalizedString(
                "reallyDeleteTherapyPlan",
                comment: "Really delete therapy plan?"
            ),
            isPresented: $showDeleteConfirmation
        ) {
            Button(
                NSLocalizedString("delete", comment: "Delete"),
                role: .destructive
            ) {
                if let plan = planToDelete {
                    therapy.therapyPlans.removeAll { $0.id == plan.id }  // 🔹 nur Binding ändern
                    isDirty = true  // 🔹 markieren
                    planToDelete = nil
                }
            }
            Button(
                NSLocalizedString("cancel", comment: "Cancel"),
                role: .cancel
            ) {
                planToDelete = nil
            }
        }
        .onDisappear {  // 🔹 EINMAL speichern
            if isDirty {
                persistCurrentPatient(wait: true)
                isDirty = false
            }
        }
    }

    // MARK: - Helpers

    private func persistCurrentPatient(wait: Bool) {
        var updatedPatient = patient
        if let idx = updatedPatient.therapies.firstIndex(where: {
            $0?.id == therapy.id
        }) {
            updatedPatient.therapies[idx] = therapy
        } else {
            updatedPatient.therapies.append(therapy)
        }
        patientStore.updatePatient(updatedPatient, waitUntilSaved: wait)  // 🔹 zentrale Stelle
    }

    private func createNewPlan() {
        let plannedIds = Set(
            therapyPlansBinding.wrappedValue.compactMap { $0.diagnosisId }
        )
        let available = therapy.diagnoses.filter {
            !$0.treatments.isEmpty && !plannedIds.contains($0.id)
        }

        if let nextDiagnosis = available.first {
            createNewPlan(for: nextDiagnosis)
            return
        }

        let plan = TherapyPlan(
            id: UUID(),
            diagnosisId: nil,
            therapistId: therapy.therapistId,
            title: NSLocalizedString(
                "newTherapyPlan",
                comment: "New Therapy Plan"
            ),
            treatmentServiceIds: [],
            frequency: .weekly,
            preferredTimeOfDay: .morning,
            startDate: therapy.startDate
        )
        therapy.therapyPlans.append(plan)  // 🔹 nur Binding
        expandedPlanIds.insert(plan.id)
        isDirty = true  // 🔹 markieren
    }

    private func createNewPlan(for diagnosis: Diagnosis) {
        let serviceIds = diagnosis.treatments.compactMap { $0.treatmentService }
        let maxSessions = diagnosis.treatments.map(\.number).max() ?? 0

        let plan = TherapyPlan(
            id: UUID(),
            diagnosisId: diagnosis.id,
            therapistId: therapy.therapistId,
            title: therapy.title,
            treatmentServiceIds: serviceIds,
            frequency: .weekly,
            preferredTimeOfDay: .morning,
            startDate: therapy.startDate,
            numberOfSessions: maxSessions
        )
        therapy.therapyPlans.append(plan)  // 🔹 nur Binding
        expandedPlanIds.insert(plan.id)
        isDirty = true  // 🔹 markieren
    }

    private func binding(for plan: TherapyPlan) -> Binding<TherapyPlan>? {
        guard
            let index = therapyPlansBinding.wrappedValue.firstIndex(where: {
                $0.id == plan.id
            })
        else { return nil }
        return Binding(
            get: { therapyPlansBinding.wrappedValue[index] },
            set: {
                therapyPlansBinding.wrappedValue[index] = $0
                isDirty = true
            }  // 🔹 Änderungen markieren
        )
    }

    private func initializeIfNeeded() {
        let existingDiagnosisIds = Set(
            therapy.therapyPlans.compactMap { $0.diagnosisId }
        )
        let unplannedDiagnoses = therapy.diagnoses.filter {
            !$0.treatments.isEmpty && !existingDiagnosisIds.contains($0.id)
        }
        guard !unplannedDiagnoses.isEmpty else { return }
        for d in unplannedDiagnoses { createNewPlan(for: d) }  // 🔹 markiert intern isDirty
    }

    private func planDisclosureGroup(for plan: Binding<TherapyPlan>)
        -> some View
    {
        let planId = plan.wrappedValue.id
        let isExpandedBinding = Binding(
            get: { expandedPlanIds.contains(planId) },
            set: { expanded in
                if expanded {
                    expandedPlanIds.insert(planId)
                } else {
                    expandedPlanIds.remove(planId)
                }
            }
        )

        return DisclosureGroup(isExpanded: isExpandedBinding) {
            VStack(alignment: .leading, spacing: 12) {
                planDetailSection(for: plan)
            }
            .padding(.top, 8)
        } label: {
            planHeader(for: plan)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6))
        )
    }

    @ViewBuilder
    private func planDetailSection(for plan: Binding<TherapyPlan>) -> some View
    {
        TherapyPlanDetailView(
            plan: plan,
            diagnoses: availableDiagnosesForPlanning(),
            allServices: allServices,
            availableTherapists: AppGlobals.shared.therapistList,
            patient: patient,
            therapy: therapy,
            onUpdatePlan: { updated in
                // 🔹 direkt ins Binding schreiben (keine Persistenz hier)
                if let idx = therapy.therapyPlans.firstIndex(where: {
                    $0.id == updated.id
                }) {
                    therapy.therapyPlans[idx] = updated
                    isDirty = true
                }
                selectedPlan = nil
            }
        )
        .environmentObject(patientStore)
    }

    private func availableDiagnosesForPlanning() -> [Diagnosis] {
        let plannedIds = Set(therapy.therapyPlans.compactMap { $0.diagnosisId })
        return therapy.diagnoses.filter {
            !$0.treatments.isEmpty && !plannedIds.contains($0.id)
        }
    }

    @ViewBuilder
    private func planHeader(for plan: Binding<TherapyPlan>) -> some View {
        HStack(spacing: 16) {
            Text(
                plan.wrappedValue.title
                    ?? NSLocalizedString(
                        "untitledPlan",
                        comment: "Untitled therapy plan"
                    )
            )
            .font(.headline)

            Spacer()

            let diagnosis = allDiagnoses.first(where: {
                $0.id == plan.wrappedValue.diagnosisId
            })
            Text(
                formatDiagnosisTitle(
                    diagnosis,
                    fallbackDate: plan.wrappedValue.startDate ?? Date()
                )
            )
            .font(.subheadline)
            .foregroundColor(.secondary)

            if plan.wrappedValue.treatmentSessions.allSatisfy({ $0.draft }) {
                Image(systemName: "trash")
                    .font(.system(size: 15, weight: .thin))
                    .padding(8)
                    .background(Color.deleteButton.opacity(0.6))
                    .clipShape(Circle())
                    .foregroundColor(.white)
                    .onTapGesture {
                        planToDelete = plan.wrappedValue
                        showDeleteConfirmation = true
                    }
                    .padding(.horizontal, 16)
            }
        }
        .contentShape(Rectangle())
    }
}

func formatDiagnosisTitle(_ diagnosis: Diagnosis?, fallbackDate: Date) -> String
{
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.locale = Locale.current

    if let diagnosis = diagnosis {
        let formattedDate = formatter.string(from: diagnosis.date)
        return "\(diagnosis.title) – \(formattedDate)"
    } else {
        let formattedFallback = formatter.string(from: fallbackDate)
        return NSLocalizedString(
            "withoutDiagnosis",
            comment: "Without diagnosis"
        ) + " – \(formattedFallback)"
    }
}
