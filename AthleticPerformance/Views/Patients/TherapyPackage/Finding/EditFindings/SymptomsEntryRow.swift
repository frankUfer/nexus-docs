//
//  SymptomsEntryRow.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 09.05.25.
//

import SwiftUI

struct SymptomsEntryRow: View {
    @Binding var entry: SymptomsStatusEntry
    let availableBodyRegions: [BodyRegionSelectionGroup]
    let availablePainStructures: [PainStructures]
    let availablePainQualities: [PainQualities]
    let onEdited: () -> Void

    @State private var selectedRegion: BodyRegionGroup?
    @State private var selectedPartID: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            regionPickerView
            partPickerView
            actionAndDateView
            painSection
            notesFieldsView
        }
        .onAppear {
            // lokale Auswahl initialisieren
            let region = entry.bodyRegion?.region
            selectedRegion = region

            if let region,
                let validPart = entry.bodyPart,
                region.parts.contains(where: { $0.id == validPart.id })
            {
                DispatchQueue.main.async {
                    selectedPartID = validPart.id
                }
            }
        }
        .onChange(of: selectedRegion) { _, _ in
            selectedPartID = nil
            updateBodyRegionAndMarkEdited()
        }
        .onChange(of: selectedPartID) { _, _ in
            updateBodyRegionAndMarkEdited()
        }
    }

    // Einziger Ort, der bodyRegion/bodyPart setzt UND genau einmal onEdited() feuert
    private func updateBodyRegionAndMarkEdited() {
        if let region = selectedRegion {
            if let partID = selectedPartID,
                let part = region.parts.first(where: { $0.id == partID })
            {
                entry.bodyRegion = BodyRegionSelectionGroup(
                    region: region,
                    selectedParts: [part]
                )
                entry.bodyPart = part
            } else {
                entry.bodyRegion = BodyRegionSelectionGroup(
                    region: region,
                    selectedParts: []
                )
                entry.bodyPart = nil
            }
        } else {
            entry.bodyRegion = nil
            entry.bodyPart = nil
        }
        onEdited()
    }

    // MARK: - Subviews

    private var regionPickerView: some View {
        HStack {
            Text(NSLocalizedString("bodyRegion", comment: "Body Region"))
                .frame(width: 120, alignment: .leading)

            Picker("", selection: $selectedRegion) {
                Text("–").tag(BodyRegionGroup?.none)
                ForEach(availableBodyRegions, id: \.region.id) { group in
                    Text(group.region.localized()).tag(Optional(group.region))
                }
            }
            .pickerStyle(.menu)
            .tint(.secondary)
            .frame(width: 300, alignment: .trailing)
        }
    }

    private var partPickerView: some View {
        HStack {
            Text(NSLocalizedString("bodyPart", comment: "Body Part"))
                .frame(width: 120, alignment: .leading)

            Picker("", selection: $selectedPartID) {
                Text("–").tag(nil as String?)
                ForEach(selectedRegion?.parts ?? [], id: \.id) { part in
                    Text(part.localized()).tag(part.id)
                }
            }
            .pickerStyle(.menu)
            .tint(.secondary)
            .frame(width: 300, alignment: .trailing)
        }
    }

    private var actionAndDateView: some View {
        HStack(alignment: .center, spacing: 16) {
            TextField(
                NSLocalizedString(
                    "problematicAction",
                    comment: "Problematic action"
                ),
                text: Binding($entry.problematicAction, default: "")
            )
            .textFieldStyle(.roundedBorder)
            .frame(maxWidth: .infinity)
            .submitLabel(.done)
            .onSubmit { onEdited() }

            Spacer()

            Text(NSLocalizedString("since", comment: "Since"))
                .frame(width: 50, alignment: .leading)

            DatePicker(
                "",
                selection: Binding($entry.sinceDate, default: Date()),
                displayedComponents: [.date]
            )
            .datePickerStyle(.compact)
            .frame(maxWidth: 150)
            .onChange(of: entry.sinceDate) { _, _ in onEdited() }
        }
    }

    private var painSection: some View {
        let painBinding = Binding<SymptomPains>(
            get: {
                entry.symptomPains
                    ?? SymptomPains(id: UUID(), timestamp: Date())
            },
            set: {
                entry.symptomPains = $0
                onEdited()
            }
        )

        return VStack(alignment: .leading, spacing: 8) {

            // Zeile 1: Label + Struktur
            HStack {
                Text(NSLocalizedString("pain", comment: "Pain"))
                    .frame(width: 120, alignment: .leading)

                Picker(
                    "",
                    selection: Binding(
                        get: { painBinding.wrappedValue.painStructure },
                        set: {
                            painBinding.wrappedValue.painStructure = $0
                            onEdited()
                        }
                    )
                ) {
                    Text("–").tag(PainStructures?.none)
                    ForEach(availablePainStructures, id: \.id) { ps in
                        Text(ps.localized()).tag(Optional(ps))
                    }
                }
                .pickerStyle(.menu)
                .tint(.secondary)
                .frame(width: 300, alignment: .trailing)

                Spacer()
            }

            // Zeile 2: Qualität + Stärke
            HStack {
                HStack {
                    Text("")  // Platzhalter zur Spaltenausrichtung
                        .frame(width: 120, alignment: .leading)

                    Picker(
                        "",
                        selection: Binding(
                            get: { painBinding.wrappedValue.painQuality },
                            set: {
                                painBinding.wrappedValue.painQuality = $0
                                onEdited()
                            }
                        )
                    ) {
                        Text("–").tag(PainQualities?.none)
                        ForEach(availablePainQualities, id: \.id) { pq in
                            Text(pq.localized()).tag(Optional(pq))
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(.secondary)
                    .frame(width: 300, alignment: .trailing)

                    Spacer()
                }

                HStack {
                    Text("\(painBinding.wrappedValue.painLevel?.value ?? 0)")
                        .frame(width: 70, alignment: .leading)

                    Spacer()

                    Slider(
                        value: Binding(
                            get: {
                                Double(
                                    painBinding.wrappedValue.painLevel?.value
                                        ?? 0
                                )
                            },
                            set: {
                                painBinding.wrappedValue.painLevel = PainLevels(
                                    Int($0)
                                )
                            }
                        ),
                        in: 0...10,
                        step: 1
                    ) { editing in
                        if !editing { onEdited() }
                    }
                }
            }
        }
    }

    private var notesFieldsView: some View {
        VStack(spacing: 8) {
            let painBinding = Binding<SymptomPains>(
                get: {
                    entry.symptomPains
                        ?? SymptomPains(id: UUID(), timestamp: Date())
                },
                set: {
                    entry.symptomPains = $0
                    onEdited()
                }
            )

            TextField(
                NSLocalizedString("notes", comment: "Notes"),
                text: painBinding.subBinding(\.notes, default: "")
            )
            .textFieldStyle(.roundedBorder)
            .submitLabel(.done)
            .onSubmit { onEdited() }
        }
    }
}
