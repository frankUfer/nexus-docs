//
//  editPatient.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 22.03.25.
//

import SwiftUI

struct EditPatientView: View {
    @Binding var patient: Patient
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var patientStore: PatientStore

    // MARK: - View State
    @State private var title: PatientTitle
    @State private var firstnameTerms: Bool
    @State private var firstname: String
    @State private var lastname: String
    @State private var birthdate: Date
    @State private var gender: Gender
    @State private var addresses: [LabeledValue<Address>]
    @State private var phoneNumbers: [LabeledValue<String>]
    @State private var emailAddresses: [LabeledValue<String>]
    @State private var emergencyContacts: [LabeledValue<EmergencyContact>]
    @State private var insuranceStatus: InsuranceStatus
    @State private var insurance: String
    @State private var insuranceNumber: String
    @State private var familyDoctor: String

    // Für neue Versicherung
    @State private var showAddInsuranceSheet = false
    @State private var newInsuranceName: String = ""
    @State private var alertMessage: String = ""
    @State private var showAlert = false

    init(patient: Binding<Patient>) {
        _title = State(initialValue: patient.wrappedValue.title)
        _patient = patient
        _firstnameTerms = State(initialValue: patient.wrappedValue.firstnameTerms)
        _firstname = State(initialValue: patient.wrappedValue.firstname)
        _lastname = State(initialValue: patient.wrappedValue.lastname)
        _birthdate = State(initialValue: patient.wrappedValue.birthdate)
        _gender = State(initialValue: patient.wrappedValue.sex)
        _addresses = State(initialValue: patient.wrappedValue.addresses)
        _phoneNumbers = State(initialValue: patient.wrappedValue.phoneNumbers)
        _emailAddresses = State(initialValue: patient.wrappedValue.emailAddresses)
        _emergencyContacts = State(initialValue: patient.wrappedValue.emergencyContacts)
        _insuranceStatus = State(initialValue: patient.wrappedValue.insuranceStatus)
        _insurance = State(initialValue: patient.wrappedValue.insurance ?? "")
        _insuranceNumber = State(initialValue: patient.wrappedValue.insuranceNumber ?? "")
        _familyDoctor = State(initialValue: patient.wrappedValue.familyDoctor ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                BasicInfoSection(title: $title, firstnameTerms: $firstnameTerms, firstname: $firstname, lastname: $lastname, birthdate: $birthdate, gender: $gender)
                PhoneNumberEntryList(entries: $phoneNumbers, labelOptions: AppGlobals.shared.labelOptions)
                LabeledEmailEntryList(entries: $emailAddresses, titleKey: "emailAddresses", labelOptions: AppGlobals.shared.labelOptions)
                LabeledAddressEntryList(entries: $addresses, titleKey: "addresses", labelOptions: AppGlobals.shared.labelOptions)
                LabeledEmergencyContactList(entries: $emergencyContacts, titleKey: "emergencyContacts", labelOptions: AppGlobals.shared.emergencyContactOptions)
                InsuranceSection(
                    insuranceStatus: $insuranceStatus,
                    insurance: $insurance,
                    insuranceNumber: $insuranceNumber,
                    familyDoctor: $familyDoctor,
                    showAddInsuranceSheet: $showAddInsuranceSheet,
                    patientInsuranceName: patient.insurance
                )
            }
            .navigationTitle(NSLocalizedString("editPatient", comment: ""))
            .toolbar { toolbarContent }
            .sheet(isPresented: $showAddInsuranceSheet) { AddInsuranceSheet }
            .alert(NSLocalizedString("validationError", comment: ""), isPresented: $showAlert) {
                Button(NSLocalizedString("okButton", comment: ""), role: .cancel) {}
            } message: {
                Text(alertMessage)
            }
        }
    }

    private var AddInsuranceSheet: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(NSLocalizedString("newInsuranceName", comment: ""), text: $newInsuranceName)
                }
            }
            .navigationTitle(NSLocalizedString("addInsurance", comment: ""))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("cancel", comment: "")) {
                        showAddInsuranceSheet = false
                    }.foregroundColor(.cancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("save", comment: "Save")) {
                        addNewInsurance()
                    }
                    .foregroundColor(.done)
                    .disabled(newInsuranceName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button(NSLocalizedString("cancel", comment: "")) { dismiss() }
                .foregroundColor(.cancel)
        }
        ToolbarItem(placement: .confirmationAction) {
            Button(NSLocalizedString("save", comment: "")) {
                saveChanges()
                let missingFields = ValidationService.shared.validateRequiredFields(patient)
                if !missingFields.isEmpty {
                    alertMessage = NSLocalizedString("validationFailed", comment: "") + "\n" +
                        missingFields.map { NSLocalizedString($0, comment: "") }.joined(separator: "\n")
                    showAlert = true
                    return
                }
                patientStore.updatePatient(patient)
                dismiss()
            }
            .foregroundColor(.save)
        }
    }

    private func saveChanges() {
        ensureBillingAddress()
        
        patient.title = title
        patient.firstnameTerms = firstnameTerms
        patient.firstname = firstname
        patient.lastname = lastname
        patient.birthdate = birthdate
        patient.sex = gender
        patient.addresses = addresses
        patient.phoneNumbers = phoneNumbers
        patient.emailAddresses = emailAddresses
        patient.emergencyContacts = emergencyContacts
        patient.insuranceStatus = insuranceStatus
        patient.insurance = insurance
        patient.insuranceNumber = insuranceNumber
        patient.familyDoctor = familyDoctor
    }

    private func addNewInsurance() {
        let trimmedName = newInsuranceName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        if AppGlobals.shared.insuranceList.contains(where: { $0.name.localizedCaseInsensitiveCompare(trimmedName) == .orderedSame }) {
            alertMessage = NSLocalizedString("insuranceAlreadyExists", comment: "")
            showAlert = true
            return
        }

        let base = trimmedName.components(separatedBy: .whitespacesAndNewlines).first?.lowercased().filter { $0.isLetter || $0.isNumber }.prefix(3) ?? "xxx"

        var uniqueID = String(base)
        var suffix = 1
        while AppGlobals.shared.insuranceList.contains(where: { $0.id == uniqueID }) {
            uniqueID = String(base) + String(suffix)
            suffix += 1
        }

        let newCompany = InsuranceCompany(id: uniqueID, name: trimmedName)
        AppGlobals.shared.insuranceList.append(newCompany)

        do {
            try saveParameterList(AppGlobals.shared.insuranceList, fileName: "insurances")
        } catch {
            alertMessage = NSLocalizedString("couldNotSaveInsurance", comment: "")
            showAlert = true
            return
        }

        insurance = newCompany.name
        newInsuranceName = ""
        showAddInsuranceSheet = false
    }
    
    private func ensureBillingAddress() {
        // Keine Adressen? Nichts tun
        guard !addresses.isEmpty else { return }

        var billingFound = false

        for index in addresses.indices {
            if addresses[index].value.isBillingAddress {
                if !billingFound {
                    // Erste gefundene Rechnungsadresse akzeptieren
                    billingFound = true
                } else {
                    // Weitere Rechnungsadressen deaktivieren
                    addresses[index].value.isBillingAddress = false
                }
            }
        }

        // Falls keine Rechnungsadresse gefunden wurde: erste Adresse setzen
        if !billingFound {
            addresses[0].value.isBillingAddress = true
        }
    }
}

