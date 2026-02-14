//
//  TreatmentSessionDetailView.swift
//  AthleticPerformance
//
//  Created by Frank Ufer on 13.06.25.
//

import SwiftUI

struct TreatmentSessionDetailView: View {
    let session: TreatmentSessions
    let patientId: UUID?     
    let allServices: [TreatmentService]
    let therapists: [Therapists]
    let patientsById: [UUID: Patient]
    
    @EnvironmentObject var patientStore: PatientStore
    @EnvironmentObject var navigationStore: AppNavigationStore

    private var sessionDurationMinutes: Int {
        let diff = session.endTime.timeIntervalSince(session.startTime)
        return max(Int(diff / 60), 0)
    }

    private var therapist: Therapists? {
        therapists.first(where: { $0.id == session.therapistId })
    }

    private var sessionStatusText: String {
        switch effectiveStatus {
        case .invoiced: return NSLocalizedString("invoiced", comment: "")
        case .done:     return NSLocalizedString("done", comment: "")
        case .scheduled:return NSLocalizedString("scheduled", comment: "")
        case .planned:  return NSLocalizedString("planned", comment: "")
        case .draft:    return NSLocalizedString("draft", comment: "")
        case .unknown:  return ""
        }
    }

    private var sessionStatusColor: Color {
        switch effectiveStatus {
        case .invoiced:  return Color("doneColor")
        case .done:      return Color("iconColor")
        case .scheduled: return Color("positiveCheckColor")
        case .planned:   return Color("errorColor")
        case .draft:     return Color("AccentColor")
        case .unknown:   return .purple
        }
    }

    private enum SessionStatus {
        case invoiced, done, scheduled, planned, draft, unknown
    }

    private var effectiveStatus: SessionStatus {
        if session.isInvoiced { return .invoiced }
        if session.isDone     { return .done }
        if session.isScheduled{ return .scheduled }
        if session.isPlanned  { return .planned }
        if session.draft      { return .draft }
        return .unknown
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Titel
            if !session.title.isEmpty {
                Text(
                    session.serialNumber != nil
                    ? "\(session.title) (\(session.serialNumber!.current)/\(session.serialNumber!.total))"
                    : session.title
                )
                .font(.title2.bold())
                .lineLimit(1)
            }

            // Datum und Zeit
            VStack(alignment: .leading, spacing: 4) {
                Label {
                    Text("\(session.date.formatted(.dateTime.weekday(.wide).day().month().year())), \(session.startTime.formatted(date: .omitted, time: .shortened)) – \(session.endTime.formatted(date: .omitted, time: .shortened))")
                } icon: {
                    Image(systemName: "calendar")
                }

                Text("\(sessionDurationMinutes) Minuten")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Patient
            Label(patientName, systemImage: "person.crop.circle")
            
            // Ort
            Label(session.address.fullDescription, systemImage: "mappin.and.ellipse")

            // Therapeut
            if let t = therapist {
                Label(t.fullName, systemImage: "person.fill")
            }

            // Status
            Label(sessionStatusText, systemImage: "checkmark.circle.fill")
                .foregroundColor(sessionStatusColor)
                .padding(.top, 8)

            // Heilmittel
            if !session.treatmentServiceIds.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Heilmittel:")
                        .font(.headline)
                    ForEach(session.treatmentServiceIds, id: \.self) { id in
                        if let service = allServices.first(where: { $0.internalId == id }) {
                            Text("• \(service.de) – \(service.quantity ?? 0) \(service.unit ?? "")")
                                .font(.subheadline)
                        }
                    }
                }
            }
            
            // Button → zur Patienten-Ansicht springen
            if let patient = patientForSession() {
                HStack {
                    Spacer()

                    Button {
                        navigationStore.selectedPatientID = patient.id
                        navigationStore.selectedMainMenu = .patients
                    } label: {
                        Label(NSLocalizedString("showPatient", comment: "Show Patient"), systemImage: "arrow.right.circle")
                    }
                    .buttonStyle(.bordered)
                    .padding(.top, 20)

                    Spacer()
                }
            }
            
            Spacer()
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGroupedBackground)))
    }
        
    private var patientName: String {
        if let patientId, let patient = patientsById[patientId] {
            return patient.fullName
        } else if let fallback = patientForSession() {
            return fallback.fullName
        } else {
            return NSLocalizedString("unknown", comment: "Unknown patient")
        }
    }
    
    private func patientForSession() -> Patient? {
        for patient in patientStore.patients {
            for therapy in patient.therapies.compactMap({ $0 }) {
                for plan in therapy.therapyPlans {
                    if plan.treatmentSessions.contains(where: { $0.id == session.id }) {
                        return patient
                    }
                }
            }
        }
        return nil
    }
}
