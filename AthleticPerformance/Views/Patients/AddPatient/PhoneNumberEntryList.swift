//
//  PhoneNumberEntryList.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 07.04.25.
//

import SwiftUI

struct PhoneNumberEntryList: View {
    @Binding var entries: [LabeledValue<String>]
    let labelOptions: [String]

    var body: some View {
        Section(header: Text(NSLocalizedString("phoneNumbers", comment: ""))) {
            ForEach(entries.indices, id: \.self) { index in
                Section {
                    HStack(spacing: 8) {
                        Button(role: .destructive) {
                            entries.remove(at: index)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                            .foregroundColor(.deleteButton)
                        }

                        Picker("", selection: $entries[index].label) {
                            ForEach(labelOptions, id: \.self) { label in
                                Text(NSLocalizedString(label, comment: "")).tag(label)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(.secondary)
                        .frame(width: 140)

                        TextField(NSLocalizedString("phone", comment: "Phone"), text: $entries[index].value)
                            .keyboardType(.phonePad)
                            .textContentType(.telephoneNumber)
                            .textFieldStyle(.roundedBorder)
                            .submitLabel(.done)
                            .onChange(of: entries[index].value) { oldValue, newValue in
                                entries[index].value = PhoneNumberHelper.shared.format(newValue, region: "DE")
                            }
                    }
                }
            }

            Button {
                let nextLabel = labelOptions[entries.count % labelOptions.count]
                entries.append(LabeledValue(label: nextLabel, value: ""))
            } label: {
                Label(NSLocalizedString("add_phoneNumbers", comment: ""), systemImage: "plus.circle.fill")
                    .foregroundColor(.addButton)
            }
            .padding(.top, 6)
        }
    }
}
