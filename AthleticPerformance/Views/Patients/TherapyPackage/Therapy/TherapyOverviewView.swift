//
//  TherapyOverviewView.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 22.04.25.
//

import SwiftUI

/// Anzeige und Bearbeitung der allgemeinen Therapiedaten
struct TherapyOverviewView: View {
    @EnvironmentObject var patientStore: PatientStore
    @Binding var patient: Patient
    @Binding var therapy: Therapy
    
    @State private var allTherapyPlans: [TherapyPlan] = []
    @State private var allServices: [TreatmentService] = []
    @State private var expandedPlans: Set<UUID> = []
    @State private var agreementRefreshID = UUID()
    
    // 🔹 Flag: wurde vom Nutzer etwas verändert?
    @State private var isDirty = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                DisplaySectionBox(
                    title: NSLocalizedString("therapyOverview", comment: "Therapy overview"),
                    lightAccentColor: .accentColor,
                    darkAccentColor: .accentColor
                ) {
                    VStack(spacing: 16) {
                        if therapy.isCompleted {
                            HStack {
                                Text(therapy.title)
                                    .padding(8)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(Color.gray.opacity(0.4))
                                    )
                                Spacer()
                            }
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.positiveCheck)
                                .accessibilityLabel(NSLocalizedString("therapyFinished", comment: "Therapy finished."))
                        } else {
                            TextField(NSLocalizedString("title", comment: "Title"), text: $therapy.title)
                                .textFieldStyle(.roundedBorder)
                                .onChange(of: therapy.title) { _, _ in isDirty = true }
                        }
                        
