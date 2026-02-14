//
//  ErrorTypes.swift
//  AthleticPerformance
//
//  Created by Frank Ufer on 04.07.25.
//

enum ErrorType: Error {
    case encodingFailed
    case writeFailed
    case decodingFailed
    case readFailed
    case directoryCreationFailed
    case invoiceDirectoryReadFailed
    case patientDirectoryReadFailed
}
