//
//  WeekCalendarView.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 14.04.25.
//

import SwiftUI

struct WeekCalendarView: View {
    let weekOf: Date
    @State private var selectedDate: Date = Date()

    @EnvironmentObject var availabilityStore: AvailabilityStore
    @EnvironmentObject var holidayStore: HolidayStore

    var body: some View {
        let calendar = Calendar.current
        let days = calendar.weekDates(containing: weekOf)

        VStack(spacing: 0) {
            // 🔹 Horizontale Tagesleiste
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(days, id: \.self) { date in
                        let isToday = calendar.isDateInToday(date)
                        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)

                        VStack(spacing: 4) {
                            Text(date.formatted(.dateTime.weekday(.narrow)))
                            Text("\(calendar.component(.day, from: date))")
                                .fontWeight(isToday ? .bold : .regular)
                        }
                        .padding(8)
                        .frame(width: 44)
                        .background(
                            Circle()
                                .fill(isSelected ? Color.accentColor.opacity(0.3) : .clear)
                        )
                        .onTapGesture {
                            selectedDate = date
                        }
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical, 6)

            Divider()
            .background(Color.divider.opacity(0.5))

            // 🔹 Stundenraster mit Inhalten
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(8..<21, id: \.self) { hour in
                        HStack(alignment: .top) {
                            // Uhrzeit links
                            Text(String(format: "%02d:00", hour))
                                .font(.caption)
                                .frame(width: 50, alignment: .trailing)

                            // Inhalt rechts
                            ZStack(alignment: .leading) {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.05))
                                    .frame(height: 40)

                                // Verfügbarkeit anzeigen
                                if slotExists(at: hour, on: selectedDate) {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.availability.opacity(0.3))
                                        .frame(height: 36)
                                        .padding(.vertical, 2)
                                }
                            }
                        }
                    }

                    // Feiertag anzeigen
                    if let holiday = holidayStore.holiday(on: selectedDate) {
                        HStack(alignment: .top) {
                            Text("")
                                .frame(width: 50)
                            Text(holiday.name)
                                .font(.caption)
                                .padding(6)
                                .background(Color.holiday.opacity(0.2))
                                .cornerRadius(6)
                                .padding(.top, 10)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }
        }
    }

    private func slotExists(at hour: Int, on date: Date) -> Bool {
        let calendar = Calendar.current
        return availabilityStore.slots.contains { slot in
            calendar.isDate(slot.start, inSameDayAs: date) &&
            calendar.component(.hour, from: slot.start) <= hour &&
            calendar.component(.hour, from: slot.end) > hour
        }
    }
}
