//
//  AvailabilityEditorView.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 16.04.25.
//

import SwiftUI
import LocalAuthentication

struct AvailabilityEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTherapistId: UUID = AppGlobals.shared.therapistId ?? UUID()
    @StateObject private var holidayStore = HolidayStore()
    @StateObject private var availabilityStore = AvailabilityStore(
        therapistId: "0",
        baseDirectory: FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    )
    
    @State private var selectedDateRange: ClosedRange<Date>? = nil
    @State private var startTime = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date())!
    @State private var endTime = Calendar.current.date(bySettingHour: 17, minute: 0, second: 0, of: Date())!
    
    @State private var dateRangeStart: Date = Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: 1, day: 1))!
    @State private var dateRangeEnd: Date = Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: 12, day: 31))!
    
    @State private var showDayView = false
    @State private var selectedDate: Date? = Date()
    @State private var currentMonth: Date = Date()
    @State private var didAuthenticateThisSession = false
    @State private var showDeleteConfirmation = false
    @State private var pendingMergedSlots: [(day: Date, newSlot: AvailabilitySlot, toRemove: [AvailabilitySlot])] = []
    @State private var showMergeConfirmation = false
    
    var body: some View {
        VStack(spacing: 15) {
            MonthCalendarView(
                monthOf: $currentMonth,
                selectedDate: $selectedDate,
                showDayView: $showDayView,
                dateRangeStart: $dateRangeStart,
                dateRangeEnd: $dateRangeEnd,
                didAuthenticate: $didAuthenticateThisSession
            )
            .environmentObject(availabilityStore)
            .environmentObject(holidayStore)
            .onAppear {
                updateStoreForSelectedTherapist()
                holidayStore.refreshIfNeeded(for: currentMonth)
                mergeAllDays()
            }
            
            Divider()
            .background(Color.divider.opacity(0.5))
            
            GroupBox {
                VStack(alignment: .leading, spacing: 15) {
                    HStack {
                        Text(NSLocalizedString("maintainAvailabilityFor", comment: "Maintain availability for"))
                            .font(.headline)
                        Picker("", selection: $selectedTherapistId) {
                            ForEach(AppGlobals.shared.therapistList, id: \ .id) { therapist in
                                Text(therapist.fullName).tag(therapist.id)
                            }
                        }
                        .labelsHidden()
                        .frame(maxWidth: 200)
                    }
                                        
                    HStack(spacing: 8) {
                        Text(NSLocalizedString("period", comment: "Period"))
                            .frame(width: 110, alignment: .leading)
                        
                        DatePicker("", selection: $dateRangeStart, displayedComponents: .date)
                            .labelsHidden()
                            .fixedSize()
                            .onChange(of: dateRangeStart) { oldStart, newStart in
                                let cal = Calendar.current
                                let newYear = cal.component(.year, from: newStart)
                                let currentEndYear = cal.component(.year, from: dateRangeEnd)
                                
                                // Nur wenn das Jahr sich ändert, Enddatum neu setzen:
                                if newYear != currentEndYear {
                                    dateRangeEnd = endOfYear(for: newStart)
                                }
                            }
                        
                        Text("–")
                        
                        DatePicker("", selection: $dateRangeEnd, displayedComponents: .date)
                            .labelsHidden()
                            .fixedSize()
                        
                        Spacer()
                        
                        Text(NSLocalizedString("therapyTime", comment: "Therapy time"))
                            .frame(width: 110, alignment: .leading)
                        
                        DatePicker("", selection: $startTime, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                            .fixedSize()
                        
                        Text("–")
                        
                        DatePicker("", selection: $endTime, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                            .fixedSize()
                        
                        Spacer()
                    }
                    
                    HStack {
                        Button {
                            authenticateIfNeeded {
                                    selectedDateRange = dateRangeStart...dateRangeEnd
                                    addSlots()
                                }
                        } label: {
                            Label("", systemImage: "plus.circle.fill")
                                .foregroundColor(.addButton)
                        }
                        
                        Spacer()
                        
                        Button {
                            authenticateIfNeeded {
                                    selectedDateRange = dateRangeStart...dateRangeEnd
                                    deleteSlots()
                                }
                        } label: {
                            Label("", systemImage: "minus.circle.fill")
                                .foregroundColor(.deleteButton)
                        }
                    }
                }
                .padding(.horizontal)
            } label: {
                EmptyView()
            }
            .padding(.top)
        }
        .padding()
        .navigationTitle(NSLocalizedString("availability", comment: "Availability"))
        .sheet(isPresented: Binding(get: {
            showDayView && !availabilityStore.slots.isEmpty
        }, set: {
            showDayView = $0
        })) {
            NavigationStack {
                DayCalendarView(date: selectedDate, didAuthenticate: $didAuthenticateThisSession)
                    .environmentObject(availabilityStore)
                    .environmentObject(holidayStore)
            }
        }
        .onChange(of: selectedTherapistId) {
            updateStoreForSelectedTherapist()
        }
        .onDisappear {
            didAuthenticateThisSession = false
        }
        .alert(NSLocalizedString("reallyDeleteAvailabilities", comment: "Really delete availabilities?"), isPresented: $showDeleteConfirmation) {
            Button(NSLocalizedString("delete", comment: "Delete"), role: .destructive) {
                confirmDelete()
            }
            
            
            Button(NSLocalizedString("cancel", comment: "Cancel"), role: .cancel) {}
        } message: {
            Text(NSLocalizedString("availabilitiesWillBeDeleted", comment: "Availabilities will be deleted"))
        }
        .alert(NSLocalizedString("overwriteAvailabilities", comment: "Overwrite availabilities?"), isPresented: $showMergeConfirmation) {
            Button(NSLocalizedString("continue", comment: "Continue"), role: .destructive) {
                confirmSlotMerges()
            }
            Button(NSLocalizedString("cancel", comment: "Cancel"), role: .cancel) {
                pendingMergedSlots = []
            }
        } message: {
            Text(NSLocalizedString("mergeAvailabilities", comment: "Merge availabilities"))
        }
    }
    
    private func addSlots() {
        guard let dateRange = selectedDateRange else { return }
        let calendar = Calendar.current
        let days = calendar.generateDates(from: dateRange.lowerBound, to: dateRange.upperBound)
        var newMergedSlots: [(Date, AvailabilitySlot, [AvailabilitySlot])] = []

        for day in days {
            let weekday = calendar.component(.weekday, from: day)
            let isWeekend = weekday == 1 || weekday == 7
            let isHoliday = holidayStore.holidays.contains { calendar.isDate($0.date, inSameDayAs: day) }

            if isWeekend || isHoliday { continue }

            let start = calendar.combine(date: day, time: startTime)
            let end = calendar.combine(date: day, time: endTime)

            let slotsForDay = availabilityStore.slots.filter {
                calendar.isDate($0.start, inSameDayAs: day)
            }

            if slotsForDay.contains(where: { $0.start == start && $0.end == end }) {
                continue
            }

            let overlapping = slotsForDay.filter { $0.start < end && $0.end > start }

            if overlapping.isEmpty {
                availabilityStore.addOrUpdate(AvailabilitySlot(start: start, end: end))
            } else {
                // Prüfe, ob der neue Slot komplett innerhalb eines bestehenden liegt → als Update erlauben
                let exactMatch = overlapping.contains { $0.start == start && $0.end == end }

                if exactMatch {
                    continue
                } else {
                    // Wenn der neue Slot kleiner oder teilweise anders ist, ersetze
                    let merged = AvailabilitySlot(start: start, end: end)
                    newMergedSlots.append((day, merged, overlapping))
                }
            }
        }

        // Wenn etwas zu bestätigen ist
        if !newMergedSlots.isEmpty {
            pendingMergedSlots = newMergedSlots
            showMergeConfirmation = true
        } else {
            mergeAllDays()
            availabilityStore.save()
        }
    }
    
    private func confirmSlotMerges() {
        for (_, newSlot, toRemove) in pendingMergedSlots {
            availabilityStore.slots.removeAll { slot in toRemove.contains(where: { $0.id == slot.id }) }
            availabilityStore.addOrUpdate(newSlot)
        }

        pendingMergedSlots = []
        mergeAllDays()
        availabilityStore.save()
    }
    
    private func deleteSlots() {
        showDeleteConfirmation = true
    }

    private func confirmDelete() {
        guard let dateRange = selectedDateRange else { return }
        let calendar = Calendar.current
        let inclusiveEnd = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: dateRange.upperBound) ?? dateRange.upperBound
        availabilityStore.deleteInRange(from: dateRange.lowerBound, to: inclusiveEnd)
        availabilityStore.save()
    }
    
    private func updateStoreForSelectedTherapist() {
        availabilityStore.slots = []
        availabilityStore.setTherapist(id: selectedTherapistId)
        availabilityStore.load()
    }
    
    // 🔄 Einzelner Tag: Alle Slots dieses Tages mergen
    private func mergeOverlappingSlots(for day: Date) {
        let calendar = Calendar.current
        let slotsForDay = availabilityStore.slots
            .filter { calendar.isDate($0.start, inSameDayAs: day) }
            .sorted(by: { $0.start < $1.start })
        
        var merged: [AvailabilitySlot] = []
        for slot in slotsForDay {
            if let last = merged.last, last.end >= slot.start {
                let updated = AvailabilitySlot(start: last.start, end: max(last.end, slot.end))
                merged.removeLast()
                merged.append(updated)
            } else {
                merged.append(slot)
            }
        }
        
        availabilityStore.slots.removeAll { calendar.isDate($0.start, inSameDayAs: day) }
        availabilityStore.slots.append(contentsOf: merged)
    }
    
    // 🔁 Alle Tage durchlaufen und mergen
    private func mergeAllDays() {
        let calendar = Calendar.current
        let uniqueDays: Set<Date> = Set(
            availabilityStore.slots.map { calendar.startOfDay(for: $0.start) }
        )
        
        for day in uniqueDays {
            mergeOverlappingSlots(for: day)
        }
    }

    private func authenticateIfNeeded(successHandler: @escaping () -> Void) {
        // Wenn bereits authentifiziert → direkt ausführen
        if didAuthenticateThisSession {
            successHandler()
            return
        }

        let context = LAContext()
        var error: NSError?

        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: NSLocalizedString("editAvailabilityReason", comment: "Authorize editing availabilities")
            ) { success, _ in
                if success {
                    DispatchQueue.main.async {
                        didAuthenticateThisSession = true
                        successHandler()
                    }
                } else {
                    // optional: zeige Feedback bei Abbruch
                }
            }
        } else {
            // Optional: Fallback oder Hinweis anzeigen
            showErrorAlert(errorMessage: String(
                format: NSLocalizedString("errorAuthentification", comment: "Authentication error")
            ))
        }
    }
    
    private func endOfYear(for date: Date) -> Date {
        let cal = Calendar.current
        let year = cal.component(.year, from: date)
        let components = DateComponents(
            year: year,
            month: 12,
            day: 31,
            hour: 23,
            minute: 59,
            second: 59
        )
        return cal.date(from: components)!
    }
}

