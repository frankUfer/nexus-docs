//
//  TherapistEditorList.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 09.04.25.
//

import SwiftUI

struct TherapistEditorList: View {
    @Binding var therapists: [Therapists]
    @State private var therapistsToDelete: Set<UUID> = []
    @State private var pendingDeleteId: UUID? = nil
    @State private var showDeleteConfirmation = false

    let nextId: () -> UUID
    var onModified: () -> Void
    var onDone: () -> Void = {}
    var onCancel: () -> Void = {}

    var body: some View {
        VStack(spacing: 16) {
            ForEach(filteredTherapistIndices(), id: \.self) { index in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Button(role: .destructive) {
                            pendingDeleteId = therapists[index].id
                            showDeleteConfirmation = true
                        } label: {
                            Label(NSLocalizedString("deleteTherapist", comment: ""), systemImage: "minus.circle.fill")
                                .foregroundColor(.deleteButton)
                        }

                        Spacer()
                        
                        BoolSwitch(
                            value: $therapists[index].isActive,
                            label: NSLocalizedString("active", comment: "Aktiv")
                        )
                    }

                    HStack(spacing: 12) {
                        TextField(NSLocalizedString("firstname", comment: ""), text: $therapists[index].firstname)
                            .textFieldStyle(.roundedBorder)
                        TextField(NSLocalizedString("lastname", comment: ""), text: $therapists[index].lastname)
                            .textFieldStyle(.roundedBorder)
                    }

                    TextField(NSLocalizedString("email", comment: ""), text: $therapists[index].email)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.emailAddress)
                }
                .padding(.vertical, 4)
            }

            Button {
                let newID = nextId()
                therapists.append(
                    Therapists(id: newID, firstname: "", lastname: "", email: "", isActive: true)
                )
                onModified()
            } label: {
                Label(NSLocalizedString("addTherapist", comment: "Add therapist"), systemImage: "plus.circle.fill")
                    .foregroundColor(.addButton)
            }

            HStack {
                Button(role: .cancel, action: {
                    therapistsToDelete.removeAll()
                    pendingDeleteId = nil
                    onCancel()
                }) {
                    Label(NSLocalizedString("cancel", comment: "Cancel"), systemImage: "xmark")
                        .foregroundColor(.cancel)
                }

                Spacer()

                Button(action: {
                    therapists.removeAll { therapistsToDelete.contains($0.id) }
                    therapistsToDelete.removeAll()
                    onModified()
                    onDone()
                }) {
                    Label(NSLocalizedString("save", comment: "Save"), systemImage: "checkmark")
                }
                .foregroundColor(.done)
                .tint(.accentColor)
            }
            .padding(.top, 12)
        }
        .alert(isPresented: $showDeleteConfirmation) {
            Alert(
                title: Text(NSLocalizedString("confirmDelete", comment: "Confirm deletion")),
                message: Text(NSLocalizedString("reallyDeleteTherapist", comment: "Do you really want to delete this therapist?")),
                primaryButton: .destructive(Text(NSLocalizedString("delete", comment: "Delete"))) {
                    if let id = pendingDeleteId {
                        if canDeleteTherapist(id: id) {
                            therapistsToDelete.insert(id)
                            onModified()
                        }
                        pendingDeleteId = nil
                    }
                },
                secondaryButton: .cancel {
                    pendingDeleteId = nil
                }
            )
        }
    }

    // MARK: - Helpers

    private func filteredTherapistIndices() -> [Int] {
        therapists.indices.filter { !therapistsToDelete.contains(therapists[$0].id) }
    }

    private func canDeleteTherapist(id: UUID) -> Bool {
        // TODO: Später echte Validierung
        return true
    }
}
