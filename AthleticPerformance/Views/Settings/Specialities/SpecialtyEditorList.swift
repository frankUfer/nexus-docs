//
//  SpecialtyEditorList.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 18.04.25.
//

import SwiftUI

struct SpecialtyEditorList: View {
    @Binding var specialties: [Specialty]
    @State private var specialtyToDelete: Int? = nil
    @State private var showDeleteConfirmation = false
    @State private var duplicateIndices: Set<Int> = []
    @State private var showDuplicateAlert = false

    var onModified: () -> Void = {}
    var onDone: () -> Void = {}
    var onCancel: () -> Void = {}

    var body: some View {
        VStack(spacing: 16) {
            ForEach(specialties.indices, id: \.self) { index in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        TextField(NSLocalizedString("specialtyName", comment: "Specialty name"),
                                  text: Binding(
                                    get: { specialties[index].name[Locale.current.language.languageCode?.identifier ?? "en"] ?? "" },
                                    set: { newValue in
                                        specialties[index].name[Locale.current.language.languageCode?.identifier ?? "en"] = newValue
                                    }))
                        .textFieldStyle(.roundedBorder)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(duplicateIndices.contains(index) ? Color.red : Color.clear, lineWidth: 2)
                        )
                        .onChange(of: specialties[index].name) { _, _ in
                            validateDuplicates()
                            onModified()
                        }

                        Spacer()

                        Button(role: .destructive) {
                            specialtyToDelete = index
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

            Button {
                let existingIDs = Set(specialties.map(\.id))
                let newId = generateID(from: UUID().uuidString, existingIDs: existingIDs)
                specialties.append(Specialty(id: newId, name: [:], source: "user"))
                validateDuplicates()
                onModified()
            } label: {
                Label(NSLocalizedString("addSpecialty", comment: "Add specialty"), systemImage: "plus.circle.fill")
                    .foregroundColor(.addButton)
            }

            HStack {
                Button(role: .cancel, action: onCancel) {
                    Label(NSLocalizedString("cancel", comment: "Cancel"), systemImage: "xmark")
                }

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
                .foregroundColor(.done)
                .tint(.accentColor)
            }
            .padding(.top, 12)
            .alert(isPresented: $showDeleteConfirmation) {
                Alert(
                    title: Text(NSLocalizedString("confirmDelete", comment: "Confirm deletion")),
                    message: Text(NSLocalizedString("reallyDeleteSpecialty", comment: "Do you really want to delete this specialty?")),
                    primaryButton: .destructive(Text(NSLocalizedString("delete", comment: "Delete"))) {
                        if let index = specialtyToDelete, specialties.indices.contains(index) {
                            specialties.remove(at: index)
                            validateDuplicates()
                            onModified()
                        }
                        specialtyToDelete = nil
                    },
                    secondaryButton: .cancel {
                        specialtyToDelete = nil
                    }
                )
            }
            .alert(NSLocalizedString("duplicateSpecialty", comment: "Duplicate specialty"), isPresented: $showDuplicateAlert) {
                Button(NSLocalizedString("okButton", comment: "Ok button"), role: .cancel) {}
            }
            .foregroundColor(.ok)
        }
    }

    private func validateDuplicates() {
        var nameCounts: [String: [Int]] = [:]
        for (index, specialty) in specialties.enumerated() {
            let key = specialty.localizedName().trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if !key.isEmpty {
                nameCounts[key, default: []].append(index)
            }
        }
        duplicateIndices = Set(nameCounts.values.filter { $0.count > 1 }.flatMap { $0 })
    }

    private func sortAndSave() {
        specialties.sort { $0.localizedName() < $1.localizedName() }
        do {
            try saveParameterList(specialties, fileName: "specialties")
        } catch {
            showErrorAlert(errorMessage: NSLocalizedString("errorSavingSpecialties", comment: "Error saving specialties"))
        }
    }
}

