//
//  MonthCalendarView.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 14.04.25.
//

import SwiftUI

struct MonthCalendarView: View {
    @Binding var monthOf: Date
    @Binding var selectedDate: Date?
    @Binding var showDayView: Bool
    @Binding var dateRangeStart: Date
    @Binding var dateRangeEnd: Date
    @Binding var didAuthenticate: Bool

    @EnvironmentObject var availabilityStore: AvailabilityStore
    @EnvironmentObject var holidayStore: HolidayStore

    // Long-Press Popover-State
    @State private var showDayActions = false
    @State private var pendingDate: Date?

    private let cellHeight: CGFloat = 90
    private let kwColumnWidth: CGFloat = 32
    private let spacing: CGFloat = 1
    private let horizontalPadding: CGFloat = 8

    private var calendar: Calendar {
        var cal = Calendar(identifier: .iso8601)
        cal.firstWeekday = 2
        cal.locale = Locale.current
        return cal
    }

    private var weeks: [[Date]] {
        calendar.monthDates(for: monthOf, padded: true).chunked(into: 7)
    }

    var body: some View {
        VStack(spacing: 8) {
            // Monatskopf
            HStack {
                Text(monthOf.formatted(.dateTime.month(.wide).year()))
                    .font(.title3)
                    .fontWeight(.semibold)
                Spacer()
                Button(NSLocalizedString("today", comment: "Today")) {
                    withAnimation {
                        monthOf = Date()
                        selectedDate = Date()
                    }
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal)

            // Raster
            GeometryReader { geo in
                let totalWidth = geo.size.width - horizontalPadding * 2 - kwColumnWidth * 3
                let dayWidth = (totalWidth - spacing * 7) / 7
                let columns: [GridItem] =
                    [GridItem(.fixed(kwColumnWidth))] +
                    Array(repeating: GridItem(.fixed(dayWidth)), count: 7)

                LazyVGrid(columns: columns, spacing: spacing) {
                    // Header
                    Text(NSLocalizedString("cw", comment: "CW"))
                        .font(.caption2)
                        .frame(height: 20)
                        .foregroundColor(.secondary)

                    ForEach(0..<7, id: \.self) { i in
                        Text(calendar.shortWeekdaySymbols[(i + calendar.firstWeekday - 1) % 7])
                            .font(.caption)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .foregroundColor(.secondary)
                    }

                    // Wochen
                    ForEach(weeks, id: \.self) { week in
                        if let firstDay = week.first {
                            let kw = calendar.component(.weekOfYear, from: firstDay)
                            Text("\(kw)")
                                .font(.caption2)
                                .frame(height: cellHeight)
                                .foregroundColor(.secondary)
                                .padding(.top, 6)
                        }

                        ForEach(week, id: \.self) { date in
                            calendarCell(for: date, width: dayWidth)
                        }
                    }
                }
                .padding(.horizontal, horizontalPadding)
                .gesture(swipeGesture)
                .onAppear { holidayStore.refreshIfNeeded(for: monthOf) }
                .onChange(of: monthOf) { _, _ in
                    holidayStore.refreshIfNeeded(for: monthOf)
                }
            }
            .frame(minHeight: CGFloat(weeks.count + 1) * (cellHeight + spacing) + 20)
        }
    }

    // MARK: - Zelle

    private func calendarCell(for date: Date, width: CGFloat) -> some View {
        let isToday = calendar.isDateInToday(date)
        let isCurrentMonth = calendar.isDate(date, equalTo: monthOf, toGranularity: .month)
        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate ?? Date.distantPast)
        let weekday = calendar.component(.weekday, from: date)
        let isWeekend = (weekday == 1 || weekday == 7)

        let availability = availabilityStore.slots.filter { calendar.isDate($0.start, inSameDayAs: date) }
        let holiday = holidayStore.holiday(on: date)
        let isHoliday = holiday != nil

        return VStack(alignment: .center, spacing: 2) {
            calendarDayNumber(for: date, isToday: isToday, isCurrentMonth: isCurrentMonth)

            if let holiday {
                calendarHolidayView(holiday)
            }

            availabilityInfo(for: availability)
            Spacer()
        }
        .frame(width: width, height: cellHeight)
        .padding(4)
        .background(RoundedRectangle(cornerRadius: 0).fill(isWeekend ? Color.weekend.opacity(0.8) : Color.clear))
        .background(RoundedRectangle(cornerRadius: 0).fill(isHoliday ? Color.holiday.opacity(0.5) : Color.clear))
        .overlay(RoundedRectangle(cornerRadius: 0).stroke(Color.gray.opacity(0.2)))
        .background(isSelected ? Color.accentColor.opacity(0.8) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture { selectedDate = date }
        .onLongPressGesture {
            pendingDate = date
            showDayActions = true
        }
        .popover(
            isPresented: popoverBinding(for: date),
            attachmentAnchor: .rect(.bounds),
            arrowEdge: .top
        ) {
            DayActionsView(
                onDisplay: {
                    if let day = pendingDate {
                        selectedDate = day
                        showDayView = true
                    }
                    dismissPopover(for: date)
                },
                onFrom: {
                    if let day = pendingDate { dateRangeStart = day }
                    dismissPopover(for: date)
                },
                onUntil: {
                    if let day = pendingDate { dateRangeEnd = day }
                    dismissPopover(for: date)
                }
            )
            .frame(minWidth: 200)
            .padding(8)
        }
    }

    // MARK: - UI-Bausteine

    private func calendarDayNumber(for date: Date, isToday: Bool, isCurrentMonth: Bool) -> some View {
        Text("\(calendar.component(.day, from: date))")
            .font(.caption)
            .fontWeight(isToday ? .bold : .regular)
            .foregroundColor(isCurrentMonth ? .primary : .secondary)
            .frame(maxWidth: .infinity)
    }

    private func calendarHolidayView(_ holiday: HolidayCalendarEntry) -> some View {
        Text(holiday.name)
            .font(.caption2)
            .lineLimit(1)
            .truncationMode(.tail)
            .padding(2)
            .cornerRadius(0)
    }

    private func availabilityInfo(for slots: [AvailabilitySlot]) -> some View {
        VStack(spacing: 2) {
            ForEach(slots.indices, id: \.self) { index in
                let slot = slots[index]
                let start = slot.start.formatted(date: .omitted, time: .shortened)
                let end = slot.end.formatted(date: .omitted, time: .shortened)
                let components = Calendar.current.dateComponents([.hour, .minute], from: slot.start, to: slot.end)
                let hours = components.hour ?? 0
                let minutes = components.minute ?? 0
                let durationString = minutes == 0 ? "\(hours) h" : "\(hours) h \(minutes) min"

                Text("\(start) – \(end) • \(durationString)")
                    .font(.caption2)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .padding(3)
                    .frame(maxWidth: .infinity)
                    .background(Color.availability.opacity(0.8))
                    .cornerRadius(0)
            }
        }
    }

    // MARK: - Gesten

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 20)
            .onEnded { value in
                if value.translation.width < -20 {
                    withAnimation {
                        monthOf = calendar.date(byAdding: .month, value: 1, to: monthOf) ?? monthOf
                    }
                } else if value.translation.width > 20 {
                    withAnimation {
                        monthOf = calendar.date(byAdding: .month, value: -1, to: monthOf) ?? monthOf
                    }
                }
            }
    }

    // MARK: - Popover-Helfer

    private func popoverBinding(for date: Date) -> Binding<Bool> {
        Binding(
            get: { showDayActions && pendingDate == date },
            set: { presented in
                if !presented, pendingDate == date {
                    showDayActions = false
                    pendingDate = nil
                }
            }
        )
    }

    private func dismissPopover(for date: Date) {
        if pendingDate == date {
            showDayActions = false
            pendingDate = nil
        }
    }
}

// MARK: - Popover-Inhalt

struct DayActionsView: View {
    let onDisplay: () -> Void
    let onFrom: () -> Void
    let onUntil: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button(NSLocalizedString("display", comment: "Display"), action: onDisplay)
                .foregroundColor(.edit)
                .frame(maxWidth: .infinity, alignment: .center)

            Spacer()
            
            Button(NSLocalizedString("from", comment: "From"), action: onFrom)
                .foregroundColor(.edit)
                .frame(maxWidth: .infinity, alignment: .center)

            Spacer()
            
            Button(NSLocalizedString("until", comment: "Until"), action: onUntil)
                .foregroundColor(.edit)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(8)
    }
}
