//
//  FiexedHeightSheet.swift
//  AthleticPerformance
//
//  Created by Frank Ufer on 12.06.25.
//

import SwiftUI

struct FixedHeightSheet<Content: View>: View {
    let height: CGFloat
    let id: UUID
    let content: () -> Content

    var body: some View {
        content()
            .presentationDetents([.height(height)])
            .presentationDragIndicator(.visible)
            .id(id)
    }
}