                        // Goal
                        HStack(alignment: .top, spacing: 8) {
                            Text(NSLocalizedString("goal", comment: "Goal"))
                                .frame(width: 120, alignment: .topLeading)

                            Text(therapy.goals)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .topLeading)
                        }
                       
                        Divider()
                            .background(Color.divider.opacity(0.5))

                        // 📆 Period
                            HStack {
                                Text(NSLocalizedString("period", comment: "Period"))
                                    .frame(width: 120, alignment: .leading)
                                
                                Spacer()
                                
                                Text(therapy.startDate.formatted(date: .abbreviated, time: .omitted))
                                    .foregroundColor(.secondary)
                                    .frame(width: 120, alignment: .trailing)
                                
                                if let endDate = therapy.endDate {
                                    Text("-")
                                        .foregroundColor(.secondary)
                                        .frame(width: 20, alignment: .center)
                                    Text(endDate.formatted(date: .abbreviated, time: .omitted))
                                        .foregroundColor(.secondary)
                                        .frame(width: 120, alignment: .leading)
                                }
                            }
                       
                        Divider()
                            .background(Color.divider.opacity(0.5))

                            // 🔢 Sessions
                        if !allTherapyPlans.isEmpty {
                            Text(NSLocalizedString("therapyPlans", comment: "Therapy plans"))
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            ForEach(allTherapyPlans) { plan in
                                TherapyPlanSectionView(
                                    plan: plan,
                                    isExpanded: expandedPlans.contains(plan.id),
                                    onToggle: {
                                        if expandedPlans.contains(plan.id) {
                                            expandedPlans.remove(plan.id)
                                        } else {
                                            expandedPlans.insert(plan.id)
                                        }
                                    },
                                    allServices: allServices
                                )
                            }

                            Divider()
                                .background(Color.divider.opacity(0.5))
                        }
                        
                        if !therapy.isCompleted {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(NSLocalizedString("billingPeriod", comment: "Billing Period"))
                                Picker("", selection: $therapy.billingPeriod) {
                                    ForEach(BillingPeriod.allCases, id: \.self) { period in
                                        Text(period.localizedLabel).tag(period)
                                    }
                                }
                                .pickerStyle(.segmented)
                                .tint(.secondary)
                                .onChange(of: therapy.billingPeriod) { _, _ in isDirty = true }
                            }
                            
                            Divider()
                                .background(Color.divider.opacity(0.5))
                        }
                        
                        TherapyAgreementSection(
                                patient: $patient,
                                therapy: $therapy,
                                refreshTrigger: $agreementRefreshID
                            )
                            .environmentObject(patientStore)
                            .onChange(of: therapy) { _, _ in isDirty = true }

                        Divider()
                        .background(Color.divider.opacity(0.5))
                        
                        HStack {
                            Text(NSLocalizedString("therapist", comment: "Therapist"))
                                .frame(minWidth: 120, alignment: .leading)

                            Spacer()
                            
                            if !therapy.isCompleted {
                                Picker("", selection: $therapy.therapistId) {
                                    ForEach(AppGlobals.shared.therapistList, id: \.id) { therapist in
                                        Text(therapist.fullName).tag(therapist.id as Int?)
                                    }
                                }
                                .pickerStyle(.menu)
                                .tint(.secondary)
                                .onChange(of: therapy.therapistId) { _, _ in isDirty = true }
                            } else {
                                if let therapist = AppGlobals.shared.therapistList.first(where: { $0.id == therapy.therapistId }) {
                                    Text(therapist.fullName)
                                        .foregroundColor(.secondary)
                                } else {
                                    Text("-")
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .onAppear {
            let allSessions = therapy.therapyPlans.flatMap { $0.treatmentSessions }
            allTherapyPlans = therapy.therapyPlans
            allServices = AppGlobals.shared.treatmentServices

            let computedStart = allSessions.min(by: { $0.date < $1.date })?.date ?? therapy.startDate
            let computedEnd   = allSessions.max(by: { $0.date < $1.date })?.date

            if therapy.startDate != computedStart { therapy.startDate = computedStart }
            if therapy.endDate   != computedEnd   { therapy.endDate   = computedEnd }
        }
        .onDisappear {
            if isDirty {
                patientStore.updatePatient(patient, waitUntilSaved: true)
                isDirty = false
            }
        }
    }

    @ViewBuilder
    private func statusRow(label: String, status: Bool) -> some View {
        HStack {
            Text(NSLocalizedString(label, comment: ""))
            Spacer()
            Image(systemName: status ? "checkmark.circle.fill" : "slash.circle")
                .foregroundColor(status ? .positiveCheck : .negativeCheck)
        }
    }

    private struct SessionWithOptionalDivider: View {
        let session: TreatmentSessions
        let isLast: Bool
        let allServices: [TreatmentService]
        let availableTherapists: [Therapists]
        
        var body: some View {
            VStack(spacing: 0) {
                TreatmentSessionRow(
                    session: session,
                    allServices: allServices,
                    therapists: availableTherapists,
                    isMarkedForCancellation: false,
                    showCancellation: false,
                    onToggleCancellation: {}  // Leere Closure: tut nichts
                )
                .buttonStyle(.plain)
                
                if !isLast {
                    Divider()
                        .background(Color.divider.opacity(0.5))
                }
            }
        }
    }
    
    private struct TherapyPlanSectionView: View {
        let plan: TherapyPlan
        let isExpanded: Bool
        let onToggle: () -> Void
        let allServices: [TreatmentService]
        
        var body: some View {
            let allTherapyPlanSessions = plan.treatmentSessions
            let therapyPlanStartDate = allTherapyPlanSessions.min(by: { $0.date < $1.date })?.date ?? Date()
            let therapyPlanEndDate = allTherapyPlanSessions.max(by: { $0.date < $1.date })?.date
            
            VStack(alignment: .leading, spacing: 8) {
                Button(action: onToggle) {
                    HStack {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .foregroundColor(.accentColor)
                        let title = plan.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                        Text(title.isEmpty
                            ? NSLocalizedString("unnamedPlan", comment: "Unnamed plan")
                            : title)
                        .foregroundColor(.secondary)
                        Spacer()
                        
                        Text(therapyPlanStartDate.formatted(date: .abbreviated, time: .omitted))
                            .foregroundColor(.secondary)
                            .frame(width: 120, alignment: .trailing)
                        
                        if let endDate = therapyPlanEndDate {
                            Text("-")
                                .foregroundColor(.secondary)
                                .frame(width: 20, alignment: .center)
                            Text(endDate.formatted(date: .abbreviated, time: .omitted))
                                .foregroundColor(.secondary)
                                .frame(width: 120, alignment: .leading)
                        }
                        
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(PlainButtonStyle())

                if isExpanded && !plan.treatmentSessions.isEmpty {
                    Divider()
                        .background(Color.divider.opacity(0.5))

                    let sortedSessions = plan.treatmentSessions.sorted(by: { $0.startTime < $1.startTime })

                    ForEach(Array(sortedSessions.enumerated()), id: \.element.id) { index, session in
                        let serviceIds = session.treatmentServiceIds
                        let therapistId = session.therapistId

                        let assignedServices = allServices.filter { serviceIds.contains($0.internalId) }
                        let assignedTherapist = AppGlobals.shared.therapistList.first { $0.id == therapistId }

                        SessionWithOptionalDivider(
                            session: session,
                            isLast: index == sortedSessions.count - 1,
                            allServices: assignedServices,
                            availableTherapists: assignedTherapist.map { [$0] } ?? []
                        )
                    }
                }
            }
            .padding(.bottom, 8)
        }
    }
}
