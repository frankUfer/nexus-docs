//
//  AddPatientView.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 19.03.25.
//

import SwiftUI

struct AddPatientView: View {
    @ObservedObject var patientStore: PatientStore
    @EnvironmentObject var navigationStore: AppNavigationStore
    @Environment(\.presentationMode) var presentationMode

    // MARK: - Patientendaten
    @State private var title: PatientTitle = .none
    @State private var firstnameTerms: Bool = false
    @State private var firstname: String = ""
    @State private var lastname: String = ""
    @State private var birthdate: Date = Date()
    @State private var gender: Gender = .unknown
    @State private var profession: String = ""
    @State private var sports: String = ""
    @State private var hobbies: String = ""

    // MARK: - Versicherung
    @State private var insuranceStatus: InsuranceStatus = .selfPaying
    @State private var insurance: InsuranceCompany = AppGlobals.shared.insuranceList.first ?? InsuranceCompany(id: "default", name: "")
    @State private var insuranceNumber: String = ""
    @State private var familyDoctor: String = ""

    // MARK: - Kontakte
    @State private var phoneNumbers: [LabeledValue<String>] = []
    @State private var emailAddresses: [LabeledValue<String>] = []
    @State private var addresses: [LabeledValue<Address>] = []
    @State private var emergencyContacts: [LabeledValue<EmergencyContact>] = []

