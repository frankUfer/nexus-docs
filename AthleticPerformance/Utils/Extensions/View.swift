//
//  View.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 06.06.25.
//

import SwiftUI

extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
