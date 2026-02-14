//
//  BillingOverviewView.swift
//  AthleticPerformance
//
//  Created by Frank Ufer on 20.06.25.
//

import SwiftUI

struct BillingOverviewView: View {
    @Binding var billingData: [BillingEntry]
    let selectedDate: Date
    let onInvoicesCreated: () -> Void

    @State private var expandedPatients: Set<UUID> = []
    @State private var selectedPatientIDs: Set<UUID> = []
    @State private var selectedPlanIDs: Set<UUID> = []
    
    @EnvironmentObject var patientStore: PatientStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    
                    // 🔹 Faktura-Button (nur sichtbar, wenn etwas selektiert ist)
                    if !selectedPatientIDs.isEmpty || !selectedPlanIDs.isEmpty {
                                Button(action: {
                                    createInvoices()
                                }) {
                                    Label(NSLocalizedString("createInvoices", comment: "Create invoices"), systemImage: "doc.plaintext.fill")
                                        .foregroundColor(.positiveCheck)
                                }
                                .buttonStyle(.bordered)
                            }
                    
                    Spacer()

                    // 🔹 Globale Auswahlsteuerung
                    if !billablePlans.isEmpty {
                        BoolSwitchWoSpacer(
                            value: Binding(
                                get: { selectedPatientIDs.count > 0 && selectedPatientIDs.count == billablePatients.count },
                                set: { isSelected in
                                    if isSelected {
                                        selectedPatientIDs = Set(billablePatients.map { $0.id })
                                        selectedPlanIDs = Set(billablePlans.map { $0.id })
                                    } else {
                                        selectedPatientIDs.removeAll()
                                        selectedPlanIDs.removeAll()
                                    }
                                }
                            ),
                            label: NSLocalizedString("selectAll", comment: "Select All")
                        )
                        .padding(.horizontal)
                    }
                    
                }

                ForEach(groupedByPatient(), id: \.patient.id) { (patient, entries) in
                    let hasBillable = entries.contains { $0.isBillable }
                    let patientSum = entries.reduce(0.0) { $0 + $1.volume }

                    DisclosureGroup(
                        isExpanded: Binding(
                            get: { expandedPatients.contains(patient.id) },
                            set: { isExpanded in
                                if isExpanded {
                                    expandedPatients.insert(patient.id)
                                } else {
                                    expandedPatients.remove(patient.id)
                                }
                            }
                        )
                    ) {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(groupedByPlan(entries: entries), id: \.plan.id) { (plan, planEntries) in
                                let planSum = planEntries.reduce(0.0) { $0 + $1.volume }
                                let therapyTitle = planEntries.first?.therapy.title ?? NSLocalizedString("therapy", comment: "")

                                VStack(alignment: .leading, spacing: 4) {
                                    // Plan-Checkbox + Titel + Summe
                                    if planEntries.contains(where: { $0.isBillable }) {
                                        BoolSwitch(
                                            value: Binding(
                                                get: { selectedPlanIDs.contains(plan.id) },
                                                set: { isSelected in
                                                    if isSelected {
                                                        selectedPlanIDs.insert(plan.id)
                                                    } else {
                                                        selectedPlanIDs.remove(plan.id)
                                                    }
                                                    updatePatientSelection(for: patient)
                                                }
                                            ),
                                            label: "\(therapyTitle) - \(plan.title ?? NSLocalizedString("untitledPlan", comment: "")) (€ \(String(format: "%.2f", planSum)))"
                                        )
                                    } else {
                                        HStack {
                                            Text("\(therapyTitle) - \(plan.title ?? NSLocalizedString("untitledPlan", comment: ""))")
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                            Spacer()
                                            Text(String(format: "€ %.2f", planSum))
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                        }
                                    }

                                    // Heilmittel-Liste
                                    let groupedServices = Dictionary(grouping: planEntries, by: { $0.service })
                                    ForEach(groupedServices.keys.sorted(by: { $0.de < $1.de }), id: \.self) { service in
                                        if let serviceEntries = groupedServices[service] {
                                            let totalQuantity = serviceEntries.reduce(0) { $0 + $1.quantity }
                                            let totalVolume = serviceEntries.reduce(0.0) { $0 + $1.volume }

                                            HStack {
                                                Text("• \(service.de):")
                                                Spacer()
                                                Text("\(totalQuantity) × \(String(format: "€ %.2f", service.price ?? 0.0)) = \(String(format: "€ %.2f", totalVolume))")
                                            }
                                            .font(.footnote)
                                            .foregroundColor(serviceEntries.first?.isBillable == true ? .positiveCheck : .secondary)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.top, 8)

                    } label: {
                        HStack {
                            patientHeaderView(for: patient, hasBillable: hasBillable)
                            
                            Spacer()

                            Text(String(format: "€ %.2f", patientSum))
                                .font(.headline)
                                .foregroundColor(hasBillable ? .positiveCheck : .primary)
                                .bold()
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemGray6))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(.separator), lineWidth: 1)
                    )
                    .padding(.horizontal)
                }
            }
        }
    }

    // MARK: - Helpers

    private var billablePatients: [Patient] {
        groupedByPatient()
            .filter { (_, entries) in entries.contains { $0.isBillable } }
            .map { $0.patient }
    }

    private var billablePlans: [TherapyPlan] {
        billingData
            .filter { $0.isBillable }
            .map { $0.plan }
    }

    private func groupedByPatient() -> [(patient: Patient, entries: [BillingEntry])] {
        Dictionary(grouping: billingData, by: { $0.patient })
            .map { ($0.key, $0.value) }
            .sorted { $0.0.lastname < $1.0.lastname }
    }

    private func groupedByPlan(entries: [BillingEntry]) -> [(plan: TherapyPlan, entries: [BillingEntry])] {
        Dictionary(grouping: entries, by: { $0.plan })
            .map { ($0.key, $0.value) }
            .sorted { ($0.0.title ?? "") < ($1.0.title ?? "") }
    }

    private func formattedDate(_ date: Date) -> String {
        date.formatted(.dateTime.day().month().year())
    }

    private func plansForPatient(_ patient: Patient) -> [UUID] {
        billingData
            .filter { $0.patient == patient && $0.isBillable }
            .map { $0.plan.id }
    }

    private func updatePatientSelection(for patient: Patient) {
        let planIds = Set(plansForPatient(patient))
        if planIds.isSubset(of: selectedPlanIDs) {
            selectedPatientIDs.insert(patient.id)
        } else {
            selectedPatientIDs.remove(patient.id)
        }
    }
    
    @ViewBuilder
    private func patientHeaderView(for patient: Patient, hasBillable: Bool) -> some View {
        if hasBillable {
            BoolSwitchDisclosure(
                value: Binding(
                    get: { selectedPatientIDs.contains(patient.id) },
                    set: { isSelected in
                        if isSelected {
                            selectedPatientIDs.insert(patient.id)
                            selectedPlanIDs.formUnion(plansForPatient(patient))
                        } else {
                            selectedPatientIDs.remove(patient.id)
                            selectedPlanIDs.subtract(plansForPatient(patient))
                        }
                    }
                )
            ) {
                Text("\(patient.fullName) (\(formattedDate(patient.birthdate)))")
                    .foregroundColor(.positiveCheck)
            }
        } else {
            Text("\(patient.fullName) (\(formattedDate(patient.birthdate)))")
                .font(.headline)
                .foregroundColor(.primary)
        }
    }
            
    private func createInvoices() {
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        var invoiceNumberManager = NumberManager(fileName: "invoice_number_state.json", prefix: "")
        var updatedPatients: [UUID: Patient] = [:]

        for planId in selectedPlanIDs {
            let entriesForPlan = billingData.filter { $0.plan.id == planId }
            
            guard let firstEntry = entriesForPlan.first else {
                continue
            }
            
            let patient = firstEntry.patient
            let invoiceNumber = invoiceNumberManager.nextNumber(for: selectedDate)
            let dueDate = Calendar.current.date(byAdding: .day, value: AppGlobals.shared.paymentTerms, to: selectedDate) ?? selectedDate
            
            // Bereite die InvoiceItems und merke Statusänderungen
            var items: [InvoiceItem] = []
            
            // Patient-Objekt vorbereiten
            var patientObj = updatedPatients[patient.id] ?? patientStore.patients.first(where: { $0.id == patient.id })!
            
            for entry in entriesForPlan {
                items.append(
                    InvoiceItem(
                        id: UUID(),
                        sessionId: entry.sessionId.uuidString,
                        serviceId: entry.service.internalId.uuidString,
                        serviceDate: entry.serviceDate,
                        serviceDescription: entry.service.de,
                        billingCode: entry.service.billingCode,
                        quantity: entry.quantity,
                        unitPrice: entry.service.price ?? 0.0,
                        notes: nil
                    )
                )
                
                // Status setzen
                for therapyIndex in patientObj.therapies.indices {
                    guard var therapy = patientObj.therapies[therapyIndex] else { continue }
                    
                    if let planIndex = therapy.therapyPlans.firstIndex(where: { $0.id == planId }) {
                        var plan = therapy.therapyPlans[planIndex]
                        
                        if let sessionIndex = plan.treatmentSessions.firstIndex(where: { $0.id == entry.sessionId }) {
                            var session = plan.treatmentSessions[sessionIndex]
                            session.setStatus(.invoiced)
                            plan.treatmentSessions[sessionIndex] = session
                        }
                        
                        therapy.therapyPlans[planIndex] = plan
                        patientObj.therapies[therapyIndex] = therapy
                    }
                }
            }
            
            let aggregatedItems: [InvoiceServiceAggregation] = Dictionary(grouping: items, by: { $0.serviceId })
                .map { (serviceId, groupedItems) in
                    let first = groupedItems.first!
                    let totalQuantity = groupedItems.reduce(0) { $0 + $1.quantity }
                    return InvoiceServiceAggregation(
                        serviceId: serviceId,
                        serviceDescription: first.serviceDescription,
                        billingCode: first.billingCode,
                        quantity: totalQuantity,
                        unitPrice: first.unitPrice
                    )
                }
            
            updatedPatients[patient.id] = patientObj
            
            // Berechne Beträge
            let subtotal = items.reduce(0.0) { $0 + (Double($1.quantity) * $1.unitPrice) }
            let taxRate = AppGlobals.shared.taxRate
            let totalAmount = subtotal * (1.0 + taxRate)
            
            // Adresse
            let practice = AppGlobals.shared.practiceInfo
            let billingAddress = patient.addresses.first(where: { $0.value.isBillingAddress })?.value
            ?? patient.addresses.first?.value
            ?? Address(street: "", postalCode: "", city: "")
            
            let diagnosisTitle = firstEntry.therapy.diagnoses
                .first(where: { $0.id == firstEntry.plan.diagnosisId })?
                .title ?? NSLocalizedString("unknownDiagnosis", comment: "Unknown diagnosis")
            
            let diagnosisDate = firstEntry.therapy.diagnoses
                .first(where: { $0.id == firstEntry.plan.diagnosisId })?
                .source.createdAt.formatted(date: .abbreviated, time: .omitted)
                ?? NSLocalizedString("unknownDate", comment: "Unknown date")
            
            let originName = firstEntry.therapy.diagnoses
                .first(where: { $0.id == firstEntry.plan.diagnosisId })?
                .source.originName ?? NSLocalizedString("unknownOrigin", comment: "Unknown origin")
            
            let therapistName = AppGlobals.shared.therapistList
                .first(where: { $0.id == firstEntry.plan.therapistId })?
                .fullName ?? NSLocalizedString("unknownTherapist", comment: "Unknown therapist")
            
            // Dateipfad ermitteln
            let patientDir = documentsURL
                .appendingPathComponent("patients")
                .appendingPathComponent(patient.id.uuidString)
                .appendingPathComponent("invoices")
            
            // prüfen ob Plan wirklich eine Diagnose hat
            let hasDiagnosis: Bool = {
                guard let diagId = firstEntry.plan.diagnosisId else { return false }
                return firstEntry.therapy.diagnoses.contains { $0.id == diagId }
            }()
            
            let invoice = Invoice(
                id: UUID(),
                invoiceType: .invoice,
                invoiceNumber: invoiceNumber,
                therapyPlanId: planId,
                invoiceBasis: diagnosisTitle,
                diagnosisSource: originName,
                diagnosisDate: diagnosisDate,
                date: selectedDate,
                dueDate: dueDate,
                patientId: patient.id,
                patientName: patient.fullName,
                patientAddress: billingAddress,
                patientEmail: patient.emailAddresses.first?.value ?? "",
                therapistFullName: therapistName,
                providerName: practice.name,
                providerAddress: practice.address,
                providerPhone: practice.phone,
                providerEmail: practice.email,
                providerBank: practice.bank,
                providerIBAN: practice.iban,
                providerBIC: practice.bic,
                providerTaxId: practice.taxNumber,
                items: items,
                aggregatedItems: aggregatedItems,
                subtotal: subtotal,
                taxRate: taxRate,
                totalAmount: totalAmount,
                pdfPath: patientDir.path,
                isCreated: true
            )
            
            do {
                try generateInvoicePDF(
                    invoice: invoice,
                    aggregatedItems: aggregatedItems,
                    hasDiagnosis: hasDiagnosis
                )
            } catch {
            }
            
            // Datei speichern
            InvoiceFileManager.saveInvoice(invoice)
        }

        // Speichere alle geänderten Patienten im Store
        for (_, updatedPatient) in updatedPatients {
            patientStore.updatePatient(updatedPatient)
        }
        onInvoicesCreated()
    }
}
