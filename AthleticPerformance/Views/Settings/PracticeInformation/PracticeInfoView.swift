//
//  PracticeInfoView.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 08.04.25.
//

import SwiftUI
import LocalAuthentication

struct PracticeInfoView: View {
    @EnvironmentObject var globals: AppGlobals
    @State private var isModified = false
    @State private var showValidationAlert = false
    @State private var editingSection: EditingSection? = nil

    enum EditingSection {
        case practice
        case therapists
        case services
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {

                // MARK: - Praxisdaten
                DisplaySectionBox(title: "practiceDetails", lightAccentColor: .accentColor, darkAccentColor: .accentColor) {
                    if editingSection == .practice {
                        PracticeInfoEditorView(practice: $globals.practiceInfo, onChange: { isModified = true }) {
                            saveAndReset()
                        } onCancel: {
                            editingSection = nil
                        }
                    } else {
                        PracticeInfoReadonlyView(practice: globals.practiceInfo)
                            .contextMenu {
                                Button {
                                    authenticateAndEdit(.practice)
                                } label: {
                                    Label(NSLocalizedString("edit", comment: "Edit"), systemImage: "pencil")
                                }
                            }
                            .foregroundColor(.edit)
                            .onLongPressGesture {
                                authenticateAndEdit(.practice)
                            }
                    }
                }

                // MARK: - Therapeuten
                DisplaySectionBox(title: "therapists", lightAccentColor: .accentColor, darkAccentColor: .accentColor) {
                    if editingSection == .therapists {
                        TherapistEditorList(
                            therapists: $globals.practiceInfo.therapists,
                            nextId: { UUID() },
                            onModified: { isModified = true },
                            onDone: { saveAndReset() },
                            onCancel: { editingSection = nil }
                        )
                    } else {
                        TherapistListReadonlyView(therapists: globals.practiceInfo.therapists)
                            .contextMenu {
                                Button {
                                    authenticateAndEdit(.therapists)
                                } label: {
                                    Label(NSLocalizedString("edit", comment: "Edit"), systemImage: "pencil")
                                }
                            }
                            .foregroundColor(.edit)
                            .onLongPressGesture {
                                authenticateAndEdit(.therapists)
                            }
                    }
                }

                // MARK: - Services
                DisplaySectionBox(title: "services", lightAccentColor: .accentColor, darkAccentColor: .accentColor) {
                    if editingSection == .services {
                        ServiceEditorList(
                            services: $globals.practiceInfo.services,
                            onModified: { isModified = true },
                            onDone: { saveAndReset() },
                            onCancel: { editingSection = nil }
                        )
                    } else {
                        ServicesReadonlyView(services: globals.practiceInfo.services)
                            .contextMenu {
                                Button {
                                    authenticateAndEdit(.services)
                                } label: {
                                    Label(NSLocalizedString("edit", comment: "Edit"), systemImage: "pencil")
                                }
                            }
                            .foregroundColor(.edit)
                            .onLongPressGesture {
                                authenticateAndEdit(.services)
                            }
                    }
                }
            }
            .padding()
        }
        .navigationTitle(NSLocalizedString("practiceInfo", comment: "Practice Info"))
        .alert(NSLocalizedString("validationFailed", comment: ""), isPresented: $showValidationAlert) {
            Button(NSLocalizedString("okButton", comment: "Ok button"), role: .cancel) {}
        }
        .foregroundColor(.ok)
    }

    // MARK: - Authentifizierung
    private func authenticateAndEdit(_ section: EditingSection) {
        let context = LAContext()
        var error: NSError?

        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: NSLocalizedString("editPracticeInfoReason", comment: "Edit practice info")
            ) { success, _ in
                if success {
                    DispatchQueue.main.async {
                        editingSection = section
                    }
                }
            }
        } else {
                showErrorAlert(errorMessage: String(
                    format: NSLocalizedString("errorAuthentification", comment: "Authentication error")
                ))
        }
    }

    // MARK: - Speicherung
    private func savePracticeInfo() {
        let url = AppGlobals.shared.parametersURL.appendingPathComponent(ParameterFile.practiceInfo.rawValue)

        // Wrapper erstellen: Version NICHT vergessen!
        let file = PracticeInfoFile(version: 1, items: [globals.practiceInfo])

        do {
            try savePracticeInfoFile(file, to: url)
            AppGlobals.shared.treatmentServices = globals.practiceInfo.services
            AppGlobals.shared.specialties = globals.specialties
            AppGlobals.shared.insuranceList = globals.insuranceList
            AppGlobals.shared.therapistList = globals.therapistList
            
            isModified = false
        } catch {
            showErrorAlert(errorMessage: "Fehler beim Speichern: \(error.localizedDescription)")
        }
    }

    private func saveAndReset() {
        savePracticeInfo()
        editingSection = nil
        GlobalToast.show(NSLocalizedString("saved", comment: "Saved"))
    }
}
