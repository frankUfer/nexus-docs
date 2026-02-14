//
//  AnamnesisView.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 23.03.25.
//

import SwiftUI

struct AnamnesisView: View {
    let anamnesis: Anamnesis
    var onEdit: (() -> Void)? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // 🔹 Titel und Bearbeiten-Button
                HStack {
                    Text(NSLocalizedString("anamnesis", comment: "Anamnesis"))
                        .font(.title2.bold())
                        .accessibilityAddTraits(.isHeader)
                    Spacer()
                    if let onEdit = onEdit {
                        Button(action: onEdit) {
                            Label(NSLocalizedString("edit", comment: "Edit"), systemImage: "pencil")
                                .labelStyle(.iconOnly)
                                .imageScale(.large)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top)

                AnamnesisLifestyleView(lifestyle: anamnesis.lifestyle)
                AnamnesisMedicalHistoryView(history: anamnesis.medicalHistory)

                DisplaySectionBox(
                    title: "anamnesisRecordedBy",
                    lightAccentColor: .accentColor,
                    darkAccentColor: .accentColor
                ) {
                    LabeledInfoRow(
                        label: NSLocalizedString("therapist", comment: "Therapist"),
                        value: therapistName,
                        icon: "person.fill.checkmark",
                        color: .icon
                    )
                }
            }
            .padding()
        }
    }

    private var therapistName: String {
        AppGlobals.shared.therapistList.first(where: { $0.id == anamnesis.therapistId })?.fullName ?? "–"
    }
}



struct AnamnesisLifestyleView: View {
    let lifestyle: Lifestyle

    var body: some View {
        DisplaySectionBox(
            title: "lifestyle",
            lightAccentColor: .accentColor,
            darkAccentColor: .accentColor
        ) {
            // 🔹 Berufstyp (z. B. körperlich, sitzend, gemischt)
            LabeledInfoRow(
                label: "occupationType",
                value: NSLocalizedString(lifestyle.occupation.type.rawValue, comment: ""),
                icon: "person.2.fill",
                color: .icon
            )

            if !lifestyle.occupation.description.isEmpty {
                LabeledInfoRow(label: "occupation", value: lifestyle.occupation.description, icon: "briefcase.fill", color: .icon)
            }

            if !lifestyle.occupation.profession.isEmpty {
                LabeledInfoRow(label: "profession", value: lifestyle.occupation.profession, icon: "person.text.rectangle", color: .icon)
            }
        
            if lifestyle.measurements.height > 0 {
                LabeledInfoRow(
                    label: "height",
                    value: "\(lifestyle.measurements.height) cm",
                    icon: "ruler",
                    color: .icon
                )
            }

            if lifestyle.measurements.weight > 0 {
                LabeledInfoRow(
                    label: "weight",
                    value: String(format: "%.1f kg", lifestyle.measurements.weight),
                    icon: "scalemass",
                    color: .icon
                )
            }

            // BMI anzeigen, wenn sinnvoll berechnet werden kann
            if lifestyle.measurements.bmi > 0 {
                LabeledInfoRow(
                    label: "bmi",
                    value: String(format: "%.1f (%@)", lifestyle.measurements.bmi, lifestyle.measurements.bmiCategory),
                    icon: "figure.arms.open",
                    color: .icon
                )
            }

            if !lifestyle.activityLevel.rawValue.isEmpty {
                LabeledInfoRow(label: "activityLevel", value: NSLocalizedString(lifestyle.activityLevel.rawValue, comment: ""), icon: "figure.run", color: .icon)
            }

            if lifestyle.sports.active, !lifestyle.sports.types.isEmpty {
                LabeledInfoRow(label: "sports", value: lifestyle.sports.types.joined(separator: ", "), icon: "sportscourt", color: .icon)
            }

            if lifestyle.sports.active, !lifestyle.sports.equipments.isEmpty {
                LabeledInfoRow(label: "equipment", value: lifestyle.sports.equipments.joined(separator: ", "), icon: "dumbbell", color: .icon)
            }
            
            if lifestyle.balanceIssues.hasProblems, !lifestyle.balanceIssues.symptoms.isEmpty {
                LabeledInfoRow(label: "balanceIssues", value: lifestyle.balanceIssues.symptoms.joined(separator: ", "), icon: "figure.stand.line.dotted.figure.stand", color: .icon)
            }

            LabeledInfoRow(label: "smoking", value: NSLocalizedString(lifestyle.smoking.status.rawValue, comment: ""), icon: "smoke", color: .icon)

            if lifestyle.smoking.status == .current, lifestyle.smoking.quantityPerDay > 0 {
                LabeledInfoRow(label: "quantityPerDay", value: String(lifestyle.smoking.quantityPerDay), icon: "number.circle", color: .icon)
            }

            LabeledInfoRow(label: "alcohol", value: NSLocalizedString(lifestyle.alcohol.frequency.rawValue, comment: ""), icon: "wineglass", color: .icon)

            if lifestyle.alcohol.frequency != .none, lifestyle.alcohol.unitsPerWeek > 0 {
                LabeledInfoRow(label: "unitsPerWeek", value: String(lifestyle.alcohol.unitsPerWeek), icon: "number.circle", color: .icon)
            }

            if !lifestyle.nutritionNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                LabeledInfoRow(label: "nutritionNotes", value: lifestyle.nutritionNotes, icon: "fork.knife", color: .icon)
            }

            if !lifestyle.sleepQuality.rawValue.isEmpty {
                LabeledInfoRow(label: "sleepQuality", value: NSLocalizedString(lifestyle.sleepQuality.rawValue, comment: ""), icon: "bed.double.fill", color: .icon)
            }

            if !lifestyle.stressLevel.rawValue.isEmpty {
                LabeledInfoRow(label: "stressLevel", value: NSLocalizedString(lifestyle.stressLevel.rawValue, comment: ""), icon: "exclamationmark.triangle", color: .icon)
            }
        }
    }
}

struct AnamnesisMedicalHistoryView: View {
    let history: MedicalHistory

    var body: some View {
        DisplaySectionBox(
            title: "medicalHistory",
            lightAccentColor: .accentColor,
            darkAccentColor: .accentColor
        ) {
            ForEach(medicalHistoryItems, id: \.key) { item in
                if !item.values.joined().trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    LabeledInfoRow(
                        label: NSLocalizedString(item.key, comment: ""),
                        value: item.values.joined(separator: ", "),
                        icon: item.icon,
                        color: item.color
                    )
                }
            }
        }
    }

    private var medicalHistoryItems: [(key: String, values: [String], icon: String, color: Color)] {
        [
            ("orthopedic", history.orthopedic, "figure.walk", .icon),
            ("neurological", history.neurological, "brain.head.profile", .icon),
            ("cardiovascular", history.cardiovascular, "heart.fill", .icon),
            ("pulmonary", history.pulmonary, "lungs.fill", .icon),
            ("metabolic", history.metabolic, "bolt.heart", .icon),
            ("psychiatric", history.psychiatric, "face.smiling", .icon),
            ("oncological", history.oncological, "cross.case.fill", .icon),
            ("autoimmune", history.autoimmune, "shield.lefthalf.fill", .icon),
            ("infectious", history.infectious, "bandage.fill", .icon),
            ("allergies", history.allergies, "leaf.fill", .icon),
            ("currentMedications", history.currentMedications, "pills.fill", .icon),
            ("surgeries", history.surgeries, "scissors", .icon),
            ("fractures", history.fractures, "figure.arms.open", .icon),
            ("other", history.other, "list.bullet", .icon)
        ]
    }
}
