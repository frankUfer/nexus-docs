//
//  TissueStatusEntryList.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 09.05.25.
//

import SwiftUI

struct TissueStatusEntryList: View {
    @Binding var entries: [TissueStatusEntry]
    let titleKey: String
    let availableTissues: [Tissues]
    let availableTissueStates: [TissueStates]
    let availablePainQualities: [PainQualities]
    let onEdited: () -> Void
    var isEditable: Bool = true

    @State private var showDeleteAlert = false
    @State private var idToDelete: UUID?

    var body: some View {
        DisplaySectionBox(
            title: titleKey,
            lightAccentColor: .accentColor,
            darkAccentColor: .accentColor
        ) {
            VStack(spacing: 16) {

                ForEach(Array(entries.indices), id: \.self) { idx in
                    let isLast = (idx == entries.count - 1)
                    let entryBinding = Binding(
                        get: { entries[idx] },
                        set: { entries[idx] = $0 }
                    )

                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Picker("", selection: entryBinding.side) {
                                ForEach(BodySides.allCases, id: \.self) {
                                    side in
                                    Text(side.localized).tag(side)
                                }
                            }
                            .pickerStyle(.segmented)
                            .frame(maxWidth: 250)
                            .onChange(of: entryBinding.side.wrappedValue) { _, _ in
                                onEdited()
                            }

                            Spacer()

                            if isEditable {
                                BoolSwitchWoSpacer(
                                    value: entryBinding.reevaluation,
                                    label: NSLocalizedString(
                                        "reevaluation",
                                        comment: "Re-evaluation"
                                    )
                                )
                            } else {
                                BoolIndicatorWoSpacer(
                                    value: entryBinding.reevaluation
                                        .wrappedValue,
                                    label: NSLocalizedString(
                                        "reevaluation",
                                        comment: "Re-evaluation"
                                    )
                                )
                            }
                            
                            if !entryBinding.reevaluation.wrappedValue {
                                
                                Spacer()
                                
                                Button(role: .destructive) {
                                    let currentID = entryBinding.wrappedValue.id
                                    idToDelete = currentID
                                    showDeleteAlert = true
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundColor(.deleteButton)
                                }
                            }
                        }

                        TissueStatusEntryRow(
                            entry: entryBinding,
                            availableTissues: availableTissues,
                            availableTissueStates: availableTissueStates,
                            availablePainQualities: availablePainQualities,
                            onEdited: onEdited
                        )

                        if !isLast { Divider() }
                    }
                }

                Button {
                    let newEntry = TissueStatusEntry(
                        id: UUID(),
                        tissue: availableTissues.first
                            ?? Tissues(
                                id: UUID(),
                                de: "Unbekannt",
                                en: "Unknown"
                            ),
                        side: .left,
                        tissueStates: nil,
                        painQuality: nil,
                        painLevel: nil,
                        notes: nil,
                        timestamp: Date()
                    )
                    entries.append(newEntry)
                    onEdited()
                } label: {
                    Label(
                        NSLocalizedString(
                            "addTissueEntry",
                            comment: "Add tissue entry"
                        ),
                        systemImage: "plus.circle.fill"
                    )
                    .foregroundColor(.addButton)
                }
                .padding(.top, 6)
            }
        }
        .alert(isPresented: $showDeleteAlert) {
            Alert(
                title: Text(NSLocalizedString("confirmDelete", comment: "")),
                message: Text(
                    NSLocalizedString("reallyDeleteTissueEntry", comment: "")
                ),
                primaryButton: .destructive(
                    Text(NSLocalizedString("delete", comment: "Delete"))
                ) {
                    if let id = idToDelete,
                        let idx = entries.firstIndex(where: { $0.id == id })
                    {
                        _ = withAnimation(nil) {
                            entries.remove(at: idx)
                        }
                        onEdited()
                    }
                    idToDelete = nil
                },
                secondaryButton: .cancel()
            )
        }
    }
}