    // MARK: - UI States
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var showAddInsuranceSheet = false
    @State private var newInsuranceName: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text(NSLocalizedString("basicInfo", comment: "Basic info"))) {
                    
                    BoolSwitch(
                        value: $firstnameTerms,
                        label: firstnameTerms
                            ? NSLocalizedString("useFirstname", comment: "Use firstname")
                            : NSLocalizedString("useLastname", comment: "Use lastname")
                    )
                    
                    Picker(NSLocalizedString("patientTitle", comment: "Title of Patient"), selection: $title) {
                        ForEach(PatientTitle.allCases, id: \.self) { t in
                            Text(t.rawValue.isEmpty ? "" : t.rawValue)
                                .tag(t)
                        }
                    }
                    TextField(NSLocalizedString("firstname", comment: "Firstname"), text: $firstname)
                    TextField(NSLocalizedString("lastname", comment: "Lastname"), text: $lastname)
                    DatePicker(NSLocalizedString("birthdate", comment: "Birthdate"), selection: $birthdate, displayedComponents: .date)
                    Picker(NSLocalizedString("gender", comment: "Gender"), selection: $gender) {
                        ForEach(Gender.allCases, id: \.self) { g in
                            Text(NSLocalizedString(g.rawValue, comment: "")).tag(g)
                        }
                    }
                }
               
                PhoneNumberEntryList(entries: $phoneNumbers, labelOptions: AppGlobals.shared.labelOptions)
                LabeledEmailEntryList(entries: $emailAddresses, titleKey: "emailAddresses", labelOptions: AppGlobals.shared.labelOptions)
                LabeledAddressEntryList(entries: $addresses, titleKey: "addresses", labelOptions: AppGlobals.shared.labelOptions)
                LabeledEmergencyContactList(entries: $emergencyContacts, titleKey: "emergencyContacts", labelOptions: AppGlobals.shared.emergencyContactOptions)

                Section(header: Text(NSLocalizedString("insuranceInformation", comment: "Insurance information"))) {
                    Picker(NSLocalizedString("insuranceStatus", comment: "Insurance status"), selection: $insuranceStatus) {
                        ForEach(InsuranceStatus.allCases, id: \.self) { status in
                            Text(NSLocalizedString(status.rawValue, comment: "")).tag(status)
                        }
                    }

                    Picker(NSLocalizedString("insurance", comment: "Insurance"), selection: $insurance) {
                        ForEach(AppGlobals.shared.insuranceList.sorted(by: { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }), id: \.id) { company in
                            Text(company.name).tag(company)
                        }
                        
                        Divider()
                        .background(Color.divider.opacity(0.5))
                        
                        Text("🟢 " + NSLocalizedString("addInsurance", comment: "Add insurance"))
                            .tag("__add__")
                    }
                    .onChange(of: insurance) { oldValue, newValue in
                        if newValue.id == "new" {
                            showAddInsuranceSheet = true
                            insurance = AppGlobals.shared.insuranceList.first ?? InsuranceCompany(id: "", name: "")
                        }
                    }

                    TextField(NSLocalizedString("insuranceNumber", comment: "Insurance number"), text: $insuranceNumber)
                    TextField(NSLocalizedString("familyDoctor", comment: "Family doctor"), text: $familyDoctor)
                }
            }
            .navigationTitle(NSLocalizedString("addPatient", comment: "Add Patient"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("cancel", comment: "Cancel")) {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("save", comment: "Save")) {
                        Task { await savePatient() }
                    }
                    .foregroundColor(.done)
                }
            }
            .alert(NSLocalizedString("validationError", comment: "Validation error"), isPresented: $showAlert) {
                Button(NSLocalizedString("okButton", comment: "Ok button"), role: .cancel) {}
            } message: {
                Text(alertMessage)
            }
            .sheet(isPresented: $showAddInsuranceSheet) {
                NavigationStack {
                    Form {
                        TextField(NSLocalizedString("insuranceName", comment: "Insurance name"), text: $newInsuranceName)
                    }
                    .navigationTitle(NSLocalizedString("addInsurance", comment: "Add insurance"))
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button(NSLocalizedString("cancel", comment: "Cancel")) {
                                showAddInsuranceSheet = false
                                newInsuranceName = ""
                            }
                            .foregroundColor(.cancel)
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button(NSLocalizedString("save", comment: "Save")) {
                                addNewInsurance()
                            }
                            .foregroundColor(.save)
                            .disabled(newInsuranceName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                }
            }
        }
        .interactiveDismissDisabled(true)
    }

    @MainActor
    private func savePatient() async {
        ensureBillingAddress()
        let newPatient = Patient(
            id: UUID(),
            title: title,
            firstnameTerms:  firstnameTerms,
            firstname: firstname,
            lastname: lastname,
            birthdate: birthdate,
            sex: gender,
            insuranceStatus: insuranceStatus,
            insurance: insurance.name,
            insuranceNumber: insuranceNumber,
            familyDoctor: familyDoctor,
            anamnesis: nil,
            therapies: [],
            isActive: true,
            addresses: addresses,
            phoneNumbers: phoneNumbers,
            emailAddresses: emailAddresses,
            emergencyContacts: emergencyContacts,
            createdDate: Date(),
            changedDate: Date()
        )
                
        let originalList = ValidationService.shared.validateRequiredFields(newPatient)
        let missingFields = originalList.reduce(into: [String]()) { uniqueList, field in
            if !uniqueList.contains(field) {
                uniqueList.append(field)
            }
        }

        if !missingFields.isEmpty {
            alertMessage = "\n" + missingFields.map { NSLocalizedString($0, comment: $0) }.joined(separator: "\n")
            showAlert = true
            return
        }
        
        await patientStore.addPatient(newPatient)
        navigationStore.selectedPatientID = newPatient.id
        presentationMode.wrappedValue.dismiss()
    }

    private func addNewInsurance() {
        let trimmedName = newInsuranceName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        if AppGlobals.shared.insuranceList.contains(where: { $0.name.localizedCaseInsensitiveCompare(trimmedName) == .orderedSame }) {
            alertMessage = NSLocalizedString("insuranceAlreadyExists", comment: "Insurance already exists")
            showAlert = true
            return
        }

        let idRoot = trimmedName.components(separatedBy: .whitespaces).first?.lowercased().filter { $0.isLetter || $0.isNumber }.prefix(3) ?? "new"
        var uniqueID = String(idRoot)
        var counter = 1
        while AppGlobals.shared.insuranceList.contains(where: { $0.id == uniqueID }) {
            uniqueID = "\(idRoot)\(counter)"
            counter += 1
        }

        let newCompany = InsuranceCompany(id: uniqueID, name: trimmedName)
        AppGlobals.shared.insuranceList.append(newCompany)

        do {
            try saveParameterList(AppGlobals.shared.insuranceList, fileName: "insurances")
        } catch {
            alertMessage = NSLocalizedString("saveFailed", comment: "Saving failed") + ": \(error.localizedDescription)"
            showAlert = true
            return
        }

        insurance = newCompany
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
