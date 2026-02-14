//
//  PatientDetailView.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 18.03.25.
//

import SwiftUI

struct PatientReadonlyView: View {
    @Binding var patient: Patient
    @Binding var refreshTrigger: UUID
    @State private var isEditingMasterData = false

    @EnvironmentObject var patientStore: PatientStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // 🔹 Titel und Bearbeiten-Button
                HStack {
                    Text(NSLocalizedString("masterData", comment: "Patient Master Data"))
                        .font(.title2.bold())
                        .accessibilityAddTraits(.isHeader)
                    Spacer()
                    if patient.isActive {
                        Button {
                            isEditingMasterData = true
                        } label: {
                            Label(NSLocalizedString("editBasicInfo", comment: "Edit"), systemImage: "pencil")
                                .labelStyle(.iconOnly)
                                .imageScale(.large)
                        }
                    } else {
                        Label(NSLocalizedString("inactivePatient", comment: "Patient is inactive"), systemImage: "slash.circle")
                            .foregroundColor(.gray)
                            .help(NSLocalizedString("patientIsInactiveHelp", comment: "This patient is marked as inactive"))
                    }
                }
                .padding(.horizontal)
                .padding(.top)

                DisplaySectionBox(
                    title: "basicInfo",
                    lightAccentColor: .accentColor,
                    darkAccentColor: .accentColor
                ) {
                    PatientBasicInfoView(
                        title: patient.title,
                        firstnameTerms: patient.firstnameTerms,
                        firstname: patient.firstname,
                        lastname: patient.lastname,
                        birthdate: patient.birthdate,
                        sex: patient.sex
                    )
                }

                if !patient.phoneNumbers.isEmpty {
                    DisplaySectionBox(
                        title: "phoneNumbers",
                        lightAccentColor: .accentColor,
                        darkAccentColor: .accentColor
                    ) {
                        ForEach(patient.phoneNumbers) { entry in
                            PhoneNumberInfoRow(
                                label: entry.label,
                                number: entry.value,
                                icon: "phone.fill",
                                color: .icon
                            )
                        }
                    }
                }

                if !patient.emailAddresses.isEmpty {
                    DisplaySectionBox(
                        title: "emailAddresses",
                        lightAccentColor: .accentColor,
                        darkAccentColor: .accentColor
                    ) {
                        ForEach(patient.emailAddresses) { entry in
                            LabeledInfoRow(label: entry.label, value: entry.value, icon: "envelope.fill", color: .icon)
                        }
                    }
                }
                                
