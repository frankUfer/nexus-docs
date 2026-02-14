//
//  PDFPreviewView.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 07.05.25.
//

import SwiftUI
import PDFKit

struct PDFPreviewView: View {
    let url: URL
    var body: some View {
        PDFKitView(url: url)
            .edgesIgnoringSafeArea(.all)
    }
}
