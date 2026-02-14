//
//  MuscleTone.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 08.05.25.
//

enum MuscleTone: Int, CaseIterable, Codable, Identifiable {
    case minus3 = -3
    case minus2 = -2
    case minus1 = -1
    case zero   = 0
    case plus1  = 1
    case plus2  = 2
    case plus3  = 3

    var id: Int { rawValue }

    var displayValue: String {
        switch self {
        case .minus3: return "---"
        case .minus2: return "--"
        case .minus1: return "-"
        case .zero:   return "0"
        case .plus1:  return "+"
        case .plus2:  return "++"
        case .plus3:  return "+++"
        }
    }

    static func from(raw: Int) -> MuscleTone {
        MuscleTone(rawValue: raw) ?? (raw < 0 ? .minus3 : .plus3)
    }
}
