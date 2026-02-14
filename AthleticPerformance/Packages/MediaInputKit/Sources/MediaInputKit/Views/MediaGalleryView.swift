//
//  MediaGalleryView.swift
//  MediaInputKit
//
//  Created by Frank Ufer on 11.04.25.
//
// Zeigt die Medien als Vorschaubilder

import SwiftUI

public struct MediaGalleryView: View {
    @Binding var mediaItems: [MediaItem]

    public init(mediaItems: Binding<[MediaItem]>) {
        self._mediaItems = mediaItems
    }

    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(mediaItems) { item in
                    Image(uiImage: item.thumbnail)
                        .resizable()
                        .frame(width: 100, height: 100)
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.gray))
                }
            }
        }
        .frame(height: 120)
    }
}
