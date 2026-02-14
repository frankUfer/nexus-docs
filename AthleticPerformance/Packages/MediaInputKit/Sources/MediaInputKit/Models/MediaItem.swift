//
//  MediaItem.swift
//  MediaInputKit
//
//  Created by Frank Ufer on 11.04.25.
//
// Zentrales Modell für Foto, Video, Scan, Zeichnung

import SwiftUI

public struct MediaItem: Identifiable, Codable {
    public enum MediaType: String, Codable {
        case photo, video, scannedDocument, drawing
    }

    public let id: UUID
    public let type: MediaType
    public var thumbnailData: Data
    public var contentURL: URL

    public var thumbnail: UIImage {
        UIImage(data: thumbnailData) ?? UIImage(systemName: "photo")!
    }

    public init(id: UUID = UUID(), type: MediaType, thumbnail: UIImage, contentURL: URL) {
        self.id = id
        self.type = type
        self.thumbnailData = thumbnail.jpegData(compressionQuality: 0.8) ?? Data()
        self.contentURL = contentURL
    }
}
