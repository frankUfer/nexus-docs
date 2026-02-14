//
//  ServiceEditorList.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 09.04.25.
//

import SwiftUI

struct ServiceEditorList: View {
    @Binding var services: [TreatmentService]
    @State private var serviceIdsMarkedForDeletion: Set<UUID> = []
    @State private var pendingDeleteServiceId: UUID? = nil
    @State private var showDeleteConfirmation = false

    var onModified: () -> Void
    var onDone: () -> Void = {}
    var onCancel: () -> Void = {}

    var body: some View {
        VStack(spacing: 16) {
            ForEach(services.filter { !serviceIdsMarkedForDeletion.contains($0.internalId) }, id: \.internalId) { service in
                ServiceRow(
                    service: binding(for: service),
                    onDelete: {
                        pendingDeleteServiceId = service.internalId
                        showDeleteConfirmation = true
                    }
                )
            }

            Button {
                services.append(
                    TreatmentService(
                        internalId: UUID(),
                        id: "",
                        de: "",
                        en: "",
                        billingCode: nil,
                        quantity: nil,
                        unit: nil,
                        price: nil,
                        isBillable: true
                    )
                )
                onModified()
            } label: {
                Label(NSLocalizedString("addService", comment: "Add Service"), systemImage: "plus.circle.fill")
                    .foregroundColor(.addButton)
            }

            HStack {
                Button(role: .cancel, action: {
                    serviceIdsMarkedForDeletion.removeAll()
                    pendingDeleteServiceId = nil
                    onCancel()
                }) {
                    Label(NSLocalizedString("cancel", comment: "Cancel"), systemImage: "xmark")
                    .foregroundColor(.cancel)
                }

                Spacer()

                Button(action: {
                    services.removeAll { serviceIdsMarkedForDeletion.contains($0.internalId) }
                    serviceIdsMarkedForDeletion.removeAll()
                    onModified()
                    onDone()
                }) {
                    Label(NSLocalizedString("save", comment: "Save"), systemImage: "checkmark")
                    .foregroundColor(.done)
                }
                .tint(.accentColor)
            }
            .padding(.top, 12)
        }
        .alert(isPresented: $showDeleteConfirmation) {
            Alert(
                title: Text(NSLocalizedString("confirmDelete", comment: "Confirm deletion")),
                message: Text(NSLocalizedString("reallyDeleteService", comment: "Do you really want to delete this service?")),
                primaryButton: .destructive(Text(NSLocalizedString("delete", comment: "Delete"))) {
                    if let id = pendingDeleteServiceId, canDeleteService(withId: id) {
                        serviceIdsMarkedForDeletion.insert(id)
                        pendingDeleteServiceId = nil
                    }
                },
                secondaryButton: .cancel {
                    pendingDeleteServiceId = nil
                }
            )
        }
    }

    private func canDeleteService(withId id: UUID) -> Bool {
        return true
    }

    private func binding(for service: TreatmentService) -> Binding<TreatmentService> {
        guard let index = services.firstIndex(where: { $0.internalId == service.internalId }) else {
            fatalError("Service mit internalId \(service.internalId) nicht gefunden")
        }
        return $services[index]
    }
}

struct ServiceRow: View {
    @Binding var service: TreatmentService
    var onDelete: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            // 🔹 Erste Zeile
            HStack(spacing: 12) {
                TextField(NSLocalizedString("id", comment: "Service ID"), text: $service.id)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 140)

                TextField(NSLocalizedString("title", comment: "Service title"), text: Binding(get: {
                    service.localizedName(for: Locale.current.language.languageCode?.identifier ?? "en")
                }, set: { newValue in
                    if Locale.current.language.languageCode?.identifier == "de" {
                        service.de = newValue
                    } else {
                        service.en = newValue
                    }
                }))
                .textFieldStyle(.roundedBorder)
            }

            // 🔹 Zweite Zeile
            HStack {
                HStack(spacing: 12) {
                    TextField(NSLocalizedString("billingCode", comment: "Billing code"),
                              text: Binding($service.billingCode, default: ""))
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 120)

                    TextField(NSLocalizedString("quantity", comment: "Quantity"),
                              value: Binding($service.quantity, default: 0),
                              formatter: NumberFormatter())
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.numberPad)
                        .frame(width: 60)

                    TextField(NSLocalizedString("unit", comment: "Unit"),
                              text: Binding($service.unit, default: ""))
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 60)

                    TextField(NSLocalizedString("price", comment: "Price"), text: Binding(
                        get: { String(format: "%.2f", service.price ?? 0.0) },
                        set: { service.price = Double($0.replacingOccurrences(of: ",", with: ".")) ?? 0.0 }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 100)
                }

                Spacer()

                BoolSwitch(
                    value: $service.isBillable,
                    label: NSLocalizedString("billable", comment: "abrechenbar")
                )
            }

            // 🔹 Löschen
            HStack {
                Spacer()
                Button(role: .destructive, action: onDelete) {
                    Label(NSLocalizedString("deleteService", comment: ""), systemImage: "minus.circle.fill")
                        .foregroundColor(.deleteButton)
                }
            }
            Divider()
            .background(Color.divider.opacity(0.5))
        }
    }
}
