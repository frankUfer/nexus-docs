//
//  Anamnesis.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 23.03.25.
//

import Foundation

// MARK: - Anamnesis

/// Represents a patient's anamnesis, including medical history and lifestyle information.
struct Anamnesis: Codable, Equatable, Hashable {
    /// Optional ID of the therapist who recorded the anamnesis.
    var therapistId: Int? = nil

    /// The patient's medical history.
    var medicalHistory: MedicalHistory

    /// The patient's lifestyle information.
    var lifestyle: Lifestyle

    /// Creates an empty `Anamnesis` instance with default values.
    /// - Parameter therapistId: Optional therapist ID to assign.
    /// - Returns: An empty `Anamnesis` object.
    static func empty(therapistId: Int? = nil) -> Anamnesis {
        Anamnesis(
            therapistId: therapistId,
            medicalHistory: MedicalHistory(
                orthopedic: [],
                neurological: [],
                cardiovascular: [],
                pulmonary: [],
                metabolic: [],
                psychiatric: [],
                oncological: [],
                autoimmune: [],
                infectious: [],
                allergies: [],
                currentMedications: [],
                surgeries: [],
                fractures: [],
                other: []
            ),
            lifestyle: Lifestyle(
                occupation: Occupation(type: .mixed, description: "", profession: ""),
                measurements: Measurements(height: 0, weight: 0),
                activityLevel: .moderate,
                sports: Sports(active: false, types: [], equipments: []),
                balanceIssues: BalanceIssues(hasProblems: false, symptoms: []),
                smoking: Smoking(status: .never, quantityPerDay: 0),
                alcohol: Alcohol(frequency: .none, unitsPerWeek: 0),
                nutritionNotes: "",
                sleepQuality: .moderate,
                stressLevel: .medium
            )
        )
    }
}

// MARK: - Medical History

/// Represents the medical history of a patient, categorized by medical fields and conditions.
struct MedicalHistory: Codable, Equatable, Hashable {
    var orthopedic: [String]           /// Orthopedic conditions or issues.
    var neurological: [String]         /// Neurological conditions or issues.
    var cardiovascular: [String]       /// Cardiovascular conditions or issues.
    var pulmonary: [String]            /// Pulmonary (lung-related) conditions or issues.
    var metabolic: [String]            /// Metabolic conditions or issues.
    var psychiatric: [String]          /// Psychiatric conditions or issues.
    var oncological: [String]          /// Oncological (cancer-related) conditions or issues.
    var autoimmune: [String]           /// Autoimmune conditions or issues.
    var infectious: [String]           /// Infectious diseases or issues.
    var allergies: [String]            /// Known allergies.
    var currentMedications: [String]   /// Current medications being taken.
    var surgeries: [String]            /// Past surgeries.
    var fractures: [String]            /// History of bone fractures.
    var other: [String]                /// Any other relevant medical history.
}

// MARK: - Lifestyle

/// Represents a patient's lifestyle, including occupation, activity, and habits.
struct Lifestyle: Codable, Equatable, Hashable {
    var occupation: Occupation
    var measurements: Measurements
    var activityLevel: ActivityLevel
    var sports: Sports
    var balanceIssues: BalanceIssues
    var smoking: Smoking
    var alcohol: Alcohol
    var nutritionNotes: String
    var sleepQuality: SleepQuality
    var stressLevel: StressLevel

    enum CodingKeys: String, CodingKey {
        case occupation, measurements, activityLevel, sports, balanceIssues, smoking, alcohol, nutritionNotes, sleepQuality, stressLevel
    }

    // Expliziter memberwise Initializer
    init(
        occupation: Occupation,
        measurements: Measurements,
        activityLevel: ActivityLevel,
        sports: Sports,
        balanceIssues: BalanceIssues,
        smoking: Smoking,
        alcohol: Alcohol,
        nutritionNotes: String,
        sleepQuality: SleepQuality,
        stressLevel: StressLevel
    ) {
        self.occupation = occupation
        self.measurements = measurements
        self.activityLevel = activityLevel
        self.sports = sports
        self.balanceIssues = balanceIssues
        self.smoking = smoking
        self.alcohol = alcohol
        self.nutritionNotes = nutritionNotes
        self.sleepQuality = sleepQuality
        self.stressLevel = stressLevel
    }

