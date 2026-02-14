//
//  CalendarWeekView.swift
//  AthleticPerformance
//
//  Created by Frank Ufer on 13.06.25.
//

import SwiftUI

struct MultiPatientWeekView: View {
    @Binding var currentDate: Date
    let sessions: [TreatmentSessions]
    let patientColors: [UUID: Color]
    let patientsById: [UUID: Patient]
    let selectedPatientIds: Set<UUID>
    let onSelectDay: (Date) -> Void
    let onPreviousWeek: () -> Void
    let onNextWeek: () -> Void

    @State private var selectedDay: Date
    @State private var selectedSession: TreatmentSessions?
    @EnvironmentObject var patientStore: PatientStore
    @AppStorage("showAllDaySessions") private var showAllDaySessions = true

    private let hours = Array(8...20)
    private let calendar = Calendar.current
    private var startOfWeek: Date {
        calendar.startOfWeek(for: currentDate)
    }

    // Standard SwiftUI init reicht – kein eigenes init nötig
    init(
        currentDate: Binding<Date>,
        sessions: [TreatmentSessions],
        patientColors: [UUID: Color],
        patientsById: [UUID: Patient],
        selectedPatientIds: Set<UUID>,
        onSelectDay: @escaping (Date) -> Void,
        onPreviousWeek: @escaping () -> Void,
        onNextWeek: @escaping () -> Void
    ) {
        self._currentDate = currentDate
        self.sessions = sessions
        self.patientColors = patientColors
        self.patientsById = patientsById
        self.selectedPatientIds = selectedPatientIds
        self.onSelectDay = onSelectDay
        self.onPreviousWeek = onPreviousWeek
        self.onNextWeek = onNextWeek
        _selectedDay = State(initialValue: {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone.current
            let components = calendar.dateComponents([.year, .month, .day], from: currentDate.wrappedValue)
            return calendar.date(from: components)!
        }())
    }

    var body: some View {
        // ✅ Einmalige Berechnung aller Sessions dieser Woche
        let sessionsThisWeek = allSessionsForWeek(from: sessions, around: selectedDay)

        VStack(spacing: 0) {
            headerView
            gridHeader
            Divider()

            ScrollView {
                HStack(alignment: .top, spacing: 0) {
                    // Stundenachse
                    VStack(spacing: 0) {
                        ForEach(hours, id: \.self) { hour in
                            Text(String(format: "%02d:00", hour))
                                .font(.caption2)
                                .frame(height: 60, alignment: .top)
                                .padding(.trailing, 2)
                        }
                    }
                    .frame(width: 40)

                    // Wochenspalten
                    ForEach(0..<7, id: \.self) { offset in
                        let date = calendar.date(byAdding: .day, value: offset, to: startOfWeek)!
                        dayColumn(for: date, sessionsThisWeek: sessionsThisWeek)
                            .frame(maxWidth: .infinity)
                    }
                    .id(showAllDaySessions)
                }
            }
        }
        .sheet(item: $selectedSession) { session in
            SessionDetailView(
                session: session,
                patientsById: patientsById
            )
            .presentationDetents([.large])
        }
        .onChange(of: currentDate) { _, newDate in
            selectedDay = calendar.startOfDay(for: calendar.startOfWeek(for: newDate))
        }
    }

    private var headerView: some View {
        HStack {
            Text("KW \(calendar.component(.weekOfYear, from: selectedDay))")
                .font(.caption)
                .padding(.leading)

            Spacer()

            Text(startOfWeek.formatted(.dateTime.month(.wide).year()))
                .font(.headline)

            Spacer()

            HStack(spacing: 20) {
                if !calendar.isDateInToday(selectedDay) {
                    Button {
                        let today = calendar.startOfDay(for: Date())
                        selectedDay = today
                        onSelectDay(today)
                    } label: {
                        Image(systemName: "calendar.circle")
                    }
                    .help("Heute anzeigen")
                }

                Button {
                    showAllDaySessions.toggle()
                } label: {
                    Image(systemName: showAllDaySessions ? "eye.slash" : "eye")
                }
                .help("Andere Termine ein-/ausblenden")

                Button(action: onPreviousWeek) {
                    Image(systemName: "chevron.left")
                }
                .help("Vorherige Woche")

                Button(action: onNextWeek) {
                    Image(systemName: "chevron.right")
                }
                .help("Nächste Woche")
            }
            .padding(.trailing)
        }
        .padding(.vertical, 8)
    }

