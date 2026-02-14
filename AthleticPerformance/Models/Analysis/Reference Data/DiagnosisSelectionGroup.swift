//
//  DiagnosisSelectionGroup.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 22.04.25.
//

struct DiagnosisSelectionGroup: Codable, Hashable {
    var category: DiagnoseCategory
    var selectedTerms: [DiagnoseTerm]
}
