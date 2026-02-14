//
//  PatientDetailContainerView.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 23.03.25.
//

import SwiftUI

struct PatientDetailContainerView: View {
    @Binding var patient: Patient
    @Binding var selectedTab: PatientDetailTab
    @Binding var selectedTherapy: Therapy?
    @State private var isEditingAnamnesis = false
    @State private var showContractForm = false
    @State private var isCreatingNewTherapy: Bool = false
    @Binding var refreshTrigger: UUID
    
    @EnvironmentObject var patientStore: PatientStore
    
    var body: some View {
            ZStack {
                // 🔹 Detailansicht (wenn eine Therapie ausgewählt ist)
                if let selected = selectedTherapy,
                   let index = patient.therapies.firstIndex(where: { $0?.id == selected.id }),
                   let binding = Binding($patient.therapies[index]) {
                    
                    TherapyDetailView(
                        patient: $patient,
                        therapy: binding,
                        selectedTherapy: $selectedTherapy
                    )
                    .transition(.move(edge: .trailing))
                    .id("therapyDetail")
                } else {
                    VStack(spacing: 0) {
                        // 🔹 Tab-Auswahl
                        Picker("", selection: $selectedTab) {
                            ForEach(PatientDetailTab.allCases, id: \ .self) { tab in
                                Text(tab.localizedLabel).tag(tab)
                            }
                        }
                        .pickerStyle(.segmented)
                        .tint(.secondary)
                        .padding(.horizontal)
                        .padding(.top)
                        
                        Divider()
                        .background(Color.divider.opacity(0.5))
                        
                    // 🔹 Tab-Inhalte
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            switch selectedTab {
                            case .masterData:
                                SectionBox(
                                    title: "",
                                    content: {
                                        PatientReadonlyView(patient: $patient, refreshTrigger: $refreshTrigger)
                                    }
                                )
                                
                            case .anamnesis:
                                if let anamnesis = patient.anamnesis {
                                    SectionBox(title: "") {
                                        AnamnesisView(anamnesis: anamnesis) {
                                            isEditingAnamnesis = true
                                        }
                                    }
                                } else {
                                    Button {
                                        patient.anamnesis = Anamnesis.empty(therapistId: AppGlobals.shared.therapistId)
                                        isEditingAnamnesis = true
                                    } label: {
                                        Label(NSLocalizedString("addAnamnesis", comment: "Add Anamnesis"), systemImage: "plus")
                                    }
                                    .foregroundColor(.addButton)
                                    .disabled(!patient.isActive)
                                    .help(patient.isActive ?
                                          NSLocalizedString("createAnamnesis", comment: "Create a new anamnesis") :
                                            NSLocalizedString("inactivePatientNoAnamnesis", comment: "Patient is inactive. Cannot create anamnesis."))
                                    .padding(.horizontal)
                                    .padding(.vertical, 15)
                                }
                                                               
                            case .therapies:
                                TherapyListView(
                                    patient: patient,
                                    selectedTherapy: $selectedTherapy,
                                    isCreatingNewTherapy: $isCreatingNewTherapy
                                )
                            }
                        }
                        .padding(.top)
                        .transition(.move(edge: .leading))  // Übergang von links
                        .id("tabContent")
                    }
                    .sheet(isPresented: $isEditingAnamnesis) {
                        if let anamnesis = patient.anamnesis {
                            NavigationStack {
                                AnamnesisEditView(
                                    initialAnamnesis: anamnesis,
                                    patient: patient
                                ) { updated in
                                    patient.anamnesis = updated
                                    patientStore.updatePatient(patient)
                                }
                            }
                        }
                    }
                    .sheet(isPresented: $isCreatingNewTherapy) {
                        NavigationStack {
                            TherapyEditorView(patientId: patient.id) { newTherapy in
                                var therapy = newTherapy
                                therapy.patientId = patient.id
                                therapy.id = UUID()
                                
                                // Optional: gleich speichern
                                patient.therapies.append(therapy)
                                patientStore.updatePatient(patient)
                            }
                        }
                    }
                    .navigationTitle(NSLocalizedString("patientRecord", comment: "Patient Record"))
                }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: selectedTherapy)
    }

}
        
    // MARK: - Tabs
    
    enum PatientDetailTab: String, CaseIterable, Hashable {
        case masterData, anamnesis, therapies  // treatmentContract
        
        var localizedLabel: String {
            switch self {
            case .masterData: return NSLocalizedString("masterDataTab", comment: "Master Data")
            case .anamnesis: return NSLocalizedString("anamnesis", comment: "Anamnesis")
            //case .treatmentContract: return NSLocalizedString("treatmentContract", comment: "Treatment contract")
            case .therapies: return NSLocalizedString("therapies", comment: "Therapies")
            }
        }
    }
    
    private func contractPDFURL(for patient: Patient) -> URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?
            .appendingPathComponent("patients")
            .appendingPathComponent(patient.id.uuidString)
            .appendingPathComponent("contract.pdf")
    }