    private var gridHeader: some View {
        HStack(spacing: 0) {
            Spacer().frame(width: 40) // Platz für Stundenachse
            ForEach(0..<7, id: \.self) { offset in
                let date = calendar.date(byAdding: .day, value: offset, to: startOfWeek)!
                let isSelected = calendar.isDate(date, inSameDayAs: selectedDay)

                VStack(spacing: 2) {
                    Text(date.formatted(.dateTime.weekday(.narrow)))
                        .font(.caption2)
                    Text(String(calendar.component(.day, from: date)))
                        .font(.body.bold())
                        .foregroundColor(isSelected ? .white : .primary)
                        .frame(width: 28, height: 28)
                        .background(isSelected ? Color.accentColor : Color.clear)
                        .clipShape(Circle())
                }
                .frame(maxWidth: .infinity)
                .onTapGesture {
                    selectedDay = date
                    onSelectDay(date)
                }
            }
        }
        .padding(.horizontal, 4)
        .padding(.bottom, 4)
    }

    private func dayColumn(for date: Date, sessionsThisWeek: [TreatmentSessions]) -> some View {
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                ForEach(hours, id: \.self) { _ in
                    Rectangle()
                        .fill(Color.gray.opacity(0.05))
                        .frame(height: 60)
                        .overlay(
                            Rectangle()
                                .frame(height: 0.5)
                                .foregroundColor(.gray.opacity(0.3)),
                            alignment: .top
                        )
                }
            }

            let sessionsForDay = sessionsThisWeek.filter {
                        calendar.isDate($0.startTime, inSameDayAs: date)   // kein patientId-Filter
                    }

                    ForEach(sessionsForDay, id: \.id) { session in
                        // patientId robust auflösen
                        let pid = session.patientId ?? session.resolvedPatientId(in: Array(patientsById.values))

                        if let pid {
                            let hasSelection = !selectedPatientIds.isEmpty
                            let isSelected   = hasSelection && selectedPatientIds.contains(pid)
                            // Wenn keine Selektion: immer grau anzeigen
                            // Wenn Selektion: andere Patienten nur grau, wenn Toggle an
                            let showGray     = !hasSelection || (!isSelected && showAllDaySessions)

                            if isSelected || showGray {
                                let name  = patientsById[pid]?.fullName
                                    ?? PatientStore.shared.patients.first(where: { $0.id == pid })?.fullName
                                    ?? "Unbekannt"

                                let color: Color = isSelected
                                    ? (patientColors[pid] ?? .blue)
                                    : Color.gray.opacity(0.7)
                                let textColor: Color = isSelected ? color.accessibleFontColor() : .black

                                let offset = yOffset(for: session)
                                let height = CGFloat(session.duration / 3600.0) * 60
            
                        VStack(alignment: .leading, spacing: 2) {
                            Text(name)
                                .font(.caption2)
                                .bold()
                                .lineLimit(1)

                            Text(session.address.city)
                                .font(.caption2)
                                .lineLimit(1)
                            
                            Text(session.title)
                                .font(.caption2)
                                .lineLimit(1)
                            
                            if let serial = session.serialDisplay {
                                Text(serial)
                                    .font(.caption2)
                                    .monospacedDigit()
                                    .lineLimit(1)
                            }
                        }
                        .foregroundColor(textColor)
                        .padding(.horizontal, 4)
                        .background(color)
                        .cornerRadius(4)
                        .frame(height: height, alignment: .top)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .offset(y: offset)
                        .onTapGesture {
                            selectedSession = session
                        }
                        .help("\(session.startTime.formatted(date: .omitted, time: .shortened)) – \(session.endTime.formatted(date: .omitted, time: .shortened))")
                    }
                }
            }
            .padding(.horizontal, 1)
        }
    }

    private func yOffset(for session: TreatmentSessions) -> CGFloat {
        let comps = calendar.dateComponents([.hour, .minute], from: session.startTime)
        let hour = comps.hour ?? 8
        let minute = comps.minute ?? 0
        return CGFloat(hour - 8) * 60 + CGFloat(minute)
    }

    
    private func allSessionsForWeek(from sessions: [TreatmentSessions], around date: Date) -> [TreatmentSessions] {
        let calendar = Calendar.current
        let weekStart = calendar.startOfWeek(for: date)
        let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart)!

        let filtered = sessions.filter { session in
            !session.draft &&
            session.startTime >= weekStart &&
            session.startTime < weekEnd
        }

        return filtered
    }
}

struct SessionDetailView: View {
    let session: TreatmentSessions
    let patientsById: [UUID: Patient] 
    var body: some View {
        let resolvedPatientId = session.resolvedPatientId(in: Array(patientsById.values))
        TreatmentSessionDetailView(
            session: session,
            patientId: resolvedPatientId,
            allServices: AppGlobals.shared.treatmentServices,
            therapists: AppGlobals.shared.therapistList,
            patientsById: patientsById
        )
    }
}
