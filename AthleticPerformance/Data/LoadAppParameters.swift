//
//  loadAppParameters.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 27.03.25.
//

import Foundation

/// Loads all application parameters from the documents directory into global app state.
/// - Returns: `true` if all main parameter files were loaded successfully, otherwise `false`.
func loadAppParameters() -> Bool {
    let fileManager = FileManager.default

    // Get the application's document directory.
    guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
        showErrorAlert(errorMessage: NSLocalizedString("errorDocumentFolderNotFound", comment: "Could not find document directory"))
        return false
    }

    // Build the path to the parameters folder.
    let parametersURL = documentsURL
        .appendingPathComponent("resources")
        .appendingPathComponent("parameter")
    
    var success = true
    
    // MARK: - Load public addresses
    if let file: PublicAddressFile = loadJSON(from: parametersURL.appendingPathComponent(ParameterFile.publicAddresses.rawValue)) {
        AppGlobals.shared.publicAddresses = file.items
    } else {
        success = false
    }
            
    // MARK: - Load public addresses
    if let file: PublicAddressFile = loadJSON(from: parametersURL.appendingPathComponent(ParameterFile.publicAddresses.rawValue)) {
        AppGlobals.shared.publicAddresses = file.items
    } else {
        success = false
    }

    // MARK: - Load Insurances
    if let file: InsuranceCompanyFile = loadJSON(from: parametersURL.appendingPathComponent(ParameterFile.insurances.rawValue)) {
        AppGlobals.shared.insuranceList = file.items
    } else {
        success = false
    }

    // MARK: - Load Practice Info
    if let file: PracticeInfoFile = loadJSON(from: parametersURL.appendingPathComponent(ParameterFile.practiceInfo.rawValue)) {
        if let practice = file.items.first {
            AppGlobals.shared.practiceInfo = practice
            AppGlobals.shared.therapistList = practice.therapists
            AppGlobals.shared.treatmentServices = practice.services
        } else {
            success = false
        }
    } else {
        success = false
    }

    // MARK: - Load Specialties
    if let file: SpecialtyFile = loadJSON(from: parametersURL.appendingPathComponent(ParameterFile.specialties.rawValue)) {
        var specialties = file.items
        specialties.sort { $0.localizedName() < $1.localizedName() }
        AppGlobals.shared.specialties = specialties
    } else {
        success = false
    }

    // MARK: - Load Physio Reference Data
    if let file: PhysioReferenceDataFile = loadJSON(from: parametersURL.appendingPathComponent(ParameterFile.physioReferenceData.rawValue)) {
        if let data = file.items.first {
            AppGlobals.shared.physioReferenceData = data
        } else {
            success = false
        }
    } else {
        success = false
    }
    
    // MARK: - Load Diagnose Reference Data
    if let file: DiagnoseReferenceDataFile = loadJSON(from: parametersURL.appendingPathComponent(ParameterFile.diagnoseReferenceData.rawValue)) {
        if let data = file.items.first {
            AppGlobals.shared.diagnoseReferenceData = data
        } else {
            success = false
        }
    } else {
        success = false
    }
            
    // MARK: - Load Assessment Data
    if let file: AssessmentFile = loadJSON(from: parametersURL.appendingPathComponent(ParameterFile.assessmentsData.rawValue)) {
        AppGlobals.shared.assessments = file.items.sorted {
            $0.localized().localizedCaseInsensitiveCompare($1.localized()) == .orderedAscending
        }
    } else {
        success = false
    }
    
    // MARK: - Load End Feelings Data
    if let file: EndFeelingsFile = loadJSON(from: parametersURL.appendingPathComponent(ParameterFile.endFeelingsData.rawValue)) {
        AppGlobals.shared.endFeelings = file.items.sorted {
            $0.localized().localizedCaseInsensitiveCompare($1.localized()) == .orderedAscending
        }
    } else {
        success = false
    }
    
    // MARK: - Load Joint Movement Patterns Data
    if let file: JointMovementPatternFile = loadJSON(from: parametersURL.appendingPathComponent(ParameterFile.jointMovementPatternsData.rawValue)) {
        AppGlobals.shared.jointMovementPatterns = file.items.sorted {
            $0.de.localizedCaseInsensitiveCompare($1.de) == .orderedAscending
        }
    } else {
        success = false
    }
    
    // MARK: - Load Joints Data
    if let file: JointsFile = loadJSON(from: parametersURL.appendingPathComponent(ParameterFile.jointsData.rawValue)) {
        AppGlobals.shared.jointsData = file.items.sorted {
            $0.de.localizedCaseInsensitiveCompare($1.de) == .orderedAscending
        }
    } else {
        success = false
    }
    
    // MARK: - Load Muscle Groups Data
    if let file: MuscleGroupsFile = loadJSON(from: parametersURL.appendingPathComponent(ParameterFile.muscleGroupsdata.rawValue)) {
        AppGlobals.shared.muscleGroupsData = file.items.sorted {
            $0.de.localizedCaseInsensitiveCompare($1.de) == .orderedAscending
        }
    } else {
        success = false
    }
    
    // MARK: - Load Pain Qualities Data
    if let file: PainQualitiesFile = loadJSON(from: parametersURL.appendingPathComponent(ParameterFile.painQualitiesData.rawValue)) {
        AppGlobals.shared.painQualities = file.items.sorted {
            $0.de.localizedCaseInsensitiveCompare($1.de) == .orderedAscending
        }
    } else {
        success = false
    }
    
    // MARK: - Load Pain Structures Data
    if let file: PainStructuresFile = loadJSON(from: parametersURL.appendingPathComponent(ParameterFile.painStructuresData.rawValue)) {
        AppGlobals.shared.painStructure = file.items.sorted {
            $0.de.localizedCaseInsensitiveCompare($1.de) == .orderedAscending
        }
    } else {
        success = false
    }
    
    // MARK: - Load Tissue States Data
    if let file: TissueStatesFile = loadJSON(from: parametersURL.appendingPathComponent(ParameterFile.tissueStatesData.rawValue)) {
        AppGlobals.shared.tissueStatesData = file.items.sorted {
            $0.de.localizedCaseInsensitiveCompare($1.de) == .orderedAscending
        }
    } else {
        success = false
    }
    
    // MARK: - Load Tissues Data
    if let file: TissuesFile = loadJSON(from: parametersURL.appendingPathComponent(ParameterFile.tissuesData.rawValue)) {
        AppGlobals.shared.tissuesData = file.items.sorted {
            $0.de.localizedCaseInsensitiveCompare($1.de) == .orderedAscending
        }
    } else {
        success = false
    }
        
    // MARK: - Load Therapist ID Separately
    let therapistIDFile = parametersURL.appendingPathComponent(ParameterFile.therapistReference.rawValue)
    if let file: TherapistReferenceFile = loadJSON(from: therapistIDFile),
       let ref = file.items.first {
        AppGlobals.shared.therapistId = ref.id
    } else {
        showErrorAlert(errorMessage: NSLocalizedString("therapistIdInvalid", comment: "Therapist ID is invalid."))
    }

    // MARK: - Validate Therapist ID
    if let id = AppGlobals.shared.therapistId,
       !AppGlobals.shared.therapistList.contains(where: { $0.id == id }) {
        showErrorAlert(errorMessage: NSLocalizedString("therapistIdInvalid", comment: "Therapist ID is invalid."))
    }

    return success
}

