//
//  Untitled.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 27.03.25.
//

import Foundation
import SwiftUI

struct TreatmentSessions: Sendable, Identifiable, Codable, Hashable {
    var id: UUID
    var patientId: UUID?
    var date: Date

    // Uhrzeit von / bis (z. B. 08:30–09:15)
    var startTime: Date
    var endTime: Date

    // Adresse (definiert separat)
    var address: Address

    // Freier Titel
    var title: String

    // Statusflags
    var draft: Bool = false
    var isPlanned: Bool = false
    var isScheduled: Bool = false
    var isDone: Bool = false
    var isInvoiced: Bool = false
    var isPaid: Bool = false
    
    // Behandlung: Liste interner IDs von `TreatmentService`
    var treatmentServiceIds: [UUID] = []

    // Therapeut (nur ID, z. B. Benutzer- oder Mitarbeiter-ID)
    var therapistId: UUID

    // Liste von Referenz-IDs auf andere Statusobjekte (z. B. Reevals)
    var reevaluationEntryIds: [ReevaluationReferences] = []

    // Optional: Notizen
    var notes: String?
    
    /// Für Löschen den von Terminen beim Empfänger
    var icsUid: String?                 // wird in .ics-Datei verwendet
    var localCalendarEventId: String?  // wird für lokale Kalender-API verwendet
    var icsSequence: Int?
    
    // NEU: optionale Seriennummer (x / y) – zur Laufzeit befüllt
    struct Serial: Hashable, Sendable, Codable {
        let current: Int
        let total: Int
    }
    var serialNumber: Serial? = nil

    /// Anzeigeform "(x / y)"
    var serialDisplay: String? {
        guard let s = serialNumber else { return nil }
        return "(\(s.current) / \(s.total))"
    }

    // serialNumber NICHT codieren, damit flüchtig bleibt
    private enum CodingKeys: String, CodingKey {
        case id, patientId, date, startTime, endTime, address, title,
             draft, isPlanned, isScheduled, isDone, isInvoiced, isPaid,
             treatmentServiceIds, therapistId, reevaluationEntryIds, notes,
             icsUid, localCalendarEventId, icsSequence, serialNumber
    }
}

enum SessionStatus {
    case draft, planned, scheduled, done, invoiced, paid, unknown
}

extension TreatmentSessions {
    var duration: TimeInterval {
        endTime.timeIntervalSince(startTime)
    }

    mutating func setStatus(_ status: SessionStatus) {
        draft = false
        isPlanned = false
        isScheduled = false
        isDone = false
        isInvoiced = false
        isPaid = false

        switch status {
        case .draft:
            draft = true
        case .planned:
            isPlanned = true
        case .scheduled:
            isScheduled = true
        case .done:
            isDone = true
        case .invoiced:
            isInvoiced = true
        case .paid:
            isPaid = true
        case .unknown:
            break
        }
    }

    var currentStatus: SessionStatus {
        if isDone {
            return .done
        } else if isInvoiced {
            return .invoiced
        } else if isScheduled {
            return .scheduled
        } else if isPlanned {
            return .planned
        } else if draft {
            return .draft
        } else if isPaid {
            return .paid
        } else {
            return .unknown
        }
    }
}

extension TreatmentSessions {
    func overlaps(with start: Date, _ end: Date) -> Bool {
        return self.startTime < end && self.endTime > start
    }
}

extension TreatmentSessions {
    var canBeSentAsIcs: Bool {
        draft || isPlanned
    }

    var canBeCancelledAsIcs: Bool {
        isScheduled
    }
}

extension TreatmentSessions {
    func resolvedPatientId(in patients: [Patient]) -> UUID? {
        for patient in patients {
            let hasSession = patient.therapies
                .compactMap { $0 }
                .flatMap { $0.therapyPlans }
                .flatMap { $0.treatmentSessions }
                .contains(where: { $0.id == self.id })
            
            if hasSession {
                return patient.id
            }
        }
        return nil
    }
}

extension TreatmentSessions {
    var statusColor: Color {
        switch currentStatus {
        case .draft, .planned, .scheduled:
            return .accentColor
        case .done, .invoiced, .paid:
            return .positiveCheck
        case .unknown:
            return .primary
        }
    }
}

extension TreatmentSessions {
    var currentStatusText: String {
        switch currentStatus {
        case .draft:
            return NSLocalizedString("draft", comment: "Draft")
        case .planned:
            return NSLocalizedString("planned", comment: "Planned")
        case .scheduled:
            return NSLocalizedString("scheduled", comment: "Scheduled")
        case .done:
            return NSLocalizedString("done", comment: "Done")
        case .invoiced:
            return NSLocalizedString("invoiced", comment: "Invoiced")
        case .paid:
            return NSLocalizedString("paid", comment: "paid")
        case .unknown:
            return NSLocalizedString("unknown", comment: "Unknown")
        }
    }
    
    var currentStatusIcon: String {
        switch currentStatus {
        case .draft:
            return "square.and.pencil"
        case .planned:
            return "calendar"
        case .scheduled:
            return "calendar.badge.clock"
        case .done:
            return "checkmark.circle.fill"
        case .invoiced:
            return "doc.plaintext"
        case .paid:
            return "eurosign.circle"
        case .unknown:
            return "questionmark.circle"
        }
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(UUID.self, forKey: .id)
        date = try container.decode(Date.self, forKey: .date)
        startTime = try container.decode(Date.self, forKey: .startTime)
        endTime = try container.decode(Date.self, forKey: .endTime)
        address = try container.decode(Address.self, forKey: .address)
        title = try container.decode(String.self, forKey: .title)
        draft = try container.decodeIfPresent(Bool.self, forKey: .draft) ?? false
        isPlanned = try container.decodeIfPresent(Bool.self, forKey: .isPlanned) ?? false
        isScheduled = try container.decodeIfPresent(Bool.self, forKey: .isScheduled) ?? false
        isDone = try container.decodeIfPresent(Bool.self, forKey: .isDone) ?? false
        isInvoiced = try container.decodeIfPresent(Bool.self, forKey: .isInvoiced) ?? false
        isPaid = try container.decodeIfPresent(Bool.self, forKey: .isPaid) ?? false
        
        treatmentServiceIds = try container.decodeIfPresent([UUID].self, forKey: .treatmentServiceIds) ?? []
        therapistId = try decodeTherapistId(from: container, forKey: .therapistId)
        reevaluationEntryIds = try container.decodeIfPresent([ReevaluationReferences].self, forKey: .reevaluationEntryIds) ?? []
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        icsUid = try container.decodeIfPresent(String.self, forKey: .icsUid)
        localCalendarEventId = try container.decodeIfPresent(String.self, forKey: .localCalendarEventId)
        icsSequence = try container.decodeIfPresent(Int.self, forKey: .icsSequence)
        patientId = try container.decodeIfPresent(UUID.self, forKey: .patientId)
        serialNumber = try container.decodeIfPresent(Serial.self, forKey: .serialNumber)
    }
}

extension TreatmentSessions {
    /// Gibt `patientId` zurück – oder löst sie aus einer Patientenliste, wenn sie fehlt.
    func resolvedOrFallbackPatientId(in patients: [Patient]) -> UUID? {
        if let id = patientId {
            return id
        } else {
            for patient in patients {
                let hasSession = patient.therapies
                    .compactMap { $0 }
                    .flatMap { $0.therapyPlans }
                    .flatMap { $0.treatmentSessions }
                    .contains(where: { $0.id == self.id })

                if hasSession {
                    return patient.id
                }
            }
            return nil
        }
    }
}

