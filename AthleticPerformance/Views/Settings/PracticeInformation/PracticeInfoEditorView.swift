//
//  PracticeInfoEditorView.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 09.04.25.
//

import SwiftUI

struct PracticeInfoEditorView: View {
    @Binding var practice: PracticeInfo
    var onChange: () -> Void = {}
    var onDone: () -> Void = {}
    var onCancel: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            
            Text(NSLocalizedString("practiceAddress", comment: "Practice address"))
            
            LabeledTextField(label: "name", icon: "building.2", iconColor: .icon, text: $practice.name)
                .onChange(of: practice.name) { onChange() }

            LabeledTextField(label: "street", icon: "house", iconColor: .icon, text: $practice.address.street)
                .onChange(of: practice.address.street) { onChange() }

            HStack(spacing: 12) {
                LabeledTextField(label: "postalCode", icon: "number", iconColor: .icon, text: $practice.address.postalCode)
                    .onChange(of: practice.address.postalCode) { onChange() }

                LabeledTextField(label: "city", icon: "map", iconColor: .icon, text: $practice.address.city)
                    .onChange(of: practice.address.city) { onChange() }
            }

            LabeledTextField(label: "phone", icon: "phone", iconColor: .icon, keyboardType: .phonePad, text: $practice.phone)
                .onChange(of: practice.phone) { onChange() }

            LabeledTextField(label: "email", icon: "envelope", iconColor: .icon, keyboardType: .emailAddress, text: $practice.email)
                .onChange(of: practice.email) { onChange() }

            LabeledTextField(label: "website", icon: "globe", iconColor: .icon, keyboardType: .URL, text: $practice.website)
                .onChange(of: practice.website) { onChange() }
            
            LabeledTextField(label: "taxNumber", icon: "number", iconColor: .icon, text: $practice.taxNumber)
                .onChange(of: practice.taxNumber) { onChange() }

            LabeledTextField(label: "bank", icon: "banknote", iconColor: .icon, text: $practice.bank)
                .onChange(of: practice.bank) { onChange() }

            LabeledTextField(label: "iban", icon: "creditcard", iconColor: .icon, text: $practice.iban)
                .onChange(of: practice.iban) { onChange() }

            LabeledTextField(label: "bic", icon: "creditcard.fill", iconColor: .icon, text: $practice.bic)
                .onChange(of: practice.bic) { onChange() }
            
            Spacer()
            
            Text(NSLocalizedString("startAddress", comment: "Start address"))
            
            LabeledTextField(label: "street", icon: "house", iconColor: .icon, text: $practice.startAddress.street)
                .onChange(of: practice.startAddress.street) { onChange() }

            HStack(spacing: 12) {
                LabeledTextField(label: "postalCode", icon: "number", iconColor: .icon, text: $practice.startAddress.postalCode)
                    .onChange(of: practice.startAddress.postalCode) { onChange() }

                LabeledTextField(label: "city", icon: "map", iconColor: .icon, text: $practice.startAddress.city)
                    .onChange(of: practice.startAddress.city) { onChange() }
            }

            HStack {
                Button(role: .cancel, action: onCancel) {
                    Label(NSLocalizedString("cancel", comment: "Cancel"), systemImage: "xmark")
                }
                .foregroundColor(.cancel)

                Spacer()

                Button(action: onDone) {
                    Label(NSLocalizedString("save", comment: "Save"), systemImage: "checkmark")
                }
                .foregroundColor(.done)
                .tint(.accentColor)
            }
            .padding(.top, 12)
        }
    }
}
