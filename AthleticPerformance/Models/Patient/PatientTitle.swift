//
//  PatientTitle.swift
//  AthleticPerformance
//
//  Created by Frank Ufer on 23.06.25.
//

enum PatientTitle: String, Codable, CaseIterable {
    case none = ""
    case dr = "Dr."
    case prof = "Prof."
    case profDr = "Prof. Dr."
}
