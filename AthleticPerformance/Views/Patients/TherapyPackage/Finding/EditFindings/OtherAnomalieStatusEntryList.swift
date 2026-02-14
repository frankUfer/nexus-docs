//
//  OtherAnomalieStatusEntryList.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 25.05.25.
//

import SwiftUI

struct OtherAnomalieStatusEntryList: View {
    @Binding var entries: [OtherAnomalieStatusEntry]
    let titleKey: String
    let availableBodyRegions: [BodyRegionSelectionGroup]
    let availablePainQualities: [PainQualities]
    let availablePainStructures: [PainStructures]
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
                            // Body side
                            Picker("", selection: entryBinding.side) {
                                ForEach(BodySides.allCases, id: \.self) { side in
                                    Text(side.localized).tag(side)
                                }
                            }
                            .pickerStyle(.segmented)
                            .frame(maxWidth: 250)
                            .onChange(of: entryBinding.side.wrappedValue) { _, _ in
                                onEdited()
                            }

                            Spacer()

                            // Reevaluation Switch / Indicator
                            if isEditable {
                                BoolSwitchWoSpacer(
                                    value: entryBinding.reevaluation,
                                    label: NSLocalizedString("reevaluation", comment: "Re-evaluation")
                                )
                            } else {
                                BoolIndicatorWoSpacer(
                                    value: entryBinding.reevaluation.wrappedValue,
                                    label: NSLocalizedString("reevaluation", comment: "Re-evaluation")
                                )
                            }

                            // Delete NUR wenn nicht Reevaluation
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
                                .accessibilityLabel(
                                    Text(NSLocalizedString("delete", comment: "Delete"))
                                )
                            }
                        }
                        .onChange(of: entryBinding.reevaluation.wrappedValue) { _, _ in
                            onEdited()
                        }

                        // === Detailblock ohne Header-Logik ===
                        OtherAnomalieStatusEntryRow(
                            entry: entryBinding,
                            availableBodyRegions: availableBodyRegions.map(\.region),
                            availablePainStructures: availablePainStructures,
                            availablePainQualities: availablePainQualities,
                            onEdited: onEdited,
                            isEditable: isEditable
                        )

                        if !isLast { Divider() }
                    }
                }

                // Add-Button
                Button {
                    entries.append(
                        OtherAnomalieStatusEntry(
                            id: UUID(),
                            anomaly: "",
                            bodyRegion: nil,
                            bodyPart: nil,
                            side: .left,
                            anomalyPains: nil,
                            reevaluation: false,
                            timestamp: Date()
                        )
                    )
                    onEdited()
                } label: {
                    Label(
                        NSLocalizedString("addAnomalyEntry", comment: "Add anomaly entry"),
                        systemImage: "plus.circle.fill"
                    )
                    .foregroundColor(.addButton)
                }
                .padding(.top, 6)
            }
        }
        .alert(isPresented: $showDeleteAlert) {
            Alert(
                title: Text(
                    NSLocalizedString("confirmDelete", comment: "Confirm delete")
                ),
                message: Text(
                    NSLocalizedString("reallyDeleteAnomalyEntry", comment: "Really delete anomaly entry")
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
