//
//  LiveImageView.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 18.04.25.
//

import SwiftUI

struct LiveImageView: View {
    var image: UIImage?
    
    var body: some View {
        GeometryReader { geometry in
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
            } else {
                Color.black
                    .overlay(Text("Kein Bild").foregroundColor(.gray))
            }
        }
    }
}
