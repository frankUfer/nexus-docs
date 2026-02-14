//
//  PhotoPickerView.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 24.04.25.
//

import SwiftUI
import PhotosUI

struct PhotoPickerView: View {
    @Binding var isPresented: Bool
    var onItemSelected: (PhotosPickerItem) -> Void

    @State private var selectedItem: PhotosPickerItem? = nil

    var body: some View {
        PhotosPicker(
            selection: $selectedItem,
            matching: .any(of: [.images, .videos]),
            photoLibrary: .shared()
        ) {
            EmptyView()
        }
        .onChange(of: selectedItem) { oldItem, newItem in
            guard let item = newItem else { return }
            isPresented = false
            onItemSelected(item)
        }
        .photosPicker(isPresented: $isPresented,
                      selection: $selectedItem,
                      matching: .any(of: [.images, .videos]),
                      photoLibrary: .shared())
    }
}
