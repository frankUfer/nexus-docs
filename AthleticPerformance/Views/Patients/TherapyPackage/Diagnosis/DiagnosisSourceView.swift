//
//  DiagnosisSourceView.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 23.04.25.
//

import SwiftUI

struct DiagnosisSourceView: View {
    @Binding var source: DiagnosisSource
    var onChange: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(
                NSLocalizedString(
                    "diagnosisSource",
                    comment: "Diagnosis source"
                )
            )
            .font(.headline)

            TextField(
                NSLocalizedString("institution", comment: "Institution"),
                text: $source.originName
            )
            .textFieldStyle(.roundedBorder)
            .onChange(of: source.originName) { onChange?() }

            // 🔹 Straße, PLZ, Ort nebeneinander
            HStack(spacing: 8) {
                TextField(
                    NSLocalizedString("street", comment: ""),
                    text: $source.street
                )
                .textFieldStyle(.roundedBorder)
                .onChange(of: source.street) { onChange?() }

                TextField(
                    NSLocalizedString("postalCode", comment: ""),
                    text: $source.postalCode
                )
                .textFieldStyle(.roundedBorder)
                .frame(width: 80)
                .onChange(of: source.postalCode) { onChange?() }

                TextField(
                    NSLocalizedString("city", comment: ""),
                    text: $source.city
                )
                .textFieldStyle(.roundedBorder)
                .onChange(of: source.city) { onChange?() }

                TextField(
                    NSLocalizedString("phone", comment: ""),
                    text: $source.phoneNumber
                )
                .textFieldStyle(.roundedBorder)
                .onChange(of: source.phoneNumber) { onChange?() }

                if !source.phoneNumber.trimmingCharacters(
                    in: .whitespacesAndNewlines
                ).isEmpty {
                    Button(action: {
                        let digits = source.phoneNumber
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                            .filter("0123456789+".contains)

                        if let url = URL(string: "tel://\(digits)"),
                            UIApplication.shared.canOpenURL(url)
                        {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        Image(systemName: "phone.fill")
                            .foregroundColor(.icon)
                            .padding(.trailing, 4)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }

            // 🔹 Picker mit Label
            HStack {
                Text(
                    NSLocalizedString(
                        "specialtyName",
                        comment: "Specialty name"
                    )
                )
                .frame(minWidth: 120, alignment: .leading)

                Picker(
                    "",
                    selection: Binding<String>(
                        get: { source.specialty?.id ?? "" },
                        set: { newId in
                            source.specialty = AppGlobals.shared.specialties
                                .first(where: { $0.id == newId })
                            onChange?()
                        }
                    )
                ) {
                    ForEach(AppGlobals.shared.specialties, id: \.id) {
                        specialty in
                        Text(specialty.localizedName()).tag(specialty.id)
                    }
                }
                .pickerStyle(.menu)
                .tint(.secondary)

                Spacer()
            }

            DatePicker(
                NSLocalizedString("createdOn", comment: "Created on"),
                selection: $source.createdAt,
                displayedComponents: [.date]
            )
            .onChange(of: source.createdAt) { onChange?() }
        }
    }
}
