//
//  ServiceReadonlyView.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 09.04.25.
//

import SwiftUI

struct ServicesReadonlyView: View {
    let services: [TreatmentService]
    
    var body: some View {
        VStack(spacing: 16) {
            ForEach(Array(services.enumerated()), id: \.element.id) { index, service in
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top, spacing: 12) {
                        // Alle Inhalte links
                        HStack(spacing: 12) {
                            Image(systemName: "tag").foregroundColor(.icon)
                            Text(service.id)
                            
                            Image(systemName: "doc.text").foregroundColor(.icon)
                            Text(service.localizedName(for: Locale.current.language.languageCode?.identifier ?? "en"))
                            
                            if let code = service.billingCode {
                                Image(systemName: "barcode.viewfinder").foregroundColor(.icon)
                                Text(code)
                            }
                            
                            if let quantity = service.quantity {
                                Image(systemName: "clock").foregroundColor(.icon)
                                Text("\(quantity)")
                            }
                            
                            if let unit = service.unit {
                                Text(unit)
                            }
                            
                            if let price = service.price {
                                Image(systemName: "eurosign").foregroundColor(.icon)
                                Text(String(format: "%.2f", price))
                            }
                        }
                        .layoutPriority(1)
                        
                        Spacer()
                        
                        // Rechts: Status
                        Image(systemName: service.isBillable ? "checkmark.circle.fill" : "slash.circle")
                            .foregroundColor(service.isBillable ? .positiveCheck : .gray)
                    }
                    
                    // Nur Divider, wenn es mehr als einen Eintrag gibt UND nicht der letzte ist
                    if services.count > 1 && index < services.count - 1 {
                        Divider()
                            .background(Color.divider.opacity(0.5))
                    }
                }
            }
        }
    }
}
