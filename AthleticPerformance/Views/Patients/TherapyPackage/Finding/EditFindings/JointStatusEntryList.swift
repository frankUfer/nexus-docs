//
//  JointStatusEntryList.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 09.05.25.
//

import SwiftUI

struct JointStatusEntryList: View {
    @Binding var entries: [JointStatusEntry]
    let titleKey: String
    let availableJoints: [Joints]
    let availableMovements: [JointMovementPattern]
    let availablePainQualities: [PainQualities]
    let availableEndFeelings: [EndFeelings]
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
                            .onChange(of: entryBinding.side.wrappedValue) {
                                _,
                                _ in onEdited()
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

                        JointStatusEntryRow(
                            entry: entryBinding,
                            availableJoints: availableJoints,
                            availableMovements: availableMovements,
                            availablePainQualities: availablePainQualities,
                            availableEndFeelings: availableEndFeelings,
                            onEdited: onEdited
                        )

                        if !isLast { Divider() }
                    }
                }

                Button {
                    let movement =
                        availableMovements.first
                        ?? JointMovementPattern(
                            id: UUID(),
                            de: "Unbekannt",
                            en: "Unknown",
                            inputType: .slider,
                            unit: "deg",
                            min: 0,
                            max: 100,
                            step: 1,
                            default: .double(0)
                        )
                    let newEntry = JointStatusEntry(
                        id: UUID(),
                        joint: availableJoints.first
                            ?? Joints(
                                id: UUID(),
                                de: "Unbekannt",
                                en: "Unknown"
                            ),
                        side: .left,
                        movement: movement,
                        value: .number(movement.default?.doubleValue ?? 0),
                        painQuality: nil,
                        painLevel: nil,
                        endFeeling: nil,
                        notes: nil,
                        timestamp: Date()
                    )
                    entries.append(newEntry)
                    onEdited()
                } label: {
                    Label(
                        NSLocalizedString(
                            "addJointEntry",
                            comment: "Add joint"
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
                title: Text(
                    NSLocalizedString(
                        "confirmDelete",
                        comment: "Confirm deletion"
                    )
                ),
                message: Text(
                    NSLocalizedString(
                        "reallyDeleteJointEntry",
                        comment: "Really delete joint entry?"
                    )
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
