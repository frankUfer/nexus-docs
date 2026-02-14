//
//  MultiPatientCalendarView.swift
//  AthleticPerformance
//
//  Created by Frank Ufer on 13.06.25.
//

import SwiftUI

struct MultiPatientCalendarView: View {
    let patients: [Patient]
    let selectedPatientIds: Set<UUID>
    @Binding var currentDate: Date
    @Binding var selectedView: CalendarViewType

    @State private var sessionsSnapshot: [TreatmentSessions] = []
    @State private var patientsSnapshot: [UUID: Patient] = [:]

    var body: some View {
        VStack {
            Picker("Ansicht", selection: $selectedView) {
                ForEach(CalendarViewType.allCases) { view in
                    Text(view.localizedName).tag(view)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            switch selectedView {
            case .day:
                MultiPatientDayView(
                    date: currentDate,
                    sessions: sessionsSnapshot,
                    patientsById: patientsSnapshot,
                    onSelectDay: { currentDate = $0 },
                    onPreviousWeek: {
                        currentDate =
                            Calendar.current.date(
                                byAdding: .day,
                                value: -7,
                                to: currentDate
                            ) ?? currentDate
                    },
                    onNextWeek: {
                        currentDate =
                            Calendar.current.date(
                                byAdding: .day,
                                value: 7,
                                to: currentDate
                            ) ?? currentDate
                    },
                    selectedPatientIds: selectedPatientIds,
                    patientColors: patientColors
                )

            case .week:
                MultiPatientWeekView(
                    currentDate: $currentDate,
                    sessions: sessionsSnapshot,
                    patientColors: patientColors,
                    patientsById: patientsSnapshot,
                    selectedPatientIds: selectedPatientIds,
                    onSelectDay: { currentDate = $0 },
                    onPreviousWeek: {
                        currentDate =
                            Calendar.current.date(
                                byAdding: .day,
                                value: -7,
                                to: currentDate
                            ) ?? currentDate
                    },
                    onNextWeek: {
                        currentDate =
                            Calendar.current.date(
                                byAdding: .day,
                                value: 7,
                                to: currentDate
                            ) ?? currentDate
                    }
                )

            case .month:
                MultiPatientMonthView(
                    date: currentDate,
                    sessions: sessionsSnapshot,
                    patientsById: patientsSnapshot,
                    onSelectDay: { currentDate = $0 }
                )
            }
        }
        .onAppear { rebuildSnapshots(source: patients) }
        .onChange(of: selectedPatientIds) { _, _ in rebuildSnapshots(source: patients) }
        .onChange(of: selectedView) { _, _ in rebuildSnapshots(source: patients) }
        .onChange(of: currentDate) { _, _ in rebuildSnapshots(source: patients) }

    }

    // MARK: - Helpers

    private func rebuildSnapshots(source: [Patient]) {      
        let allPatients = source

        // Optional: sichtbares Fenster berechnen
        let window = visibleRange(for: selectedView, around: currentDate)

        // Patienten-Dictionary
        patientsSnapshot = Dictionary(
            uniqueKeysWithValues: allPatients.map { ($0.id, $0) }
        )

        // Sessions (Drafts raus, optional auf Zeitfenster filtern)
        var sessions: [TreatmentSessions] = []
        sessions.reserveCapacity(256)  // micro-opt, optional

        for p in allPatients {
            for tOpt in p.therapies {
                guard let t = tOpt else { continue }
                for plan in t.therapyPlans {
                    for s in plan.treatmentSessions where !s.draft {
                        var ss = s
                        if ss.patientId == nil {  // 👈 Fallback hier
                            ss.patientId = p.id
                        }
                        if let w = window {
                            if ss.startTime < w.upperBound
                                && ss.endTime > w.lowerBound
                            {
                                sessions.append(ss)
                            }
                        } else {
                            sessions.append(ss)
                        }
                    }
                }
            }
        }

        // 🔧 Duplikate über die Session-ID entfernen (Quelle der Wahrheit: die „neueste“ Variante)
        sessionsSnapshot = Array(Dictionary(grouping: sessions, by: { $0.id }).compactMap { $0.value.last })
    }

    /// Sichtbarer Datumsbereich (nil = kein Filter)
    private func visibleRange(for view: CalendarViewType, around date: Date)
        -> Range<Date>?
    {
        let cal = Calendar.current
        switch view {
        case .day:
            let start = cal.startOfDay(for: date)
            guard let end = cal.date(byAdding: .day, value: 1, to: start) else {
                return nil
            }
            return start..<end
        case .week:
            let start =
                cal.date(
                    from: cal.dateComponents(
                        [.yearForWeekOfYear, .weekOfYear],
                        from: date
                    )
                ) ?? cal.startOfDay(for: date)
            guard let end = cal.date(byAdding: .day, value: 7, to: start) else {
                return nil
            }
            return start..<end
        case .month:
            guard
                let start = cal.date(
                    from: cal.dateComponents([.year, .month], from: date)
                ),
                let end = cal.date(byAdding: .month, value: 1, to: start)
            else { return nil }
            return start..<end
        }
    }

    private var patientColors: [UUID: Color] {
        Dictionary(
            uniqueKeysWithValues: patientsSnapshot.keys.map {
                ($0, patientColor($0))
            }
        )
    }

    private func patientColor(_ id: UUID) -> Color {
        let hue = Double(abs(id.hashValue % 360)) / 360.0
        return Color(hue: hue, saturation: 0.5, brightness: 0.9)
    }
}
