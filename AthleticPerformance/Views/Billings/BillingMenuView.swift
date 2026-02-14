//
//  BillingMenuView.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 27.03.25.
//

import SwiftUI

struct BillingMenuView: View {
    @Binding var selectedBillingOption: BillingOption?

    var body: some View {
        List(BillingOption.allCases, selection: $selectedBillingOption) { option in
            Label(option.label, systemImage: option.icon)
                .tag(option)
        }
        .navigationTitle(NSLocalizedString("billingMenuTitle", comment: "Billing"))
    }
}

enum BillingOption: String, Hashable, Identifiable, CaseIterable {
    case invoicing
    case claimsManagement

    var id: String { rawValue }

    var label: String {
        switch self {
        case .invoicing: return NSLocalizedString("billingInvoicing", comment: "Invoicing")
        case .claimsManagement: return NSLocalizedString("billingClaims", comment: "Claims Management")
        }
    }

    var icon: String {
        switch self {
        case .invoicing: return "doc.text"
        case .claimsManagement: return "tray.full"
        }
    }
}
