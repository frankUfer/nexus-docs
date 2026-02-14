//
//  TherapyDetailView.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 15.04.25.
//

import SwiftUI

/// Detailansicht für eine einzelne Therapie
struct TherapyDetailView: View {
    @Binding var patient: Patient
    @Binding var therapy: Therapy
    @Binding var selectedTherapy: Therapy?

    @State private var selectedTab: TherapyTab = .overview
    //@StateObject var patientStore = PatientStore()
    @EnvironmentObject var patientStore: PatientStore

    enum TherapyTab: String, CaseIterable, Identifiable {
        case overview, diagnosis, findings, planning, sessions  // exercises, report => später

        var id: String { rawValue }

        var title: String {
            switch self {
            case .overview:
                return NSLocalizedString("overview", comment: "Overview")
            case .diagnosis:
                return NSLocalizedString("diagnosis", comment: "Diagnosis")
            case .findings:
                return NSLocalizedString("finding", comment: "Finding")
            case .planning:
                return NSLocalizedString("planning", comment: "Planning")
            //case .exercises: return NSLocalizedString("exercises", comment: "Exercises")
            case .sessions:
                return NSLocalizedString("sessions", comment: "Sessions")
            //case .report: return NSLocalizedString("dischargeReport", comment: "Discharge report")
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("Bereich", selection: $selectedTab) {
                ForEach(TherapyTab.allCases) { tab in
                    Text(tab.title).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .tint(.secondary)
            .padding()

            Divider()
                .background(Color.divider.opacity(0.5))

            // Dynamischer Inhalt pro Tab
            Group {
                switch selectedTab {
                case .overview:
                    TherapyOverviewView(
                        patient: $patient,
                        therapy: $therapy
                    )
                    .environmentObject(patientStore)
                case .diagnosis:
                    TherapyDiagnosisListView(
                        therapy: $therapy,
                        patient: $patient
                    )
                    .environmentObject(patientStore)
                
                case .findings:
                    TherapyFindingEditorView(
                        therapy: $therapy,
                        patient: $patient,
                        finding: $therapy.findings[0]
                    )
                    .environmentObject(patientStore)
                    
                case .planning:
                    TherapyPlanningView(
                        therapy: $therapy,
                        patient: patient,
                        allDiagnoses: therapy.diagnoses,
                        allServices: AppGlobals.shared.treatmentServices
                    )
                    .environmentObject(patientStore)
                    
                //                case .exercises:
                //                    TherapyOverviewView(
                //                        patient: $patient,
                //                        therapy: $therapy)
                case .sessions:
                    TherapySessionDisplayView(
                        therapy: $therapy,
                        patient: $patient
                    )
                    .environmentObject(patientStore)
                    
                //                case .report:
                //                    TherapyOverviewView(
                //                        patient: $patient,
                //                        therapy: $therapy)
                }
            }
        }
        .navigationTitle(
            therapy.title.isEmpty
                ? NSLocalizedString("therapy", comment: "Therapy")
                : therapy.title
        )
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if therapy.findings.isEmpty {
                therapy.findings.append(
                    Finding(
                        therapistId: nil,
                        patientId: therapy.patientId
                    )
                )
            }
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(action: {
                    withAnimation {
                        selectedTherapy = nil
                    }
                }) {
                    Image(systemName: "chevron.left")
                        .imageScale(.large)
                        .font(.title2)
                        .accessibilityLabel(
                            Text(NSLocalizedString("Back", comment: "Back"))
                        )
                }
            }
        }
    }
}
