//
//  MultiPatientMonthView.swift
//  AthleticPerformance
//
//  Created by Frank Ufer on 13.06.25.
//

import SwiftUI

struct MultiPatientMonthView: View {
    let calendar = Calendar.current
    let date: Date
    let sessions: [TreatmentSessions]
    let patientsById: [UUID: Patient]
    let onSelectDay: (Date) -> Void

    private var monthDates: [Date] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: date) else { return [] }
        let firstWeek = calendar.dateInterval(of: .weekOfMonth, for: monthInterval.start)!
        let lastWeek = calendar.dateInterval(of: .weekOfMonth, for: monthInterval.end)!
        let range = DateInterval(start: firstWeek.start, end: lastWeek.end)
        return stride(from: range.start, to: range.end, by: 60 * 60 * 24).map { $0 }
    }

    var body: some View {
        VStack(spacing: 4) {
            // Header
            let weekdaySymbols = calendar.shortWeekdaySymbols
            HStack {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.caption)
                        .frame(maxWidth: .infinity)
                }
            }

            // Grid
            let columns = Array(repeating: GridItem(.flexible()), count: 7)
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(monthDates, id: \.self) { day in
                    let isToday = calendar.isDateInToday(day)
                    let inMonth = calendar.isDate(day, equalTo: date, toGranularity: .month)
                    let daySessions = sessionsForDay(day)
                    let dayPatients = uniquePatientIds(from: daySessions, patients: Array(patientsById.values))

                    Button(action: {
                        onSelectDay(day)
                    }) {
                        VStack(spacing: 2) {
                            Text("\(calendar.component(.day, from: day))")
                                .font(.caption)
                                .foregroundColor(inMonth ? .primary : .gray)
                                .background(
                                    Circle()
                                        .fill(isToday ? Color.accentColor.opacity(0.3) : .clear)
                                        .frame(width: 28, height: 28)
                                )

                            HStack(spacing: 2) {
                                ForEach(dayPatients, id: \.self) { id in
                                    Circle()
                                        .fill(patientColor(id))
                                        .frame(width: 5, height: 5)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: 40)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding()
        .navigationTitle(date.formatted(Date.FormatStyle().month(.wide).year()))
    }

    // MARK: - Helpers

    private func sessionsForDay(_ day: Date) -> [TreatmentSessions] {
        sessions.filter { calendar.isDate($0.startTime, inSameDayAs: day) }
    }
    
    private func uniquePatientIds(from sessions: [TreatmentSessions], patients: [Patient]) -> [UUID] {
        let ids = sessions.compactMap { $0.resolvedPatientId(in: patients) }
        return Array(Set(ids)).sorted(by: { $0.uuidString < $1.uuidString })
    }

    private func patientColor(_ id: UUID) -> Color {
        let seed = id.hashValue
        let hue = Double(abs(seed % 360)) / 360.0
        return Color(hue: hue, saturation: 0.5, brightness: 0.9)
    }
}
