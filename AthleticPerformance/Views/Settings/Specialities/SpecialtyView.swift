//
//  SpecialtyView.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 18.04.25.
//

import SwiftUI
import LocalAuthentication

// MARK: - SpecialtyView
struct SpecialtyView: View {
    @State private var isModified = false
    @State private var editing = false
    @State private var specialtyList: [Specialty] = loadParameterList(from: "specialties")

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                DisplaySectionBox(title: "specialties", lightAccentColor: .accentColor, darkAccentColor: .accentColor) {
                    if editing {
                        SpecialtyEditorList(
                            specialties: $specialtyList,
                            onModified: { isModified = true },
                            onDone: { saveAndReset() },
                            onCancel: { editing = false }
                        )
                    } else {
                        SpecialtyReadonlyView(specialties: specialtyList)
                            .contextMenu {
                                Button {
                                    authenticateAndEdit()
                                } label: {
                                    Label(NSLocalizedString("edit", comment: "Edit"), systemImage: "pencil")
                                }
                            }
                            .foregroundColor(.edit)
                            .onLongPressGesture {
                                authenticateAndEdit()
                            }
                    }
                }
            }
            .padding()
        }
        .navigationTitle(NSLocalizedString("specialties", comment: "Specialties"))
    }

    private func saveAndReset() {
        do {
            try saveParameterList(specialtyList, fileName: "specialties")
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
                localizedReason: NSLocalizedString("editSpecialtiesReason", comment: "Edit specialties")
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
