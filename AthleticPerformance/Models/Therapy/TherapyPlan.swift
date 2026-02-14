//
//  TherapyPlan.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 12.04.25.
//

import Foundation

struct TherapyPlan: Identifiable, Codable, Hashable {
    var id: UUID
    var diagnosisId: UUID?
    var therapistId: Int?
    var title: String? = nil {
        didSet {
            propagateTitleChange()
        }
    }
    var treatmentServiceIds: [UUID]
    var frequency: TherapyFrequency?
    var weekdays: [Weekday]?
    var preferredTimeOfDay: TimeOfDay?
    var startDate: Date?
    var numberOfSessions: Int
    
    // NEU: nach Änderungen automatisch neu nummerieren
    var treatmentSessions: [TreatmentSessions] = [] {
        didSet { renumberSessions() }
    }
    
    private var _isRenumbering = false
    private var _isPropagatingTitle = false
    
    // var treatmentSessions: [TreatmentSessions] = []
    var sessionDocs: [TherapySessionDocumentation] = []
    var addressId: UUID?
    var isCompleted: Bool = false
    
    // WICHTIG: _isRenumbering hier NICHT aufführen
    private enum CodingKeys: String, CodingKey {
        case id, diagnosisId, therapistId, title, treatmentServiceIds, frequency,
             weekdays, preferredTimeOfDay, startDate, numberOfSessions,
             treatmentSessions, sessionDocs, addressId, isCompleted
    }

    init(
        id: UUID = UUID(),
        diagnosisId: UUID? = nil,
        therapistId: Int?,
        title: String = "",
        treatmentServiceIds: [UUID] = [],
        frequency: TherapyFrequency? = .weekly,
        preferredTimeOfDay: TimeOfDay? = .morning,
        weekdays: [Weekday]? = [],
        startDate: Date = Date(),
        numberOfSessions: Int = 10,
        treatmentSessions: [TreatmentSessions] = [],
        sessionDocs: [TherapySessionDocumentation] = [],
        addressId: UUID? = nil,
        isCompleted: Bool = false
    ) {
        self.id = id
        self.diagnosisId = diagnosisId
        self.therapistId = therapistId
        self.title = title
        self.treatmentServiceIds = treatmentServiceIds
        self.frequency = frequency
        self.preferredTimeOfDay = preferredTimeOfDay
        self.weekdays = weekdays
        self.startDate = startDate
        self.numberOfSessions = numberOfSessions
        self.treatmentSessions = treatmentSessions
        self.sessionDocs = sessionDocs
        self.addressId = addressId
        self.isCompleted = isCompleted
        
        // Initiale Durchnummerierung
         renumberSessions()
    }
    
    // NEU: zentrale Nummerierungslogik
    mutating func renumberSessions() {
        if _isRenumbering { return }
        _isRenumbering = true
        defer { _isRenumbering = false }

        guard !treatmentSessions.isEmpty else { return }

        let ordered = treatmentSessions.sorted {
            if $0.date != $1.date { return $0.date < $1.date }
            if $0.startTime != $1.startTime { return $0.startTime < $1.startTime }
            return $0.id.uuidString < $1.id.uuidString
        }

        let total = ordered.count
        var idxById: [UUID: Int] = [:]
        for (i, s) in ordered.enumerated() { idxById[s.id] = i + 1 }

        for i in treatmentSessions.indices {
            if let current = idxById[treatmentSessions[i].id] {
                treatmentSessions[i].serialNumber = .init(current: current, total: total)
            } else {
                treatmentSessions[i].serialNumber = nil
            }
        }
    }
    
    private mutating func propagateTitleChange() {
        if _isPropagatingTitle { return }
        _isPropagatingTitle = true
        defer { _isPropagatingTitle = false }

        guard let newTitle = title else { return }

        for i in treatmentSessions.indices {
            treatmentSessions[i].title = newTitle
        }
    }
}

/// Frequency options for therapy sessions.
enum TherapyFrequency: String, Codable, CaseIterable, Identifiable {
    case daily
    case multiplePerWeek
    case weekly
    case biweekly

    /// Unique identifier for the frequency (required for Identifiable).
    var id: String { rawValue }

    /// Localized display name for the frequency.
    var localizedName: String {
        switch self {
        case .daily: return NSLocalizedString("daily", comment: "daily")
        case .multiplePerWeek: return NSLocalizedString("multiplePerWeek", comment: "Multiple per week")
        case .weekly: return NSLocalizedString("weekly", comment: "weekly")
        case .biweekly: return NSLocalizedString("biweekly", comment: "bi weekly")
        }
    }
    
    /// Days between appointments (if fixed).
       var intervalInDays: Int? {
           switch self {
           case .daily: return 1
           case .multiplePerWeek: return 2
           case .weekly: return 7
           case .biweekly: return 14
           }
       }
}

/// Preferred time of day for a therapy session.
enum TimeOfDay: String, Codable, CaseIterable {
    case morning
    case afternoon
    case evening

    var localizedName: String {
        switch self {
        case .morning: return NSLocalizedString("morning", comment: "morning")
        case .afternoon: return NSLocalizedString("afternoon", comment: "afternoon")
        case .evening: return NSLocalizedString("evening", comment: "evening")
        }
    }

    var timeRange: TimeRange {
        switch self {
        case .morning: return TimeRange(startMinutes: 8 * 60, endMinutes: 12 * 60)
        case .afternoon: return TimeRange(startMinutes: 12 * 60, endMinutes: 16 * 60)
        case .evening: return TimeRange(startMinutes: 16 * 60, endMinutes: 20 * 60)
        }
    }

    var defaultTime: (hour: Int, minute: Int) {
        switch self {
        case .morning: return (8, 0)
        case .afternoon: return (12, 0)
        case .evening: return (16, 0)
        }
    }
}

/// Preffered days of the week
enum Weekday: Int, CaseIterable, Codable, Identifiable {
    case monday = 1, tuesday, wednesday, thursday, friday, saturday, sunday

    var id: Int { rawValue }

    var localizedName: String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        return formatter.weekdaySymbols[rawValue - 1]
    }

    var shortName: String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        return formatter.shortWeekdaySymbols[rawValue - 1]
    }
}

struct TimeRange {
    let startMinutes: Int  // z. B. 480 = 8:00
    let endMinutes: Int    // z. B. 719 = 11:59

    func contains(hour: Int, minute: Int = 0) -> Bool {
        let total = hour * 60 + minute
        return (startMinutes...endMinutes).contains(total)
    }

    var startHour: Int { startMinutes / 60 }
    var startMinute: Int { startMinutes % 60 }

    var endHour: Int { endMinutes / 60 }
    var endMinute: Int { endMinutes % 60 }
}

extension TherapyPlan: Equatable {
    static func == (lhs: TherapyPlan, rhs: TherapyPlan) -> Bool {
        lhs.id == rhs.id
        && lhs.treatmentSessions == rhs.treatmentSessions
        && lhs.title == rhs.title
        && lhs.treatmentServiceIds == rhs.treatmentServiceIds
        && lhs.frequency == rhs.frequency
        && lhs.weekdays == rhs.weekdays
        && lhs.preferredTimeOfDay == rhs.preferredTimeOfDay
        && lhs.startDate == rhs.startDate
        && lhs.numberOfSessions == rhs.numberOfSessions
        && lhs.addressId == rhs.addressId
        && lhs.isCompleted == rhs.isCompleted
        && lhs.diagnosisId == rhs.diagnosisId
        && lhs.therapistId == rhs.therapistId
    }
}
