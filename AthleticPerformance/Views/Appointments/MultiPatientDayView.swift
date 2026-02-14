//
//  MultiPatientDayView.swift
//  AthleticPerformance
//
//  Created by Frank Ufer on 13.06.25.
//

import SwiftUI

struct MultiPatientDayView: View {
    let date: Date
    let sessions: [TreatmentSessions]
    let patientColors: [UUID: Color]
    let patientsById: [UUID: Patient]
    let selectedPatientIds: Set<UUID>
    let onSelectDay: (Date) -> Void
    let onPreviousWeek: () -> Void
    let onNextWeek: () -> Void
    @AppStorage("showAllDaySessions") private var showAllDaySessions = true

    @State private var selectedDay: Date
    @State private var selectedSession: TreatmentSessions? = nil
    @EnvironmentObject var patientStore: PatientStore

    init(
        date: Date,
        sessions: [TreatmentSessions],
        patientsById: [UUID: Patient],
        onSelectDay: @escaping (Date) -> Void,
        onPreviousWeek: @escaping () -> Void,
        onNextWeek: @escaping () -> Void,
        selectedPatientIds: Set<UUID> = [],
        patientColors: [UUID: Color] = [:]
    ) {
        self.date = date
        self.sessions = sessions
        self.patientsById = patientsById
        self.onSelectDay = onSelectDay
        self.onPreviousWeek = onPreviousWeek
        self.onNextWeek = onNextWeek
        _selectedDay = State(initialValue: {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone.current
            let components = calendar.dateComponents([.year, .month, .day], from: date)
            return calendar.date(from: components)!
        }())
        self.selectedPatientIds = selectedPatientIds
        self.patientColors = patientColors
    }

    private let hours = Array(8...20)
    private let calendar = Calendar.current

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                headerView
                weekDaySelector
                Divider()
                
                ScrollView {
                    ZStack(alignment: .topLeading) {
                        // Stundenraster
                        VStack(spacing: 0) {
                            ForEach(hours, id: \.self) { hour in
                                HStack(alignment: .top) {
                                    Text(String(format: "%02d:00", hour))
                                        .font(.caption)
                                        .frame(width: 40, alignment: .trailing)
                                        .padding(.trailing, 4)
                                    Rectangle()
                                        .fill(Color.gray.opacity(0.05))
                                        .frame(height: 60)
                                        .overlay(Rectangle().frame(height: 0.5).foregroundColor(.gray.opacity(0.3)), alignment: .top)
                                }
                            }
                        }
                        
                        let sessionsThisWeek = allSessionsForWeek(from: sessions, around: selectedDay)
                        let sessionsForDay = sessionsThisWeek.filter {
                            calendar.isDate($0.startTime, inSameDayAs: selectedDay)   // ← kein patientId-Filter!
                        }

                        // Sitzungsblöcke
                        GeometryReader { _ in
                            ForEach(sessionsForDay, id: \.id) { session in
                                // Patient robust auflösen (direkt oder über Fallback-Suche)
                                let pid = session.patientId ?? session.resolvedPatientId(in: Array(patientsById.values))

                                if let pid {
                                    let hasSelection = !selectedPatientIds.isEmpty
                                    let isSelected   = hasSelection && selectedPatientIds.contains(pid)
                                    let showGray     = !hasSelection || (!isSelected && showAllDaySessions)

                                    if isSelected || showGray {
                                        let name  = patientsById[pid]?.fullName ?? "Unbekannt"
                                        let color: Color = isSelected ? (patientColors[pid] ?? .blue) : Color.gray.opacity(0.7)
                                        let textColor: Color = isSelected ? color.accessibleFontColor() : .black

                                        let offset = offsetForSession(session)
                                        let height = CGFloat(session.duration / 3600.0) * 60

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(name).font(.caption2).bold().lineLimit(1)
                                            Text(session.address.city).font(.caption2).lineLimit(1)
                                            Text(session.title).font(.caption2).lineLimit(1)
                                            
                                            if let s = session.serialNumber {
                                                Text("(\(s.current) / \(s.total))")
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
                                        .padding(.leading, 48)
                                        .onTapGesture {
                                            if selectedSession?.id == session.id {
                                                selectedSession = nil
                                            } else {
                                                selectedSession = session
                                            }
                                        }
                                        .help("\(session.startTime.formatted(date: .omitted, time: .shortened)) – \(session.endTime.formatted(date: .omitted, time: .shortened))")
                                    }
                                }
                            }
                        }
                    }
                    .padding(.leading, 0)
                    .padding(.trailing, 8)
                }
                .onChange(of: date) { _, newValue in
                    selectedDay = Calendar.current.startOfDay(for: newValue)
                }
            }
            .frame(maxWidth: .infinity)
            
