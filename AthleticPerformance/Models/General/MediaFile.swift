//
//  MediaFile.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 27.03.25.
//

import Foundation
import UIKit

/// Represents a media file (such as an image, video, or document) associated with a patient or record.
struct MediaFile: Identifiable, Codable, Hashable {
    /// Unique identifier for the media file.
    var id: UUID // = UUID()

    /// The filename of the media file (e.g., "beckenmobilität.jpg").
    var filename: String

    /// The type of the file (e.g., image, pdf, video).
    var fileType: FileType

    /// The date the file was created or recorded.
    var date: Date

    /// Optional short description of the media file.
    var description: String?

    /// Optional tags for categorizing or searching the file (e.g., ["Mobility", "Pelvis", "Test"]).
    var tags: [String]?

    /// Relative path to the file's storage location (e.g., within a patient folder).
    var relativePath: String
    
    /// Optionale Verknüpfung mit einer Diagnose
    var linkedDiagnosisId: UUID?
}

extension MediaFile {
    /// Initializes a new `MediaFile` with the given parameters.
    /// The `fileType` is automatically determined from the filename extension.
    /// - Parameters:
    ///   - filename: The name of the file.
    ///   - date: The creation or recording date (default is now).
    ///   - description: An optional short description.
    ///   - tags: Optional tags for categorization.
    ///   - relativePath: The relative storage path.
    init(
        id: UUID = UUID(),
        filename: String,
        date: Date = Date(),
        description: String? = nil,
        tags: [String]? = nil,
        relativePath: String,
        linkedDiagnosisId: UUID? = nil
    ) {
        self.id = id
        self.filename = filename
        self.fileType = FileType.from(filename: filename)
        self.date = date
        self.description = description
        self.tags = tags
        self.relativePath = relativePath
        self.linkedDiagnosisId = linkedDiagnosisId
    }
}

extension MediaFile {
    var fullURL: URL {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsURL.appendingPathComponent(self.relativePath)
    }
}

/// Enum representing the type of a media file.
enum FileType: String, Codable {
    /// Image file (e.g., jpg, png, heic).
    case image
    /// Video file (e.g., mp4, mov, avi).
    case video
    /// PDF document.
    case pdf
    /// Audio file (e.g., m4a, mp3).
    case audio
    /// CSV file.
    case csv
    /// Unknown or unsupported file type.
    case unknown
}

extension FileType {
    /// Determines the `FileType` based on the file extension of the given filename.
    /// - Parameter filename: The name of the file.
    /// - Returns: The corresponding `FileType`.
    static func from(filename: String) -> FileType {
        let ext = (filename as NSString).pathExtension.lowercased()
        switch ext {
        case "jpg", "jpeg", "png", "heic": return .image
        case "mp4", "mov", "avi": return .video
        case "pdf": return .pdf
        case "m4a", "mp3": return .audio
        case "csv": return .csv
        default: return .unknown
        }
    }
}
