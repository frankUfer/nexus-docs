//
//  Therapy.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 27.03.25.
//

import Foundation

/// Represents a therapy process or case, including metadata, content, and billing information.
struct Therapy: Identifiable, Codable, Hashable {
    /// Unique identifier for the therapy.
    var id: UUID // = UUID()

    // MARK: - Meta Information

    /// Optional reference to the therapist's ID (`Therapist.id`).
    var therapistId: UUID?

    /// Reference to the patient's unique ID.
    var patientId: UUID

    /// Title or description of the therapy.
    var title: String

    /// Goals of the therapy
    var goals: String
    
    /// Risks of the therapy
    var risks: String
    
    /// Start date of the therapy.
    var startDate: Date

    /// Optional end date of the therapy. Defaults to 30 days after creation.
    var endDate: Date?

    // MARK: - Content Components

    /// List of diagnoses for this therapy.
    var diagnoses: [Diagnosis]

    /// List of findings or observations.
    var findings: [Finding]

    /// Documentation of any pre-treatment procedures.
    var preTreatment: PreTreatmentDocumentation

    /// List of exercises prescribed as part of the therapy.
    var exercises: [Exercise]

    /// List of therapy plans associated with this therapy.
    var therapyPlans: [TherapyPlan]

    /// Optional discharge report for the therapy.
    var dischargeReport: DischargeReport?

    // MARK: - Billing

    /// List of invoices related to this therapy.
    var invoices: [Invoice]  // => entfernen!!!
    
    /// Periods for billing services
    var billingPeriod: BillingPeriod

    // MARK: - Tags and Status

    /// Tags or status information for filtering and categorization.
    var tags: [String]

    /// Indicates whether the therapy agreement has been confirmed.
    var isAgreed: Bool

    /// Indicates whether the therapy is completed (has an end date and a discharge report).
    var isCompleted: Bool {
        return endDate != nil && dischargeReport != nil
    }
    
    init(
        id: UUID = UUID(),
        therapistId: UUID?,
        patientId: UUID,
        title: String = "",
        goals: String = "",
        risks: String = "",
        startDate: Date = Date(),
        billingPeriod: BillingPeriod = .monthly
        
    ) {
        self.id = id
        self.therapistId = therapistId
        self.patientId = patientId
        self.title = title
        self.goals = goals
        self.risks = risks
        self.startDate = startDate
        self.endDate = startDate.addingTimeInterval(30 * 24 * 60 * 60)
        self.diagnoses = []
        self.findings = []
        self.preTreatment = PreTreatmentDocumentation.empty(therapistId: therapistId ?? UUID())
        self.exercises = []
        self.therapyPlans = []
        self.dischargeReport = nil
        self.invoices = []
        self.billingPeriod = billingPeriod
        self.tags = []
        self.isAgreed = false
    }

    enum CodingKeys: String, CodingKey {
        case id, therapistId, patientId, title, goals, risks, startDate, endDate,
             diagnoses, findings, preTreatment, exercises, therapyPlans,
             dischargeReport, invoices, billingPeriod, tags, isAgreed
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        therapistId = try decodeOptionalTherapistId(from: container, forKey: .therapistId)
        patientId = try container.decode(UUID.self, forKey: .patientId)
        title = try container.decode(String.self, forKey: .title)
        goals = try container.decodeIfPresent(String.self, forKey: .goals) ?? ""
        risks = try container.decodeIfPresent(String.self, forKey: .risks) ?? ""
        startDate = try container.decode(Date.self, forKey: .startDate)
        endDate = try container.decodeIfPresent(Date.self, forKey: .endDate)
        diagnoses = try container.decodeIfPresent([Diagnosis].self, forKey: .diagnoses) ?? []
        findings = try container.decodeIfPresent([Finding].self, forKey: .findings) ?? []
        preTreatment = try container.decode(PreTreatmentDocumentation.self, forKey: .preTreatment)
        exercises = try container.decodeIfPresent([Exercise].self, forKey: .exercises) ?? []
        therapyPlans = try container.decodeIfPresent([TherapyPlan].self, forKey: .therapyPlans) ?? []
        dischargeReport = try container.decodeIfPresent(DischargeReport.self, forKey: .dischargeReport)
        invoices = try container.decodeIfPresent([Invoice].self, forKey: .invoices) ?? []
        billingPeriod = try container.decode(BillingPeriod.self, forKey: .billingPeriod)
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        isAgreed = try container.decodeIfPresent(Bool.self, forKey: .isAgreed) ?? false
    }
}

extension Therapy {
    static func empty(patientId: UUID) -> Therapy {
        Therapy(
            therapistId: nil,
            patientId: patientId,
            title: "",
            goals: "",
            risks: "",
            startDate: Date(),
            billingPeriod: .monthly
        )
    }
}
