//
//  InsuranceEditorList.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 09.04.25.
//

import SwiftUI

struct InsuranceEditorList: View {
    @Binding var insurances: [InsuranceCompany]
    @State private var insuranceToDelete: Int? = nil
    @State private var showDeleteConfirmation = false
    @State private var duplicateIndices: Set<Int> = []
    @State private var showDuplicateAlert = false

    var onModified: () -> Void = {}
    var onDone: () -> Void = {}
    var onCancel: () -> Void = {}

    var body: some View {
        VStack(spacing: 16) {
            ForEach(insurances.indices, id: \.self) { index in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        TextField(NSLocalizedString("insuranceName", comment: "Insurance name"), text: $insurances[index].name)
                            .textFieldStyle(.roundedBorder)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(duplicateIndices.contains(index) ? Color.negativeCheck : Color.clear, lineWidth: 2)
                            )
                            .onChange(of: insurances[index].name) { _, _ in
                                validateDuplicates()
                                onModified()
                            }

                        Spacer()

                        Button(role: .destructive) {
                            insuranceToDelete = index
                            showDeleteConfirmation = true
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundColor(.deleteButton)
                        }
                    }
                    Divider()
                    .background(Color.divider.opacity(0.5))
                }
            }

            // Hinzufügen
            Button {
                let existingIDs = Set(insurances.map(\.id))
                let newId = generateID(from: "", existingIDs: existingIDs)
                insurances.append(InsuranceCompany(id: newId, name: ""))
                validateDuplicates()
                onModified()
            } label: {
                Label(NSLocalizedString("addInsurance", comment: ""), systemImage: "plus.circle.fill")
                    .foregroundColor(.addButton)
            }

            // Buttons unten
            HStack {
                Button(role: .cancel, action: onCancel) {
                    Label(NSLocalizedString("cancel", comment: "Cancel"), systemImage: "xmark")
                }
                .foregroundColor(.cancel)

                Spacer()

                Button(action: {
                    if duplicateIndices.isEmpty {
                        sortAndSave()
                        onDone()
                    } else {
                        showDuplicateAlert = true
                    }
                }) {
                    Label(NSLocalizedString("save", comment: "Save"), systemImage: "checkmark")
                }
                .tint(.accentColor)
            }
            .padding(.top, 12)

            // Bestätigungs-Dialog
            .alert(isPresented: $showDeleteConfirmation) {
                Alert(
                    title: Text(NSLocalizedString("confirmDelete", comment: "Confirm deletion")),
                    message: Text(NSLocalizedString("reallyDeleteInsurance", comment: "Do you really want to delete this insurance?")),
                    primaryButton: .destructive(Text(NSLocalizedString("delete", comment: "Delete"))) {
                        if let index = insuranceToDelete, insurances.indices.contains(index) {
                            insurances.remove(at: index)
                            validateDuplicates()
                            onModified()
                        }
                        insuranceToDelete = nil
                    },
                    secondaryButton: .cancel {
                        insuranceToDelete = nil
                    }
                )
            }

            // Dubletten-Alert beim Speichern
            .alert(NSLocalizedString("duplicateInsurance", comment: "Duplicate insurance"), isPresented: $showDuplicateAlert) {
                Button(NSLocalizedString("okButton", comment: "Ok button"), role: .cancel) { }
            }
        }
    }

    private func validateDuplicates() {
        var nameCounts: [String: [Int]] = [:]

        for (index, insurance) in insurances.enumerated() {
            let key = insurance.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if !key.isEmpty {
                nameCounts[key, default: []].append(index)
            }
        }

        duplicateIndices = Set(nameCounts.values.filter { $0.count > 1 }.flatMap { $0 })
    }

    // MARK: - Speichern mit Sortierung
    private func sortAndSave() {
        insurances.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        do {
            try saveParameterList(insurances, fileName: "insurances")
        } catch {
            showErrorAlert(errorMessage: NSLocalizedString("errorSavingInsurances", comment: "Error saving insurances"))
        }
    }
}

