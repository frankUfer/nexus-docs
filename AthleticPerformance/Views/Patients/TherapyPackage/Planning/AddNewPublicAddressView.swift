//
//  AddNewPublicAddressView.swift
//  AthleticPerformance
//
//  Created by Frank Ufer on 03.07.25.
//

import SwiftUI

struct AddNewPublicAddressView: View {
    @State private var name = ""
    @State private var label = ""
    @State private var street = ""
    @State private var postalCode = ""
    @State private var city = ""
    @State private var country = "Deutschland"

    let onSave: (PublicAddress) -> Void
    let onCancel: () -> Void

    var body: some View {
        Form {
            TextField(NSLocalizedString("category", comment: "Category"), text: $label)
            TextField(NSLocalizedString("publicAddressName", comment: "Public address name"), text: $name)
            TextField(NSLocalizedString("street", comment: "Street"), text: $street)
            TextField(NSLocalizedString("postalCode", comment: "postal code"), text: $postalCode)
            TextField(NSLocalizedString("city", comment: "City"), text: $city)
            TextField(NSLocalizedString("country", comment: "Country"), text: $country)

            HStack {
                Button(NSLocalizedString("cancel", comment: "Cancel")) {
                    onCancel()
                }
                Spacer()
                Button(NSLocalizedString("save", comment: "Save")) {
                    let new = PublicAddress(
                        label: label,
                        name: name,
                        address: Address(
                            street: street,
                            postalCode: postalCode,
                            city: city,
                            country: country
                        )
                    )
                    onSave(new)
                }
                .disabled(name.isEmpty || label.isEmpty || street.isEmpty)
            }
        }
        .navigationTitle(NSLocalizedString("addNewAddress", comment: "Add new address"))
    }
}
