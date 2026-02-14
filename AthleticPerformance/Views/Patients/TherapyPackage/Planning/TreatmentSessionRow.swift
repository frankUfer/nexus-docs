//
//  TreatmentSessionRow.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 28.05.25.
//

import SwiftUI

struct TreatmentSessionRow: View {
    let session: TreatmentSessions
    let allServices: [TreatmentService]
    let therapists: [Therapists]
    let isMarkedForCancellation: Bool
    let showCancellation: Bool
    let onToggleCancellation: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Titel, Datum, Uhrzeit, Gesamtdauer
            HStack {
                if !session.title.isEmpty {
                    Text(session.title)
                        .foregroundColor(.primary)
                    if let serial = session.serialDisplay {
                        Text(serial)
                            .foregroundColor(.secondary)
                            .font(.subheadline)
                            .monospacedDigit()
                            .accessibilityLabel(Text(serial))
                    }
                }
                
                Spacer()
                
                Text("\(session.date.formatted(.dateTime.weekday(.wide).locale(Locale.current))), \(session.date.formatted(date: .abbreviated, time: .omitted)): ")
                    .foregroundColor(.primary)

                Text("\(session.startTime.formatted(date: .omitted, time: .shortened)) – \(session.endTime.formatted(date: .omitted, time: .shortened))")
                    .foregroundColor(.primary)
                
                Text("(\(sessionDurationMinutes) Min)")
                    .foregroundColor(.secondary)
            }
            .font(.subheadline)

            // Behandlungsort, Therapeut & Status
            HStack(spacing: 12) {
                Label(session.address.fullDescription, systemImage: "mappin.and.ellipse")
                    .foregroundColor(.secondary)
                
                if let therapist = therapists.first(where: { $0.id == session.therapistId }) {
                    Label(therapist.fullName, systemImage: "person.fill")
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if session.isScheduled && showCancellation {
                    HStack(spacing: 8) {
                        Text(NSLocalizedString("markForCancellation", comment: "Mark for cancellation"))
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Button(action: onToggleCancellation) {
                            Image(systemName: isMarkedForCancellation ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(isMarkedForCancellation ? .positiveCheck : .negativeCheck)
                                .font(.title3)
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                Spacer()
                    .frame(width: 24)
                
                Label(sessionStatusText, systemImage: "checkmark.circle.fill")
                    .foregroundColor(sessionStatusColor)
                    .padding(4)
                    .background(sessionStatusColor.opacity(0.1))
                    .cornerRadius(4)
            }
            .font(.subheadline)

            // Behandlungen im Detail
            if !session.treatmentServiceIds.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text(NSLocalizedString("remedies", comment: "Remedies"))
                        .foregroundColor(.accent)

                    ForEach(session.treatmentServiceIds, id: \.self) { id in
                        if let service = allServices.first(where: { $0.internalId == id }) {
                            let quantity = service.quantity ?? 0
                            let unit = service.unit ?? ""
                            Text("• \(service.de) – \(quantity) \(unit)")
                                .foregroundColor(.secondary)
                        }
                    }
                    .font(.subheadline)
                }
                .padding(.top, 4)
            }
  
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isMarkedForCancellation ? Color.red.opacity(0.2) : Color(.secondarySystemGroupedBackground))
        )
    }

    private var sessionDurationMinutes: Int {
        let diff = session.endTime.timeIntervalSince(session.startTime)
        return max(Int(diff / 60), 0)
    }

    private enum SessionStatus {
        case invoiced, done, scheduled, planned, draft, unknown
    }

    private var effectiveStatus: SessionStatus {
        if session.isDone {
            return .done
        } else if session.isInvoiced {
            return .invoiced
        } else if session.isScheduled {
            return .scheduled
        } else if session.isPlanned {
            return .planned
        } else if session.draft {
            return .draft
        } else {
            return .unknown
        }
    }
    
    private var sessionStatusText: String {
        switch effectiveStatus {
        case .invoiced:
            return NSLocalizedString("invoiced", comment: "Invoiced")
        case .done:
            return NSLocalizedString("done", comment: "Done")
        case .scheduled:
            return NSLocalizedString("scheduled", comment: "Scheduled")
        case .planned:
            return NSLocalizedString("planned", comment: "Planned")
        case .draft:
            return NSLocalizedString("draft", comment: "Draft")
        case .unknown:
            return ""
        }
    }

    private var sessionStatusColor: Color {
        switch effectiveStatus {
        case .invoiced:
            return Color("doneColor")
        case .done:
            return Color("iconColor")
        case .scheduled:
            return Color("positiveCheckColor")
        case .planned:
            return Color("errorColor")
        case .draft:
            return Color("AccentColor")
        case .unknown:
            return .purple
        }
    }
}
