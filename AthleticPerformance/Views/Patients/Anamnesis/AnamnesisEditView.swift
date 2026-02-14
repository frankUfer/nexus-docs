//
//  AnamnesisEditView.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 23.03.25.
//

import SwiftUI

struct AnamnesisEditView: View {
    var initialAnamnesis: Anamnesis
    var patient: Patient
    var onSave: (Anamnesis) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var anamnesisCopy: Anamnesis
    @State private var showValidationAlert = false
    @State private var validationMessage = ""

    init(initialAnamnesis: Anamnesis, patient: Patient, onSave: @escaping (Anamnesis) -> Void) {
        self.initialAnamnesis = initialAnamnesis
        self.patient = patient
        self.onSave = onSave
        self._anamnesisCopy = State(initialValue: initialAnamnesis)
    }

    var body: some View {
        Form {
            Section(header: Text(NSLocalizedString("therapist", comment: "Therapist"))) {
                Picker("", selection: $anamnesisCopy.therapistId) {
                    ForEach(AppGlobals.shared.therapistList, id: \.id) { therapist in
                        Text(therapist.fullName).tag(therapist.id as Int?)
                    }
                }
            }

            Section(header: Text(NSLocalizedString("occupation", comment: "Occupation"))) {
                Picker(NSLocalizedString("occupationType", comment: "Occupation Type"), selection: $anamnesisCopy.lifestyle.occupation.type) {
                    ForEach(OccupationType.allCases, id: \.self) { type in
                        Text(NSLocalizedString(type.rawValue, comment: "")).tag(type)
                    }
                }
                TextField(NSLocalizedString("occupationDescription", comment: "Occupation Description"), text: $anamnesisCopy.lifestyle.occupation.description)
                TextField(NSLocalizedString("profession", comment: "Profession"), text: $anamnesisCopy.lifestyle.occupation.profession)
            }
            
            Section(header: Text(NSLocalizedString("measurements", comment: "Measurements"))) {
                TextField(
                    NSLocalizedString("height", comment: "Height"),
                    value: $anamnesisCopy.lifestyle.measurements.height,
                    format: .number
                )
                .keyboardType(.numberPad)
                
                TextField(
                    NSLocalizedString("weight", comment: "Weight"),
                    value: $anamnesisCopy.lifestyle.measurements.weight,
                    format: .number.precision(.fractionLength(1))
                )
                .keyboardType(.decimalPad)

                if anamnesisCopy.lifestyle.measurements.bmi > 0 {
                    Text("\(NSLocalizedString("bmi", comment: "BMI")): \(String(format: "%.1f", anamnesisCopy.lifestyle.measurements.bmi)) – \(anamnesisCopy.lifestyle.measurements.bmiCategory)")
                        .foregroundColor(.secondary)
                }
            }

            Section(header: Text(NSLocalizedString("activityAndSports", comment: "Activity & Sports"))) {
                Picker(NSLocalizedString("activityLevel", comment: "Activity Level"), selection: $anamnesisCopy.lifestyle.activityLevel) {
                    ForEach(ActivityLevel.allCases, id: \.self) { level in
                        Text(NSLocalizedString(level.rawValue, comment: "")).tag(level)
                    }
                }
                
                BoolSwitch(
                    value: $anamnesisCopy.lifestyle.sports.active,
                    label: NSLocalizedString("sports", comment: "Sports")
                )

                if anamnesisCopy.lifestyle.sports.active {
                    TextField(NSLocalizedString("sportsTypes", comment: "Sports Types"), text: Binding(
                        get: { anamnesisCopy.lifestyle.sports.types.joined(separator: ", ") },
                        set: { anamnesisCopy.lifestyle.sports.types = $0.components(separatedBy: ", ").map { $0.trimmingCharacters(in: .whitespaces) } }
                    ))

                    TextField(NSLocalizedString("sportsEquipments", comment: "Sports Equipment"), text: Binding(
                        get: { anamnesisCopy.lifestyle.sports.equipments.joined(separator: ", ") },
                        set: { anamnesisCopy.lifestyle.sports.equipments = $0.components(separatedBy: ", ").map { $0.trimmingCharacters(in: .whitespaces) } }
                    ))
                }
            }
            
            Section(header: Text(NSLocalizedString("balance", comment: "Balance"))) {
                BoolSwitch(
                    value: $anamnesisCopy.lifestyle.balanceIssues.hasProblems,
                    label: NSLocalizedString("balanceIssues", comment: "Balance Issues")
                )
                if anamnesisCopy.lifestyle.balanceIssues.hasProblems {
                    TextField(NSLocalizedString("balanceSymptoms", comment: "Balance Symptoms"), text: Binding(
                        get: { anamnesisCopy.lifestyle.balanceIssues.symptoms.joined(separator: ", ") },
                        set: { anamnesisCopy.lifestyle.balanceIssues.symptoms = $0.components(separatedBy: ", ").map { $0.trimmingCharacters(in: .whitespaces) } }
                    ))
                }
            }

            Section(header: Text(NSLocalizedString("smokingAndAlcohol", comment: "Smoking & Alcohol"))) {
                Picker(NSLocalizedString("smoking", comment: "Smoking"), selection: $anamnesisCopy.lifestyle.smoking.status) {
                    ForEach(SmokingStatus.allCases, id: \.self) { status in
                        Text(NSLocalizedString(status.rawValue, comment: "")).tag(status)
                    }
                }
                if anamnesisCopy.lifestyle.smoking.status == .current {
                    Stepper(value: $anamnesisCopy.lifestyle.smoking.quantityPerDay, in: 0...100) {
                        Text("\(NSLocalizedString("quantityPerDay", comment: "Quantity")): \(anamnesisCopy.lifestyle.smoking.quantityPerDay)")
                    }
                }

                Picker(NSLocalizedString("alcohol", comment: "Alcohol"), selection: $anamnesisCopy.lifestyle.alcohol.frequency) {
                    ForEach(AlcoholFrequency.allCases, id: \.self) { freq in
                        Text(NSLocalizedString(freq.rawValue, comment: "")).tag(freq)
                    }
                }
                if anamnesisCopy.lifestyle.alcohol.frequency != .none {
                    Stepper(value: $anamnesisCopy.lifestyle.alcohol.unitsPerWeek, in: 0...30) {
                        Text("\(NSLocalizedString("unitsPerWeek", comment: "Units per week")): \(anamnesisCopy.lifestyle.alcohol.unitsPerWeek)")
                    }
                }
            }

            Section(header: Text(NSLocalizedString("nutritionAndWellbeing", comment: "Nutrition & Wellbeing"))) {
                TextField(NSLocalizedString("nutritionNotes", comment: "Nutrition Notes"), text: $anamnesisCopy.lifestyle.nutritionNotes)
                Picker(NSLocalizedString("sleepQuality", comment: "Sleep Quality"), selection: $anamnesisCopy.lifestyle.sleepQuality) {
                    ForEach(SleepQuality.allCases, id: \.self) { quality in
                        Text(NSLocalizedString(quality.rawValue, comment: "")).tag(quality)
                    }
                }
                Picker(NSLocalizedString("stressLevel", comment: "Stress Level"), selection: $anamnesisCopy.lifestyle.stressLevel) {
                    ForEach(StressLevel.allCases, id: \.self) { level in
                        Text(NSLocalizedString(level.rawValue, comment: "")).tag(level)
                    }
                }
            }
            
            Section(header: Text(NSLocalizedString("medicalHistory", comment: "Medical History"))) {
                medicalField("orthopedic", $anamnesisCopy.medicalHistory.orthopedic)
                medicalField("neurological", $anamnesisCopy.medicalHistory.neurological)
                medicalField("cardiovascular", $anamnesisCopy.medicalHistory.cardiovascular)
                medicalField("pulmonary", $anamnesisCopy.medicalHistory.pulmonary)
                medicalField("metabolic", $anamnesisCopy.medicalHistory.metabolic)
                medicalField("psychiatric", $anamnesisCopy.medicalHistory.psychiatric)
                medicalField("oncological", $anamnesisCopy.medicalHistory.oncological)
                medicalField("autoimmune", $anamnesisCopy.medicalHistory.autoimmune)
                medicalField("infectious", $anamnesisCopy.medicalHistory.infectious)
                medicalField("allergies", $anamnesisCopy.medicalHistory.allergies)
                medicalField("currentMedications", $anamnesisCopy.medicalHistory.currentMedications)
                medicalField("surgeries", $anamnesisCopy.medicalHistory.surgeries)
                medicalField("fractures", $anamnesisCopy.medicalHistory.fractures)
                medicalField("other", $anamnesisCopy.medicalHistory.other)
            }
        }
        .navigationTitle(NSLocalizedString("anamnesis", comment: "Anamnesis"))
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(NSLocalizedString("cancel", comment: "Cancel")) {
                    dismiss()
                }
                .foregroundColor(.cancel)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(NSLocalizedString("save", comment: "Save")) {
                    validateAndSave()
                }
                .foregroundColor(.addButton)
            }
        }
        .alert(isPresented: $showValidationAlert) {
            Alert(
                title: Text(NSLocalizedString("validationError", comment: "Validation error")),
                message: Text(validationMessage),
                dismissButton: .default(Text(NSLocalizedString("ok", comment: "Ok")))
            )
        }
    }

    private func medicalField(_ key: String, _ binding: Binding<[String]>) -> some View {
        TextField(NSLocalizedString(key, comment: "Medical history field"), text: Binding(
            get: { binding.wrappedValue.joined(separator: ", ") },
            set: { binding.wrappedValue = $0.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) } }
        ))
    }

    private func validateAndSave() {
        onSave(anamnesisCopy)
        dismiss()
    }
}
