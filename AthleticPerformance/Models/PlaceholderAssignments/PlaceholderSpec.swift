//
//  PlaceholderSpec.swift
//  AthleticPerformance
//
//  Created by Frank Ufer on 07.07.25.
//

import Foundation

struct PlaceholderSpec {
    let key: String
    let valueBuilder: (PlaceholderContext) -> String
}

struct PlaceholderContext {
    let practice: PracticeInfo
    let patient: Patient
    let patientAddress: Address?
    let place: String
    let dateString: String
    let therapy: Therapy
}

let defaultPlaceholderSpecs: [PlaceholderSpec] = [
    PlaceholderSpec(
        key: "[[PRACTICE_NAME]]",
        valueBuilder: { ctx in ctx.practice.name }
    ),
    PlaceholderSpec(
        key: "[[PRACTICE_STREET]]",
        valueBuilder: { ctx in ctx.practice.address.street }
    ),
    PlaceholderSpec(
        key: "[[PRACTICE_POSTALCODE]]",
        valueBuilder: { ctx in ctx.practice.address.postalCode }
    ),
    PlaceholderSpec(
        key: "[[PRACTICE_CITY]]",
        valueBuilder: { ctx in ctx.practice.address.city }
    ),
    PlaceholderSpec(
        key: "[[PRACTICE_PHONE]]",
        valueBuilder: { ctx in ctx.practice.phone }
    ),
    PlaceholderSpec(
        key: "[[PRACTICE_EMAIL]]",
        valueBuilder: { ctx in ctx.practice.email }
    ),
    PlaceholderSpec(
        key: "[[TITLE]]",
        valueBuilder: { ctx in
            ctx.patient.title.rawValue.isEmpty ? "" : "\(ctx.patient.title.rawValue) "
        }
    ),
    PlaceholderSpec(
        key: "[[FIRSTNAME]]",
        valueBuilder: { ctx in ctx.patient.firstname }
    ),
    PlaceholderSpec(
        key: "[[LASTNAME]]",
        valueBuilder: { ctx in ctx.patient.lastname }
    ),
    PlaceholderSpec(
        key: "[[STREET]]",
        valueBuilder: { ctx in ctx.patientAddress?.street ?? "" }
    ),
    PlaceholderSpec(
        key: "[[POSTALCODE]]",
        valueBuilder: { ctx in ctx.patientAddress?.postalCode ?? "" }
    ),
    PlaceholderSpec(
        key: "[[CITY]]",
        valueBuilder: { ctx in ctx.patientAddress?.city ?? "" }
    ),
    PlaceholderSpec(
        key: "[[PLACE_DATE]]",
        valueBuilder: { ctx in "\(ctx.place), \(ctx.dateString)" }
    ),
    PlaceholderSpec(
        key: "[[GOAL_OF_THERAPY]]",
        valueBuilder: { ctx in ctx.therapy.goals }
    ),
    PlaceholderSpec(
        key: "[[RISKS_OF_THERAPY]]",
        valueBuilder: { ctx in
            ctx.therapy.risks.isEmpty
                ? ""
                : "\n\(NSLocalizedString("additionalRisks", comment: "Additional risk information"))\n\(ctx.therapy.risks)"
        }
    ),
    PlaceholderSpec(
        key: "[[INVOICING_TERMS]]",
        valueBuilder: { ctx in ctx.therapy.billingPeriod.localizedDescription }
    )
]
