//
//  RecipeImportConfirmationView.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 29.04.25.
//

import SwiftUI

struct RecipeImportConfirmationView: View {
    let diagnosis: DiagnosisInfo?
    let remedies: [Remedy]
    let doctor: DiagnosisSource?
    let matchPercentage: Int
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Text(NSLocalizedString("proofPrescription", comment: "Proof of precscription"))
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)
                    .padding(.top, 12)

                VStack(alignment: .leading, spacing: 24) {
                    Text("✅ \(NSLocalizedString("equality", comment: "Equality")): \(matchPercentage)%")

                    if let diagnosis = diagnosis {
                        Text("🩺 \(NSLocalizedString("diagnosis", comment: "Diagnosis")): \(diagnosis.text)")
                        if let date = diagnosis.diagnosisDate {
                            Text("📅 \(NSLocalizedString("diagnosisDate", comment: "Diagnosis date")): \(formatted(date))")
                        }
                    }

                    if !remedies.isEmpty {
                        Text("👐 \(NSLocalizedString("remedy", comment: "Remedy")):")
                            .padding(.top, 16)

                        ForEach(remedies, id: \.name) { remedy in
                            Text("       – \(remedy.quantity) x \(remedy.name)")
                                .padding(.top, -8)
                        }
                    }

                    if let doctor = doctor {
                        Text("👨‍⚕️ \(NSLocalizedString("doctor", comment: "Doctor")): \(doctor.originName)")
                            .padding(.top, 16)

                        if !doctor.phoneNumber.isEmpty {
                            Text("📞 \(doctor.phoneNumber)")
                        }
                        if !doctor.street.isEmpty {
                            Text("🏥 \(doctor.street), \(doctor.postalCode) \(doctor.city)")
                        }
                        if let specialty = doctor.specialty {
                            Text("🩻 \(NSLocalizedString("specialty", comment: "Specialty")): \(specialty.localizedName())")
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)

                Spacer()

                HStack {
                    Button(NSLocalizedString("cancel", comment: "Cancel")) {
                        onCancel()
                    }
                    .padding()
                    .background(Color.cancel.opacity(0.2))
                    .foregroundColor(.cancel)
                    .cornerRadius(10)

                    Spacer()

                    Button(NSLocalizedString("confirm", comment: "Confirm")) {
                        onConfirm()
                    }
                    .padding()
                    .background(Color.addButton)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    private func formatted(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateFormat = "dd.MM.yyyy"
        return formatter.string(from: date)
    }
}
