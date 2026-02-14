//
//  SimpleSessionEditor.swift
//  AthleticPerformance
//
//  Created by Frank Ufer on 26.10.25.
//

import SwiftUI

struct SimpleSessionEditor: View {
    let session: TreatmentSessions
    let plan: TherapyPlan

    let initialDoc: TherapySessionDocumentation
    let onCommit: (TherapySessionDocumentation) -> Void
    let onCancel: () -> Void
    let onToggleStatus: () -> Void

    @State private var localDoc: TherapySessionDocumentation
    @State private var hasLocalChanges = false
    @State private var showValidationAlert = false

    init(
        session: TreatmentSessions,
        plan: TherapyPlan,
        initialDoc: TherapySessionDocumentation,
        onCommit: @escaping (TherapySessionDocumentation) -> Void,
        onCancel: @escaping () -> Void,
        onToggleStatus: @escaping () -> Void
    ) {
        self.session = session
        self.plan = plan
        self.initialDoc = initialDoc
        self.onCommit = onCommit
        self.onCancel = onCancel
        self.onToggleStatus = onToggleStatus
        _localDoc = State(initialValue: initialDoc)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {

                    // Status toggeln
                    Button(action: {
                        // doppelter Schutz: nur ausführen, wenn Notes lang genug
                        if localDoc.notes.trimmingCharacters(in: .whitespacesAndNewlines).count >= 10 {
                            onToggleStatus()
                        }
                    }) {
                        HStack {
                            Text("\(NSLocalizedString("status", comment: "Status")):")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(session.currentStatusText).bold()
                            Image(systemName: session.currentStatusIcon)
                        }
                    }
                    .tint(session.statusColor)
                    .disabled(localDoc.notes.trimmingCharacters(in: .whitespacesAndNewlines).count < 10)
                    .opacity(localDoc.notes.trimmingCharacters(in: .whitespacesAndNewlines).count < 10 ? 0.4 : 1.0)

                    // Notizen
                    DisplaySectionBox(
                        title: NSLocalizedString("notes", comment: "Notes"),
                        lightAccentColor: .accentColor,
                        darkAccentColor: .accentColor
                    ) {
                        TextEditor(text: $localDoc.notes)
                            .frame(minHeight: 80)
                            .padding(4)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.secondary)
                            )
                            .onChange(of: localDoc.notes) { _, _ in
                                hasLocalChanges = true
                            }
                    }

                    AppliedTreatmentsEntryList(
                        appliedTreatments: $localDoc.appliedTreatments,
                        plan: plan,
                        allServices: AppGlobals.shared.treatmentServices,
                        sessionId: session.id,
                        sessionDocs: plan.sessionDocs,
                        onEdited: { hasLocalChanges = true }
                    )

                    SymptomsEntryList(
                        entries: $localDoc.symptoms,
                        titleKey: NSLocalizedString("symptoms", comment: "Symptoms"),
                        availableBodyRegions: AppGlobals.shared.bodyRegionGroups,
                        availablePainQualities: AppGlobals.shared.painQualities,
                        availablePainStructures: AppGlobals.shared.painStructure,
                        onEdited: { hasLocalChanges = true },
                        isEditable: false
                    )

                    JointStatusEntryList(
                        entries: $localDoc.joints,
                        titleKey: NSLocalizedString("joints", comment: "Joints"),
                        availableJoints: AppGlobals.shared.jointsData,
                        availableMovements: AppGlobals.shared.jointMovementPatterns,
                        availablePainQualities: AppGlobals.shared.painQualities,
                        availableEndFeelings: AppGlobals.shared.endFeelings,
                        onEdited: { hasLocalChanges = true },
                        isEditable: false
                    )

                    MuscleStatusEntryList(
                        entries: $localDoc.muscles,
                        titleKey: NSLocalizedString("muscles", comment: "Muscles"),
                        availableMuscleGroups: AppGlobals.shared.muscleGroupsData,
                        availablePainQualities: AppGlobals.shared.painQualities,
                        onEdited: { hasLocalChanges = true },
                        isEditable: false
                    )

                    TissueStatusEntryList(
                        entries: $localDoc.tissues,
                        titleKey: NSLocalizedString("tissues", comment: "Tissues"),
                        availableTissues: AppGlobals.shared.tissuesData,
                        availableTissueStates: AppGlobals.shared.tissueStatesData,
                        availablePainQualities: AppGlobals.shared.painQualities,
                        onEdited: { hasLocalChanges = true },
                        isEditable: false
                    )

                    AssessmentStatusEntryList(
                        entries: $localDoc.assessments,
                        titleKey: NSLocalizedString("assessments", comment: "Assessments"),
                        availableAssessments: AppGlobals.shared.assessments,
                        onEdited: { hasLocalChanges = true },
                        isEditable: false
                    )

                    OtherAnomalieStatusEntryList(
                        entries: $localDoc.otherAnomalies,
                        titleKey: NSLocalizedString("anomalies", comment: "Anomalies"),
                        availableBodyRegions: AppGlobals.shared.bodyRegionGroups,
                        availablePainQualities: AppGlobals.shared.painQualities,
                        availablePainStructures: AppGlobals.shared.painStructure,
                        onEdited: { hasLocalChanges = true },
                        isEditable: false
                    )
                }
                .padding(.vertical, 8)
                .padding(.horizontal)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .cancel) {
                        onCancel()
                    } label: {
                        Text(NSLocalizedString("cancel", comment: "Cancel"))
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        if localDoc.notes.trimmingCharacters(in: .whitespacesAndNewlines).count >= 10 {
                            onCommit(localDoc)
                        } else {
                            showValidationAlert = true
                        }
                    } label: {
                        Text(NSLocalizedString("save", comment: "Save")).bold()
                    }
                }
            }
            .alert(isPresented: $showValidationAlert) {
                Alert(
                    title: Text(NSLocalizedString("invalidNotesTitle", comment: "Invalid notes")),
                    message: Text(NSLocalizedString("documentationMissing", comment: "Please enter at least 10 characters in the notes field before saving.")),
                    dismissButton: .default(Text("OK"))
                )
            }
            .navigationTitle(
                session.startTime.formatted(.dateTime.day().month().year())
            )
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
