//
//  InsuranceView.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 09.04.25.
//

import SwiftUI
import LocalAuthentication

struct InsuranceView: View {
    @State private var isModified = false
    @State private var editing = false
    @State private var insuranceList: [InsuranceCompany] = loadParameterList(from: "insurances")

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                DisplaySectionBox(title: "insurances", lightAccentColor: .accentColor, darkAccentColor: .accentColor) {
                    if editing {
                        InsuranceEditorList(
                            insurances: $insuranceList,
                            onModified: { isModified = true },
                            onDone: { saveAndReset() },
                            onCancel: { editing = false }
                        )
                    } else {
                        InsuranceReadonlyView(insurances: insuranceList)
                            .contextMenu {
                                Button {
                                    authenticateAndEdit()
                                } label: {
                                    Label(NSLocalizedString("edit", comment: "Edit"), systemImage: "pencil")
                                }
                            }
                            .onLongPressGesture {
                                authenticateAndEdit()
                            }
                    }
                }
            }
            .padding()
        }
        .navigationTitle(NSLocalizedString("insurances", comment: "Insurances"))
    }

    // MARK: - Speicherung
    private func saveAndReset() {
        do {
            try saveParameterList(insuranceList, fileName: "insurances")
            isModified = false
            editing = false
            GlobalToast.show(NSLocalizedString("saved", comment: "Saved"))
        } catch {
            showErrorAlert(errorMessage: NSLocalizedString("errorSaving", comment: "Error saving file"))
        }
    }

    private func authenticateAndEdit() {
        let context = LAContext()
        var error: NSError?
        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            context.evaluatePolicy(.deviceOwnerAuthentication,
                localizedReason: NSLocalizedString("editInsurancesReason", comment: "Edit insurances")
            ) { success, _ in
                if success {
                    DispatchQueue.main.async {
                        editing = true
                    }
                }
            }
        } else {
            showErrorAlert(errorMessage: NSLocalizedString("errorAuthentification", comment: "Authentication failed"))
        }
    }
}
