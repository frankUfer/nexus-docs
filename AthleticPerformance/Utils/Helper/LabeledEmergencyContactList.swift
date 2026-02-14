//
//  LabeledEmergencyContactList.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 28.03.25.
//

import SwiftUI

struct LabeledEmergencyContactList: View {
    @Binding var entries: [LabeledValue<EmergencyContact>]
    let titleKey: String
    let labelOptions: [String]

    var body: some View {
        Section(header: Text(NSLocalizedString(titleKey, comment: ""))) {
            ForEach(entries.indices, id: \.self) { index in
                Section {
                    HStack {
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
                        .frame(width: 150)
                    }

                    TextField(NSLocalizedString("firstname", comment: ""), text: $entries[index].value.firstname)
                        .textFieldStyle(.roundedBorder)
                        .submitLabel(.next)

                    TextField(NSLocalizedString("lastname", comment: ""), text: $entries[index].value.lastname)
                        .textFieldStyle(.roundedBorder)
                        .submitLabel(.next)

                    TextField(NSLocalizedString("phone", comment: ""), text: $entries[index].value.phone)
                        .keyboardType(.phonePad)
                        .textFieldStyle(.roundedBorder)
                        .submitLabel(.next)
                        .onChange(of: entries[index].value.phone) { oldValue, newValue in
                            entries[index].value.phone = PhoneNumberHelper.shared.format(newValue, region: "DE")
                        }

                    TextField(NSLocalizedString("email", comment: ""), text: $entries[index].value.email)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.emailAddress)
                        .submitLabel(.done)
                }
            }

            // ➕ Neuer Eintrag
            Button {
                let newContact = EmergencyContact(firstname: "", lastname: "", phone: "", email: "")
                let nextLabel = labelOptions[entries.count % labelOptions.count]
                entries.append(LabeledValue(label: nextLabel, value: newContact))
            } label: {
                Label(NSLocalizedString("addEmergencyContact", comment: ""), systemImage: "plus.circle.fill")
                    .foregroundColor(.addButton)
            }
            .padding(.top, 6)
        }
    }
}