// CSV-Lader für PLZ↔Ort
private func loadPostalcodeCitiesCSV(from url: URL) -> [PostalcodeCity]? {
    guard FileManager.default.fileExists(atPath: url.path) else { return nil }
    guard let raw = try? String(contentsOf: url, encoding: .utf8) else { return nil }

    var result: [PostalcodeCity] = []
    var lineNo = 0

    // Split in Zeilen (unterstützt \n und \r\n)
    raw.enumerateLines { line, stop in
        lineNo += 1
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return }                             // leere Zeilen ignorieren
        if lineNo == 1, trimmed.lowercased().hasPrefix("plz") {   // Header überspringen
            return
        }

        // simple CSV: plz;ort — keine Quotes, kein Escaping
        // Falls du Quotes brauchst: später erweitern
        let parts = trimmed.split(separator: ";", omittingEmptySubsequences: false).map { String($0) }
        guard parts.count >= 2 else { return }

        let plzRaw = parts[0]
        let cityRaw = parts[1]

        // Dein init() normalisiert: nur Ziffern + Zero-Padding auf 5
        let entry = PostalcodeCity(postalCode: plzRaw, city: cityRaw)
        // nur 5-stellige PLZ akzeptieren (nach Padding)
        guard entry.postalCode.count == 5 else { return }
        result.append(entry)
    }

    return result
}
