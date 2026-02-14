//
//  OtherAnomalieStatusEntryRow.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 25.05.25.
//

import SwiftUI

struct OtherAnomalieStatusEntryRow: View {
    @Binding var entry: OtherAnomalieStatusEntry
    let availableBodyRegions: [BodyRegionGroup]
    let availablePainStructures: [PainStructures]
    let availablePainQualities: [PainQualities]
    let onEdited: () -> Void
    var isEditable: Bool = true

    @State private var selectedRegion: BodyRegionGroup?
    @State private var selectedPartID: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            regionPickerView
            partPickerView
            painSection
            anomalySection
            notesFieldsView
        }
        .onAppear {
            // Initial sync Region + Part aus entry.* wie gehabt
            let region = entry.bodyRegion?.region
            selectedRegion = region

            if let region,
               let validPart = entry.bodyPart,
               region.parts.contains(where: { $0.id == validPart.id })
            {
                // async, damit Picker aufgebaut ist
                DispatchQueue.main.async {
                    selectedPartID = validPart.id
                }
            }
        }
        .onChange(of: selectedRegion) { _, _ in
            // Region gewechselt → Part zurücksetzen
            selectedPartID = nil
            updateBodyRegion()
        }
        .onChange(of: selectedPartID) { _, _ in
            updateBodyRegion()
        }
    }

    // MARK: - Unter-Views

    private var regionPickerView: some View {
        HStack {
            Text(NSLocalizedString("bodyRegion", comment: "Body Region"))
                .frame(width: 120, alignment: .leading)

            Picker("", selection: $selectedRegion) {
                Text("–").tag(BodyRegionGroup?.none)
                ForEach(availableBodyRegions, id: \.id) { region in
                    Text(region.localized()).tag(Optional(region))
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
                    Text(part.localized()).tag(Optional(part.id))
                }
            }
            .pickerStyle(.menu)
            .tint(.secondary)
            .frame(width: 300, alignment: .trailing)
        }
    }

    private var painSection: some View {
        // Lokales Binding für optionale Pain-Infos
        let pains = Binding<AnomalyPains>(
            get: {
                entry.anomalyPains ?? AnomalyPains(id: UUID(), timestamp: Date())
            },
            set: {
                entry.anomalyPains = $0
                onEdited()
            }
        )

        return HStack(alignment: .center, spacing: 16) {

            // Schmerz-Struktur
            HStack {
                Text(NSLocalizedString("pain", comment: "Pain"))
                    .frame(width: 120, alignment: .leading)

                Picker("", selection: pains.subBinding(\.painStructure)) {
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

            // Schmerz-Qualität
            HStack {
                Text("").frame(width: 70, alignment: .leading)
                Spacer()

                Picker("", selection: pains.subBinding(\.painQuality)) {
                    Text("–").tag(PainQualities?.none)
                    ForEach(availablePainQualities, id: \.id) { pq in
                        Text(pq.localized()).tag(Optional(pq))
                    }
                }
                .pickerStyle(.menu)
                .tint(.secondary)
                .frame(width: 150, alignment: .trailing)

                Spacer()
            }

            // Schmerz-Stärke
            HStack {
                Text("\(pains.wrappedValue.painLevel?.value ?? 0)")
                    .frame(width: 70, alignment: .leading)

                Slider(
                    value: Binding(
                        get: {
                            Double(pains.wrappedValue.painLevel?.value ?? 0)
                        },
                        set: {
                            pains.wrappedValue.painLevel = PainLevels(Int($0))
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

    private var anomalySection: some View {
        HStack {
            Text(NSLocalizedString("anomaly", comment: "Anomaly"))
                .frame(width: 120, alignment: .leading)

            TextField(
                "",
                text: $entry.anomaly
            )
            .textFieldStyle(.roundedBorder)
            .submitLabel(.done)
            .onSubmit { onEdited() }
        }
    }

    private var notesFieldsView: some View {
        let pains = Binding<AnomalyPains>(
            get: {
                entry.anomalyPains ?? AnomalyPains(id: UUID(), timestamp: Date())
            },
            set: {
                entry.anomalyPains = $0
                onEdited()
            }
        )

        return VStack(spacing: 8) {
            TextField(
                NSLocalizedString("notes", comment: "Notes"),
                text: pains.subBinding(\.notes, default: "")
            )
            .textFieldStyle(.roundedBorder)
            .submitLabel(.done)
            .onSubmit { onEdited() }
        }
    }

    // MARK: - Helper

    private func updateBodyRegion() {
        guard let region = selectedRegion else {
            entry.bodyRegion = nil
            entry.bodyPart = nil
            onEdited()
            return
        }

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
        onEdited()
    }
}