                if !patient.addresses.isEmpty {
                    DisplaySectionBox(
                        title: "addresses",
                        lightAccentColor: .accentColor,
                        darkAccentColor: .accentColor
                    ) {
                        ForEach(patient.addresses) { entry in
                            let cityLine = [entry.value.postalCode, entry.value.city]
                                .filter { !$0.isEmpty }
                                .joined(separator: " ")
                            
                            let fullAddress = [entry.value.street, cityLine, entry.value.country]
                                .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                                .joined(separator: ", ")

                            HStack(alignment: .top, spacing: 16) {
                                VStack(alignment: .leading, spacing: 6) {
                                    LabeledInfoRow(label: entry.label, value: entry.value.street, icon: "house.fill", color: .icon)

                                    if !cityLine.isEmpty {
                                        LabeledInfoRow(label: "city", value: cityLine, icon: "map.fill", color: .icon)
                                    }

                                    LabeledInfoRow(label: "country", value: entry.value.country, icon: "globe", color: .icon)
                                    
                                    if entry.value.isBillingAddress {
                                        LabeledInfoRow(label: "isBillingAddress", value: "", icon: "envelope.open.fill", color: .icon)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)

                                if !fullAddress.isEmpty {
                                    AddressMapView(addressString: fullAddress)
                                        .frame(width: 150, height: 100)
                                        .cornerRadius(12)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                

                if !patient.emergencyContacts.isEmpty {
                    DisplaySectionBox(
                        title: "emergencyContacts",
                        lightAccentColor: .accentColor,
                        darkAccentColor: .accentColor
                    ) {
                        ForEach(patient.emergencyContacts) { contact in
                            VStack(alignment: .leading, spacing: 6) {
                                let name = [contact.value.firstname, contact.value.lastname]
                                    .filter { !$0.isEmpty }
                                    .joined(separator: " ")
                                if !name.isEmpty {
                                    LabeledInfoRow(label: contact.label, value: name, icon: "person.crop.circle.badge.exclamationmark", color: .icon)
                                }

                                if !contact.value.phone.isEmpty {
                                    LabeledInfoRow(label: "phone", value: contact.value.phone, icon: "phone.fill", color: .icon)
                                }

                                if !contact.value.email.isEmpty {
                                    LabeledInfoRow(label: "email", value: contact.value.email, icon: "envelope.fill", color: .icon)
                                }
                            }
                        }
                    }
                }

                DisplaySectionBox(
                    title: "insuranceInformation",
                    lightAccentColor: .accentColor,
                    darkAccentColor: .accentColor
                ) {
                    if !patient.insuranceStatus.rawValue.isEmpty {
                        LabeledInfoRow(
                            label: "insuranceStatus",
                            value: NSLocalizedString(patient.insuranceStatus.rawValue, comment: ""),
                            icon: "heart.text.square.fill",
                            color: .icon
                        )
                    }
                    if let insuranceId = patient.insurance, !insuranceId.isEmpty {
                        LabeledInfoRow(
                            label: "insurance",
                            value: resolvedInsuranceName(for: insuranceId),
                            icon: "building.2.fill",
                            color: .icon
                        )
                    }
                    if let insuranceNumber = patient.insuranceNumber, !insuranceNumber.isEmpty {
                        LabeledInfoRow(
                            label: "insuranceNumber",
                            value: insuranceNumber,
                            icon: "number",
                            color: .icon
                        )
                    }
                    if let doctor = patient.familyDoctor, !doctor.isEmpty {
                        LabeledInfoRow(
                            label: "familyDoctor",
                            value: doctor,
                            icon: "stethoscope",
                            color: .icon
                        )
                    }
                }
                
                TreatmentContractSection(patient: $patient, refreshTrigger: $refreshTrigger)
                    .environmentObject(patientStore)
            }
            .padding()
        }
        .sheet(isPresented: $isEditingMasterData) {
            EditPatientView(patient: $patient)
                .environmentObject(patientStore)
        }
    }

    private func resolvedInsuranceName(for id: String) -> String {
        AppGlobals.shared.insuranceList.first(where: { $0.id == id })?.name ?? id
    }
}

struct PatientBasicInfoView: View {
    let title: PatientTitle
    let firstnameTerms: Bool
    let firstname: String
    let lastname: String
    let birthdate: Date
    let sex: Gender

    var body: some View {
        LabeledInfoRow(
            label: "firstnameTerms",
            value: firstnameTerms
                ? NSLocalizedString("useFirstname", comment: "Use firstname")
                : NSLocalizedString("useLastname", comment: "Use lastname"),
            icon: "person.text.rectangle",
            color: .icon
        )
        
        if !title.rawValue.isEmpty {
            LabeledInfoRow(label: "patientTitle", value: title.rawValue, icon: "graduationcap", color: .icon)
        }

        LabeledInfoRow(label: "firstname", value: firstname, icon: "person", color: .icon)
        LabeledInfoRow(label: "lastname", value: lastname, icon: "person.fill", color: .icon)
        LabeledInfoRow(label: "birthdate", value: formattedDate(birthdate), icon: "calendar", color: .icon)
        LabeledInfoRow(label: "gender", value: NSLocalizedString(sex.rawValue, comment: ""), icon: "figure.stand", color: .icon)
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}
