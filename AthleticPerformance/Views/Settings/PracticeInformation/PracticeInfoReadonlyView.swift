//
//  PracticeInfoReadonlyView.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 09.04.25.
//

import SwiftUI

struct PracticeInfoReadonlyView: View {
    let practice: PracticeInfo
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 🔹 Name
            IconValueRow(icon: "building.2", color: .icon, value: practice.name)
            
            // 🔹 Street
            IconValueRow(icon: "house", color: .icon, value: practice.address.street)
            
            // 🔹 ZIP + City
            if !practice.address.postalCode.isEmpty || !practice.address.city.isEmpty {
                let cityLine = [practice.address.postalCode, practice.address.city].filter { !$0.isEmpty }.joined(separator: " ")
                IconValueRow(icon: "map", color: .icon, value: cityLine)
            }
            
            // 🔹 Telephone
            if !practice.phone.isEmpty {
                IconValueRow(icon: "phone", color: .icon, value: practice.phone)
            }
            
            // 🔹 E-Mail
            if !practice.email.isEmpty {
                IconValueRow(icon: "envelope", color: .icon, value: practice.email)
            }
            
            // 🔹 Website
            if !practice.website.isEmpty {
                IconValueRow(icon: "globe", color: .icon, value: practice.website)
            }
            
            // 🔹 Steuer-Nr
            if !practice.taxNumber.isEmpty {
                IconValueRow(icon: "number", color: .icon, value: practice.taxNumber)
            }
            
            // 🔹 Bank
            if !practice.bank.isEmpty {
                IconValueRow(icon: "banknote", color: .icon, value: practice.bank)
            }
            
            // 🔹 IBAN
            if !practice.iban.isEmpty {
                IconValueRow(icon: "creditcard", color: .icon, value: practice.iban)
            }
            
            // 🔹 BIC
            if !practice.bic.isEmpty {
                IconValueRow(icon: "creditcard.fill", color: .icon, value: practice.bic)
            }
            
            // Start address for visits of patients
            if !practice.startAddress.street.isEmpty {
                Divider()
                    .background(Color.divider.opacity(0.5))
            }
            
            if !practice.startAddress.street.isEmpty {
                Text(NSLocalizedString("startAddress", comment: "Start address"))
            }
            
            // Street
            if !practice.startAddress.street.isEmpty {
                IconValueRow(icon: "house", color: .icon, value: practice.startAddress.street)
                
                // 🔹 ZIP + City
                if !practice.startAddress.postalCode.isEmpty || !practice.startAddress.city.isEmpty {
                    let cityLine = [practice.startAddress.postalCode, practice.startAddress.city].filter { !$0.isEmpty }.joined(separator: " ")
                    IconValueRow(icon: "map", color: .icon, value: cityLine)
                }
            }
        }
    }
    
    struct IconValueRow: View {
        let icon: String
        let color: Color
        let value: String
        
        var body: some View {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .frame(width: 20, alignment: .leading)
                
                Text(value)
                    .font(.body)
                    .multilineTextAlignment(.leading)
                
                Spacer(minLength: 0)
            }
        }
    }
}