private struct BasicInfoSection: View {
    @Binding var title: PatientTitle
    @Binding var firstnameTerms: Bool
    @Binding var firstname: String
    @Binding var lastname: String
    @Binding var birthdate: Date
    @Binding var gender: Gender

    var body: some View {
        Section(header: Text(NSLocalizedString("basicInfo", comment: ""))) {
            
            BoolSwitch(
                value: $firstnameTerms,
                label: firstnameTerms
                    ? NSLocalizedString("useFirstname", comment: "Use firstname")
                    : NSLocalizedString("useLastname", comment: "Use lastname")
            )
            
            Picker(NSLocalizedString("patientTitle", comment: "Title of patient"), selection: $title) {
                ForEach(PatientTitle.allCases, id: \.self) { t in
                    Text(t.rawValue.isEmpty ? "" : t.rawValue)
                        .tag(t)
                }
            }
            TextField(NSLocalizedString("firstname", comment: ""), text: $firstname)
            TextField(NSLocalizedString("lastname", comment: ""), text: $lastname)
            DatePicker(NSLocalizedString("birthdate", comment: ""), selection: $birthdate, displayedComponents: .date)
            Picker(NSLocalizedString("gender", comment: ""), selection: $gender) {
                ForEach(Gender.allCases, id: \.self) { g in
                    Text(NSLocalizedString(g.rawValue, comment: "")).tag(g)
                }
            }
        }
    }
}

private struct InsuranceSection: View {
    @Binding var insuranceStatus: InsuranceStatus
    @Binding var insurance: String
    @Binding var insuranceNumber: String
    @Binding var familyDoctor: String
    @Binding var showAddInsuranceSheet: Bool

    var patientInsuranceName: String?

    var body: some View {
        Section(header: Text(NSLocalizedString("insuranceInformation", comment: ""))) {
            Picker(NSLocalizedString("insuranceStatus", comment: ""), selection: $insuranceStatus) {
                ForEach(InsuranceStatus.allCases, id: \.self) { status in
                    Text(NSLocalizedString(status.rawValue, comment: "")).tag(status)
                }
            }

            Picker(NSLocalizedString("insurance", comment: ""), selection: $insurance) {
                ForEach(AppGlobals.shared.insuranceList.sorted(by: { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }), id: \.id) { company in
                    Text(company.name).tag(company.name)
                }
                Divider()
                    .background(Color.divider.opacity(0.5))
                Text("\u{1F7E2} " + NSLocalizedString("addInsurance", comment: "")).tag("__add__")
            }
            .onChange(of: insurance) { oldValue, newValue in
                if newValue == "__add__" {
                    showAddInsuranceSheet = true
                    insurance = patientInsuranceName ?? ""
                }
            }

            TextField(NSLocalizedString("insuranceNumber", comment: ""), text: $insuranceNumber)
            TextField(NSLocalizedString("familyDoctor", comment: ""), text: $familyDoctor)
        }
    }
}