            // Rechte Detailansicht (wenn ein Termin ausgewählt ist)
            if let selectedSession {
                let resolvedPatientId = selectedSession.resolvedPatientId(in: Array(patientsById.values))
                Divider()
                TreatmentSessionDetailView(
                    session: selectedSession,
                    patientId: resolvedPatientId,
                    allServices: AppGlobals.shared.treatmentServices,
                    therapists: AppGlobals.shared.therapistList,
                    patientsById: patientsById
                )
                .frame(width: 340)
            }
        }
    }
    
    private func sessionBlock(for session: TreatmentSessions, patient: Patient, startOffset: CGFloat, blockHeight: CGFloat) -> some View {
        let bgColor = patientColor(patient.id)
        let textColor = bgColor.accessibleFontColor()

        return VStack(alignment: .leading, spacing: 2) {
            Text(patient.fullName)
                .font(.caption2)
                .lineLimit(1)
            Text(session.address.city)
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
        .padding(4)
        .background(bgColor)
        .cornerRadius(6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: blockHeight)
        .offset(y: startOffset)
        .padding(.leading, 48)
    }
   
    private func extraSessionBlock(
        for session: TreatmentSessions,
        patientName: String,
        startOffset: CGFloat,
        blockHeight: CGFloat
    ) -> some View {
        
        VStack(alignment: .leading, spacing: 2) {
            Text(patientName)
                .font(.caption2)
                .lineLimit(1)
            Text(session.address.city)
                .font(.caption2)
                .lineLimit(1)
            if let serial = session.serialDisplay {
                Text(serial)
                    .font(.caption2)
                    .monospacedDigit()
                    .lineLimit(1)
            }
        }
        .foregroundColor(.black)
        .padding(4)
        .background(Color.gray.opacity(0.7))
        .cornerRadius(6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: blockHeight)
        .offset(y: startOffset)
        .padding(.leading, 48)
    }
    
    private var headerView: some View {
        HStack {
            Text("KW \(calendar.component(.weekOfYear, from: selectedDay))")
                .font(.caption)
                .padding(.leading)

            Spacer()

            Text(selectedDay.formatted(.dateTime.weekday(.wide).day().month(.wide).year()))
                .font(.headline)

            Spacer()

            HStack(spacing: 25) {
                // Button zum Anzeigen heutiges Datum, nur falls nötig
                if !calendar.isDateInToday(selectedDay) {
                    Button {
                        selectedDay = calendar.startOfDay(for: Date())
                        onSelectDay(selectedDay)
                    } label: {
                        Image(systemName: "calendar.circle")
                    }
                    .help(NSLocalizedString("showToday", comment: "Show today"))
                }
                
                Button {
                    showAllDaySessions.toggle()
                } label: {
                    Image(systemName: showAllDaySessions ? "eye.slash" : "eye")
                }

                Button(action: onPreviousWeek) {
                    Image(systemName: "chevron.left")
                }
                Button(action: onNextWeek) {
                    Image(systemName: "chevron.right")
                }
            }
            .padding(.trailing)
        }
        .padding(.vertical, 8)
    }

    private var weekDaySelector: some View {
        let startOfWeek = calendar.fixedStartOfWeek(for: selectedDay)

        return HStack(spacing: 30) {
            ForEach(0..<7, id: \.self) { offset in
                let day = calendar.date(byAdding: .day, value: offset, to: startOfWeek)!
                let isSelected = calendar.isDate(day, inSameDayAs: selectedDay)

                VStack(spacing: 4) {
                    Text(day.formatted(.dateTime.weekday(.narrow)))
                        .font(.caption2)

                    Text(String(calendar.component(.day, from: day)))
                        .font(.body.bold())
                        .foregroundColor(isSelected ? .white : .primary)
                        .frame(width: 28, height: 28)
                        .background(isSelected ? Color.accentColor : Color.clear)
                        .clipShape(Circle())
                }
                .onTapGesture {
                    selectedDay = day
                    onSelectDay(day)
                }
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 4)
    }
       
    private func offsetForSession(_ session: TreatmentSessions) -> CGFloat {
        let components = calendar.dateComponents([.hour, .minute], from: session.startTime)
        guard let hour = components.hour, let minute = components.minute else { return 0 }
        let baseOffset = CGFloat(hour - 8) * 60
        return baseOffset + CGFloat(minute)
    }

    private func patientColor(_ id: UUID) -> Color {
        let hue = Double(abs(id.hashValue % 360)) / 360.0
        return Color(hue: hue, saturation: 0.5, brightness: 0.9)
    }
           
    private func allSessionsForWeek(from sessions: [TreatmentSessions], around date: Date) -> [TreatmentSessions] {
        let calendar = Calendar.current
        let weekStart = calendar.startOfWeek(for: date)
        let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart)!

        return sessions.filter { session in
            !session.draft &&
            session.startTime >= weekStart &&
            session.startTime < weekEnd
        }
    }
}

extension Color {
    func accessibleFontColor() -> Color {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0
        #if os(iOS)
        if UIColor(self).getRed(&red, green: &green, blue: &blue, alpha: nil) {
            let brightness = (red * 299 + green * 587 + blue * 114) / 1000
            return brightness > 0.5 ? .black : .white
        }
        #endif
        return .primary
    }
}

extension Calendar {
    func fixedStartOfWeek(for date: Date) -> Date {
        var calendar = self
        calendar.firstWeekday = 2 // Montag
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return calendar.date(from: components) ?? date
    }
}
