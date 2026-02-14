//
//  AddressSelectionView.swift
//  AthleticPerformance
//
//  Created by Frank Ufer on 03.07.25.
//

import SwiftUI

struct AddressSelectionView: View {
    let patientAddresses: [Address]
    let onSelect: (Address) -> Void
    let onDelete: (PublicAddress) -> Void
    let onAddNew: () -> Void
    
    @ObservedObject private var globals = AppGlobals.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var isPatientAddressesExpanded = true
    @State private var expandedCategories: Set<String> = []
    @State private var showDeleteConfirmation = false
    @State private var publicAddressToDelete: PublicAddress? = nil
    
    private var groupedPublicAddresses: [String: [PublicAddress]] {
        Dictionary(grouping: globals.publicAddresses, by: { $0.label })
    }
    
    var body: some View {
        List {
            // ✅ Patienten-Adressen Disclosure
            if !patientAddresses.isEmpty {
                DisclosureGroup(
                    isExpanded: $isPatientAddressesExpanded,
                    content: {
                        ForEach(patientAddresses.sorted(by: { $0.city < $1.city }), id: \.self) { address in
                            Button(action: {
                                onSelect(address)
                                dismiss()
                            }) {
                                Text(address.fullDescription)
                                    .foregroundColor(.secondary)
                            }
                        }
                    },
                    label: {
                        Text(NSLocalizedString("patientAddresses", comment: "Patient Addresses"))
                            .foregroundColor(.primary)
                            .font(.headline)
                    }
                )
            }
            
            // ✅ Öffentliche Adressen Disclosure pro Kategorie
            ForEach(groupedPublicAddresses.keys.sorted(), id: \.self) { category in
                DisclosureGroup(
                    isExpanded: Binding(
                        get: { expandedCategories.contains(category) },
                        set: { isExpanded in
                            if isExpanded {
                                expandedCategories.insert(category)
                            } else {
                                expandedCategories.remove(category)
                            }
                        }
                    )
                ) {
                    ForEach(groupedPublicAddresses[category] ?? []) { publicAddr in
                        HStack {
                            // 1️⃣ Selektionsbereich nur links
                            Text("\(publicAddr.name) — \(publicAddr.address.fullDescription)")
                                .foregroundColor(.secondary)
                                .onTapGesture {
                                    onSelect(publicAddr.address)
                                    dismiss()
                                }
                                .contentShape(Rectangle())

                            Spacer()

                            // 2️⃣ Delete-Button rechts klar separat
                            Button(role: .destructive) {
                                publicAddressToDelete = publicAddr
                                showDeleteConfirmation = true
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                } label: {
                    Text(category)
                        .foregroundColor(.primary)
                        .font(.headline)
                }
            }
            
            // ✅ Neue Adresse hinzufügen
            Section {
                HStack {
                    Spacer()
                    Button(action: {
                        dismiss()
                        onAddNew()
                    }) {
                        Label(NSLocalizedString("addNewAddress", comment: "Add new address"), systemImage: "plus")
                    }
                    Spacer()
                }
            }
            .navigationTitle(NSLocalizedString("selectAddress", comment: "Select Address"))
            .listStyle(.insetGrouped)
        }
        .alert(isPresented: $showDeleteConfirmation) {
            Alert(
                title: Text("Löschen?"),
                message: Text("Wirklich löschen?"),
                primaryButton: .destructive(Text("Löschen")) {
                    if let toDelete = publicAddressToDelete {
                        onDelete(toDelete)    // <- übergebe an Parent!
                    }
                    publicAddressToDelete = nil
                },
                secondaryButton: .cancel {
                    publicAddressToDelete = nil
                }
            )
        }
    }
}