    // Custom decoding initializer bleibt bestehen
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        occupation = try container.decode(Occupation.self, forKey: .occupation)
        measurements = try container.decodeIfPresent(Measurements.self, forKey: .measurements) ?? Measurements(height: 0, weight: 0)
        activityLevel = try container.decode(ActivityLevel.self, forKey: .activityLevel)
        sports = try container.decode(Sports.self, forKey: .sports)
        balanceIssues = try container.decode(BalanceIssues.self, forKey: .balanceIssues)
        smoking = try container.decode(Smoking.self, forKey: .smoking)
        alcohol = try container.decode(Alcohol.self, forKey: .alcohol)
        nutritionNotes = try container.decode(String.self, forKey: .nutritionNotes)
        sleepQuality = try container.decode(SleepQuality.self, forKey: .sleepQuality)
        stressLevel = try container.decode(StressLevel.self, forKey: .stressLevel)
    }
}

// MARK: - Lifestyle Subtypes

/// Represents a patient's occupation.
struct Occupation: Codable, Equatable, Hashable {
    /// The type of occupation (e.g., sedentary, physical, mixed).
    var type: OccupationType
    /// A description of the occupation.
    var description: String
    /// The profession as free text.
    var profession: String
}

/// Measurements of patient
struct Measurements: Codable, Equatable, Hashable {
    var height: Int = 0
    var weight: Double = 0
    var bmi: Double {
        let h = Double(height) / 100.0
        guard h > 0 else { return 0 }
        return weight / (h * h)
    }
    
    var bmiCategory: String {
            switch bmi {
            case ..<18.5: return NSLocalizedString("underweight", comment: "Anamnesis")
            case 18.5..<25: return NSLocalizedString("normalWeight", comment: "Normal weight")
            case 25..<30: return NSLocalizedString("overweight", comment: "Overweight")
            default: return NSLocalizedString("obesity", comment: "Obesity")
            }
        }
}

/// Represents sports participation information.
struct Sports: Codable, Equatable, Hashable {
    /// Whether the patient is active in sports.
    var active: Bool
    /// Types of sports the patient participates in.
    var types: [String]
    /// Sports equipment the patient has available
    var equipments: [String]
}

/// Represents information about balance issues.
struct BalanceIssues: Codable, Equatable, Hashable {
    /// Whether the patient has balance problems.
    var hasProblems: Bool
    /// Symptoms related to balance issues.
    var symptoms: [String]
}

/// Represents smoking habits.
struct Smoking: Codable, Equatable, Hashable {
    /// Smoking status (never, former, current).
    var status: SmokingStatus
    /// Number of cigarettes (or equivalent) smoked per day.
    var quantityPerDay: Int
}

/// Represents alcohol consumption habits.
struct Alcohol: Codable, Equatable, Hashable {
    /// Frequency of alcohol consumption.
    var frequency: AlcoholFrequency
    /// Units of alcohol consumed per week.
    var unitsPerWeek: Int
}

// MARK: - Enums

/// Represents a person's general activity level.
enum ActivityLevel: String, Codable, CaseIterable, Hashable {
    case low       /// Low activity level.
    case moderate  /// Moderate activity level.
    case high      /// High activity level.
}

/// Represents the type of occupation.
enum OccupationType: String, Codable, CaseIterable, Hashable {
    case sedentary /// Mainly sedentary work.
    case physical  /// Mainly physical work.
    case mixed     /// Mixed (both sedentary and physical) work.
}

/// Represents the smoking status of a person.
enum SmokingStatus: String, Codable, CaseIterable, Hashable {
    case never     /// Never smoked.
    case former    /// Former smoker.
    case current   /// Currently smokes.
}

/// Represents the frequency of alcohol consumption.
enum AlcoholFrequency: String, Codable, CaseIterable, Hashable {
    case none        /// No alcohol consumption.
    case occasional  /// Occasional alcohol consumption.
    case regular     /// Regular alcohol consumption.
}

/// Represents the quality of a person's sleep.
enum SleepQuality: String, Codable, CaseIterable, Hashable {
    case good     /// Good sleep quality.
    case moderate /// Moderate sleep quality.
    case poor     /// Poor sleep quality.
}

/// Represents a person's stress level.
enum StressLevel: String, Codable, CaseIterable, Hashable {
    case low     /// Low stress level.
    case medium  /// Medium stress level.
    case high    /// High stress level.
}
