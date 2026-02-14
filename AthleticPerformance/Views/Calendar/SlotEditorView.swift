//
//  SlotEditorView.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 17.04.25.
//

import SwiftUI
import LocalAuthentication

struct SlotEditorView: View {
    @Binding var didAuthenticate: Bool
    @Environment(\.dismiss) private var dismiss
    @State private var start: Date
    @State private var end: Date
    private let originalID: UUID
    let onSave: (AvailabilitySlot) -> Void
    
    private var calendar: Calendar { Calendar.current }
    
    // Start- und Endzeitbegrenzung (08:00 – 20:00)
    private var minDate: Date {
        calendar.date(bySettingHour: 8, minute: 0, second: 0, of: start) ?? start
    }
    
    private var maxDate: Date {
        calendar.date(bySettingHour: 20, minute: 0, second: 0, of: start) ?? end
    }
    
    private var isValid: Bool {
        start < end && start >= minDate && end <= maxDate
    }
    
    init(
        slot: AvailabilitySlot,
        didAuthenticate: Binding<Bool>, // <- Hier als Binding übergeben
        onSave: @escaping (AvailabilitySlot) -> Void
    ) {
        self._didAuthenticate = didAuthenticate // <- Binding korrekt zuweisen
        self._start = State(initialValue: slot.start)
        self._end = State(initialValue: slot.end)
        self.originalID = slot.id
        self.onSave = onSave
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text(NSLocalizedString("time", comment: "Time"))) {
                    DatePicker(NSLocalizedString("from", comment: "From"), selection: $start, in: minDate...maxDate, displayedComponents: .hourAndMinute)
                    DatePicker(NSLocalizedString("until", comment: "Until"), selection: $end, in: minDate...maxDate, displayedComponents: .hourAndMinute)
                }
                
                if !isValid {
                    Text(NSLocalizedString("errorTimeOrder", comment: "Error time order"))
                        .foregroundColor(.negativeCheck)
                        .font(.caption)
                }
            }
            .navigationTitle(NSLocalizedString("availability", comment: "Availability"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("save", comment: "Save")) {
                        authenticateIfNeeded {
                            if isValid {
                                let updated = AvailabilitySlot(id: originalID, start: start, end: end)
                                onSave(updated)
                                dismiss()
                            }
                        }
                    }
                    .foregroundColor(.done)
                    .disabled(!isValid)
                }
                
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("cancel", comment: "Cancel")) {
                        dismiss()
                    }
                    .foregroundColor(.cancel)
                }
            }
        }
    }
    private func authenticateIfNeeded(completion: @escaping () -> Void) {
        guard !didAuthenticate else {
            completion()
            return
        }

        let context = LAContext()
        var error: NSError?

        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: NSLocalizedString("authenticate", comment: "Authenticate to make changes")) { success, authError in
                DispatchQueue.main.async {
                    if success {
                        didAuthenticate = true
                        completion()
                    } else {
                        // Optional: Alert anzeigen oder dismissen
                    }
                }
            }
        } else {
            // Gerät unterstützt keine Authentifizierung (Face ID / Touch ID / Code)
            DispatchQueue.main.async {
                didAuthenticate = true
                completion()
            }
        }
    }
}
