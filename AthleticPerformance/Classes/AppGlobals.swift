//
//  AppGlobals.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 19.03.25.
//

import Foundation

class AppGlobals: ObservableObject {
    static let shared = AppGlobals()

    let parametersURL: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs
            .appendingPathComponent("resources", isDirectory: true)
            .appendingPathComponent("parameter", isDirectory: true)
    }()
    
    @Published var practiceInfo: PracticeInfo = PracticeInfo(
        id: 1,
        name: "",
        address: Address.empty(),
        startAddress: Address.empty(),
        phone: "",
        email: "",
        website: "",
        taxNumber: "",
        bank: "",
        iban: "",
        bic: "",
        therapists: [],
        services: []
    )
    
    @Published var publicAddresses: [PublicAddress] = []
    
    var paymentTerms: Int = 14
    var taxRate: Double = 0.00
    var calendarName: String = "Athletic Performance"
    var alertMinutesBefore: Int = 1500 // 1 and 1 hour day before
    var maxSessionsPerDay: Int = 4
    let maxSessionBlockDuration: Int = 120
    var travelBuffer: Int = 15
    var insuranceList: [InsuranceCompany] = []
    var therapistList: [Therapists] = []
    var therapistId: UUID? = nil
    var treatmentServices: [TreatmentService] = []
    var specialties: [Specialty] = []
    var physioReferenceData: PhysioReferenceData = .empty
    var diagnoseReferenceData: DiagnoseReferenceData = .empty
    
    // Postalcodes and Cities
    var postalcodesCities: [PostalcodeCity] = [] {
           didSet { rebuildPostalCodeIndex() }   // <-- Index automatisch neu aufbauen
       }
    // 2) Indizes für O(1)-Checks
    private(set) var postalCodeIndex: [String: Set<String>] = [:]
    private(set) var postalCityPairs: Set<String> = []
    
    var assessments: [Assessments] = []
    var endFeelings: [EndFeelings] = []
    var jointMovementPatterns: [JointMovementPattern] = []
    var jointsData: [Joints] = []
    var muscleGroupsData: [MuscleGroups] = []
    var painQualities: [PainQualities] = []
    var painStructure: [PainStructures] = []
    var tissueStatesData: [TissueStates] = []
    var tissuesData: [Tissues] = []
    var bodyRegionGroups: [BodyRegionSelectionGroup] {
            physioReferenceData.bodyRegions.map {
                BodyRegionSelectionGroup(region: $0, selectedParts: [])
            }
        }
    
    let labelOptions: [String] = ["private", "work", "other"]
    let emergencyContactOptions: [String] = ["spouse", "partner", "parent", "sibling", "child", "relative", "friend", "familyDoctor", "other"]

    private init() {}
    
    func isValidPostalCityCombination(_ postalCode: String, _ city: String) -> Bool {
            let plz = postalCode.filter(\.isNumber)                               // robust: nur Ziffern
            let key = "\(plz)#\(city.lowercased().trimmingCharacters(in: .whitespacesAndNewlines))"
            return postalCityPairs.contains(key)
        }

        func cities(for postalCode: String) -> [String] {
            let plz = postalCode.filter(\.isNumber)
            return Array(postalCodeIndex[plz] ?? [])
        }

        // 4) Index-Aufbau (wird vom didSet getriggert)
        private func rebuildPostalCodeIndex() {
            var byPLZ: [String: Set<String>] = [:]
            var pairs: Set<String> = []

            for entry in postalcodesCities {
                // entry.postalCode ist dank deines Initializers bereits 5-stellig gepaddet
                let plz = entry.postalCode
                let city = entry.city.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                guard plz.count == 5, !city.isEmpty else { continue }

                byPLZ[plz, default: []].insert(city)
                pairs.insert("\(plz)#\(city)")
            }

            postalCodeIndex = byPLZ
            postalCityPairs = pairs
        }
}
