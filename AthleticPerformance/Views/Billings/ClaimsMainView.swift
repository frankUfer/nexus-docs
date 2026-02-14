//
//  ClaimsMainView.swift
//  AthleticPerformance
//
//  Created by Frank Ufer on 07.07.25.
//

import SwiftUI

struct ClaimsMainView: View {
    @State private var parseResult: String = ""
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 20) {
            Text("Kontoauszüge einlesen")
                .font(.headline)

            Button {
                // runParser()
            } label: {
                Label("Kontoauszüge verarbeiten", systemImage: "doc.text.magnifyingglass")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            if !parseResult.isEmpty {
                ScrollView {
                    Text(parseResult)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            }

            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.leading)
            }

            Spacer()
        }
        .padding()
        .navigationTitle("Claims Management")
    }
}
