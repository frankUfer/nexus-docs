//
//  BillingMainView.swift
//  AthleticPerformance
//
//  Created by Frank Ufer on 20.06.25.
//

import SwiftUI

struct BillingMainView: View {
    @EnvironmentObject var patientStore: PatientStore
    @State private var selectedDate: Date = BillingMainView.loadStoredDate()
    @State private var billingEntries: [BillingEntry] = []
    @State private var unsentInvoices: [Invoice] = []
    @State private var invoiceRefreshCounter: Int = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Spacer()
                    Text(NSLocalizedString("billingDate", comment: "Billing date") + ":")
                    DatePicker("", selection: $selectedDate, displayedComponents: [.date])
                        .labelsHidden()
                        .onChange(of: selectedDate) { _, newValue in
                            BillingMainView.storeDate(newValue)
                        }
                }
                .padding(.horizontal)

                Button(action: {
                    billingEntries = collectBillingData(patients: patientStore.patients, billingDate: selectedDate)
                }) {
                    Label(NSLocalizedString("generateBillingOverview", comment: "Generate Billing Overview"), systemImage: "doc.plaintext")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal)

                if !billingEntries.isEmpty {
                    BillingOverviewView(
                        billingData: $billingEntries,
                        selectedDate: selectedDate,
                        onInvoicesCreated: {
                            billingEntries = collectBillingData(patients: patientStore.patients, billingDate: selectedDate)
                            unsentInvoices = InvoiceFileManager.loadUnsentInvoices()
                            invoiceRefreshCounter += 1
                        }
                    )
                    .padding(.horizontal)
                }
                                
                // let newInvoices = InvoiceFileManager.loadUnsentInvoices()
                if !unsentInvoices.isEmpty {
                    InvoiceOverviewView(
                        invoices: unsentInvoices,
                        onInvoicesSent: {
                            unsentInvoices = InvoiceFileManager.loadUnsentInvoices()
                            invoiceRefreshCounter += 1
                        }
                    )
                    .environmentObject(patientStore)
                    .id(invoiceRefreshCounter)
                }

                Spacer()
            }
        }
        .navigationTitle(NSLocalizedString("billingInvoicing", comment: "Invoicing"))
        .onAppear {
            unsentInvoices = InvoiceFileManager.loadUnsentInvoices()
        }
        .onChange(of: invoiceRefreshCounter) {
             unsentInvoices = InvoiceFileManager.loadUnsentInvoices()
         }
    }

    private func convertSessionInfosToEntries(_ infos: [BillingSessionInfo]) -> [BillingEntry] {
        var entries: [BillingEntry] = []
        for info in infos {
            for session in info.sessions {
                for serviceId in session.treatmentServiceIds {
                    if let service = AppGlobals.shared.treatmentServices.first(where: { $0.internalId == serviceId }) {
                        let quantity = 1
                        let price = service.price ?? 0.0
                        let volume = Double(quantity) * price
                        entries.append(
                            BillingEntry(
                                patient: info.patient,
                                therapy: info.therapy,
                                plan: info.plan,
                                service: service,
                                serviceDate: session.date,
                                sessionId: session.id,
                                quantity: quantity,
                                volume: volume,
                                isBillable: info.status == .readyForInvoice && service.isBillable
                            )
                        )
                    }
                }
            }
        }
        return entries
    }

    // MARK: - Datum speichern / laden

    private static let dateStorageKey = "BillingMainView.selectedDate"

    static func loadStoredDate() -> Date {
        if let timestamp = UserDefaults.standard.double(forKey: dateStorageKey) as Double?, timestamp > 0 {
            return Date(timeIntervalSince1970: timestamp)
        } else {
            return Date() // Fallback: aktuelles Datum
        }
    }

    static func storeDate(_ date: Date) {
        UserDefaults.standard.set(date.timeIntervalSince1970, forKey: dateStorageKey)
    }
}
