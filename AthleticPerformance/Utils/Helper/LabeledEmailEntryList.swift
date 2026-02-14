//
//  LabeledTextEntryList.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 28.03.25.
//

import SwiftUI

struct LabeledEmailEntryList: View {
    @Binding var entries: [LabeledValue<String>]
    let titleKey: String
    let labelOptions: [String]

    var body: some View {
        Section(header: Text(NSLocalizedString(titleKey, comment: ""))) {
            ForEach(Array(entries.enumerated()), id: \.offset) { index, entry in
                HStack(alignment: .center, spacing: 8) {
                    // 🗑️ Löschen
                    Button(role: .destructive) {
                        if entries.indices.contains(index) {
                            entries.remove(at: index)
                        }
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .foregroundColor(.deleteButton)
                    }

                    // 🏷️ Label
                    if !labelOptions.isEmpty {
                        Picker("", selection: Binding(
                            get: {
                                entries.indices.contains(index)
                                    ? entries[index].label
                                    : labelOptions.first ?? "default"
                            },
                            set: { newValue in
                                if entries.indices.contains(index) {
                                    entries[index].label = newValue
                                }
                            }
                        )) {
                            ForEach(labelOptions, id: \.self) { label in
                                Text(NSLocalizedString(label, comment: "")).tag(label)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(.secondary)
                        .fixedSize() // Verhindert seltsame Layoutgrößen bei NaN
                    }

                    // ✏️ Eingabe
                    TextField(NSLocalizedString("value", comment: ""), text: Binding(
                        get: {
                            entries.indices.contains(index) ? entries[index].value : ""
                        },
                        set: { newValue in
                            if entries.indices.contains(index) {
                                entries[index].value = newValue
                            }
                        }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.emailAddress)
                    .submitLabel(.done)
                }
            }

            // ➕ Neuer Eintrag
            Button {
                let nextLabel = labelOptions.indices.contains(entries.count % labelOptions.count)
                    ? labelOptions[entries.count % labelOptions.count]
                    : labelOptions.first ?? "default"
                entries.append(LabeledValue(label: nextLabel, value: ""))
            } label: {
                Label(NSLocalizedString("add_\(titleKey)", comment: ""), systemImage: "plus.circle.fill")
                    .foregroundColor(.addButton)
            }
            .padding(.top, 6)
        }
    }
}
