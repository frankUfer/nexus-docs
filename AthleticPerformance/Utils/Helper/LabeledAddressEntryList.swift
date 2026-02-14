//
//  LabeledAddressEntryList.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 28.03.25.
//

import SwiftUI

struct LabeledAddressEntryList: View {
    @Binding var entries: [LabeledValue<Address>]
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
                        
                        Spacer()
                        
                        BoolSwitchWoSpacer(
                            value: $entries[index].value.isBillingAddress,
                            label: NSLocalizedString("isBillingAddress", comment: "Is billing address")
                        )
                    }

                    TextField(NSLocalizedString("street", comment: ""), text: $entries[index].value.street)
                        .textFieldStyle(.roundedBorder)
                        .submitLabel(.next)

                    HStack {
                        TextField(NSLocalizedString("postalCode", comment: ""), text: $entries[index].value.postalCode)
                            .frame(width: 80)
                            .textFieldStyle(.roundedBorder)
                            .submitLabel(.next)

                        TextField(NSLocalizedString("city", comment: ""), text: $entries[index].value.city)
                            .textFieldStyle(.roundedBorder)
                            .submitLabel(.next)
                    }

                    TextField(NSLocalizedString("country", comment: ""), text: $entries[index].value.country)
                        .textFieldStyle(.roundedBorder)
                        .submitLabel(.done)
                }
            }

            Button {
                let newAddress = Address.empty()
                let nextLabel = labelOptions[entries.count % labelOptions.count]
                entries.append(LabeledValue(label: nextLabel, value: newAddress))
            } label: {
                Label(NSLocalizedString("addAddress", comment: ""), systemImage: "plus.circle.fill")
                    .foregroundColor(.addButton)
            }
            .padding(.top, 6)
        }
    }
}
