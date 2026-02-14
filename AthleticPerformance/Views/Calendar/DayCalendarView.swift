//
//  DayCalendarView.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 14.04.25.
//

import SwiftUI

struct DayCalendarView: View {
    let date: Date?
    @Binding var didAuthenticate: Bool

    @EnvironmentObject var availabilityStore: AvailabilityStore
    @EnvironmentObject var holidayStore: HolidayStore
    @Environment(\.dismiss) private var dismiss

    private var calendar: Calendar { Calendar.current }
    private var displayDate: Date { date ?? Date() }

    @State private var editedSlots: [AvailabilitySlot] = []
    @State private var showEditor = false
    @State private var selectedSlot: AvailabilitySlot?

    let hourHeight: CGFloat = 60
    let hourStart = 8
    let hourEnd = 20

    var body: some View {
        ScrollView {
            ZStack(alignment: .topLeading) {
                // 🔹 Stundenraster
                VStack(spacing: 0) {
                    ForEach(hourStart...hourEnd, id: \.self) { hour in
                        HStack(alignment: .top) {
                            Text("\(hour):00")
                                .font(.caption)
                                .frame(width: 50, alignment: .trailing)
                                .padding(.top, -5)

                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(height: 1)
                        }
                        .frame(height: hourHeight, alignment: .top)
                    }
                }

                // 🔹 Verfügbarkeits-Blöcke
                ForEach(editedSlots) { slot in
                    if calendar.isDate(slot.start, inSameDayAs: displayDate) {
                        let y = yOffset(for: slot.start)
                        let h = height(for: slot)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.availability.opacity(0.8))
                            .frame(height: h)
                            .overlay(
                                Text(slotLabel(slot))
                                    .font(.caption2)
                                    .padding(4),
                                alignment: .topLeading
                            )
                            .frame(maxWidth: .infinity)
                            .padding(.leading, 60)
                            .offset(y: y)
                            .onTapGesture {
                                selectedSlot = slot
                                showEditor = true
                            }
                            .contextMenu {
                                Button("Bearbeiten") {
                                    selectedSlot = slot
                                    showEditor = true
                                }

                                Button("Löschen", role: .destructive) {
                                    editedSlots.removeAll { $0.id == slot.id }
                                    save()
                                }
                            }
                    }
                }
            }
            .padding(.top, 10)
            .padding(.bottom, 20)
        }
        .navigationTitle(displayDate.formatted(date: .long, time: .omitted))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    let start = calendar.date(bySettingHour: hourStart, minute: 0, second: 0, of: displayDate)!
                    let end = calendar.date(byAdding: .hour, value: 1, to: start)!
                    selectedSlot = AvailabilitySlot(start: start, end: end)
                    showEditor = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .onAppear(perform: load)
        .sheet(isPresented: $showEditor) {
            if let slot = selectedSlot {
                SlotEditorView(slot: slot, didAuthenticate: $didAuthenticate) { updated in
                    mergeSlot(updated)
                    showEditor = false
                }
            }
        }
    }

    // MARK: - Hilfsmethoden

    private func load() {
        editedSlots = availabilityStore.slots
            .filter { calendar.isDate($0.start, inSameDayAs: displayDate) }
            .sorted(by: { $0.start < $1.start })
    }

    private func save() {
        let others = availabilityStore.slots.filter {
            !calendar.isDate($0.start, inSameDayAs: displayDate)
        }
        availabilityStore.slots = (others + editedSlots).sorted(by: { $0.start < $1.start })
        availabilityStore.save()
    }

    private func slotLabel(_ slot: AvailabilitySlot) -> String {
        let start = slot.start.formatted(date: .omitted, time: .shortened)
        let end = slot.end.formatted(date: .omitted, time: .shortened)
        return "\(start) – \(end)"
    }

    private func yOffset(for date: Date) -> CGFloat {
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        let totalMinutes = (hour - hourStart) * 60 + minute
        return CGFloat(totalMinutes) * hourHeight / 60
    }

    private func height(for slot: AvailabilitySlot) -> CGFloat {
        let components = calendar.dateComponents([.minute], from: slot.start, to: slot.end)
        return CGFloat(components.minute ?? 0) * hourHeight / 60
    }

    private func mergeSlot(_ newSlot: AvailabilitySlot) {
        // 1. Entferne den alten Slot mit gleicher ID (falls vorhanden)
        editedSlots.removeAll { $0.id == newSlot.id }

        // 2. Finde überlappende Slots
        let overlapping = editedSlots.filter {
            $0.start < newSlot.end && $0.end > newSlot.start
        }

        // 3. Entferne diese überlappenden Slots
        editedSlots.removeAll { slot in
            overlapping.contains(where: { $0.id == slot.id })
        }

        // 4. Berechne neue gemeinsame Zeitspanne
        let mergedStart = ([newSlot] + overlapping).map { $0.start }.min()!
        let mergedEnd = ([newSlot] + overlapping).map { $0.end }.max()!

        // 5. Erstelle neuen Slot mit ursprünglicher ID
        let mergedSlot = AvailabilitySlot(id: newSlot.id, start: mergedStart, end: mergedEnd)
        editedSlots.append(mergedSlot)
        editedSlots.sort(by: { $0.start < $1.start })

        save()
    }
}
