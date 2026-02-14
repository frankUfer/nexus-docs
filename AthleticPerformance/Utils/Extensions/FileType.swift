//
//  FileType.swift
//  AthleticPerformance
//
//  Created by Frank Ufer on 09.10.25.
//

extension FileType {
    var preferredExtension: String {
        switch self {
        case .image: return "jpg" 
        case .pdf:   return "pdf"
        case .csv:   return "csv"
        default:     return "bin"
        }
    }
}
