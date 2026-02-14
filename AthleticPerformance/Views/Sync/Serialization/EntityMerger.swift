import Foundation

/// Merges incoming SyncPullChange records back into the monolithic patient.json structure.
/// Reverse of EntityExtractor — routes each entity type to the correct nested position.
enum EntityMerger {

    /// Applies a pulled change to a Patient, returning the modified patient.
    /// Returns nil if the change cannot be applied (e.g., wrong patient, unknown entity type).
    static func merge(change: SyncPullChange, into patient: inout Patient) -> Bool {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        guard let jsonData = try? JSONSerialization.data(
            withJSONObject: change.data.mapValues(\.value)
        ) else { return false }

        switch change.entityType {
        case .patient:
            return mergePatientDemographics(jsonData: jsonData, decoder: decoder, into: &patient)

        case .session:
            return mergeSession(jsonData: jsonData, decoder: decoder, change: change, into: &patient)

        case .assessment:
            return mergeAssessment(jsonData: jsonData, decoder: decoder, change: change, into: &patient)

        case .invoice:
            return mergeInvoice(jsonData: jsonData, decoder: decoder, change: change, into: &patient)

        case .documentMeta:
            // Media metadata is informational; no merge needed for pull
            return true

        default:
            return false
        }
    }

    // MARK: - Patient Demographics

    private static func mergePatientDemographics(jsonData: Data, decoder: JSONDecoder, into patient: inout Patient) -> Bool {
        // Decode demographics and overwrite non-therapy fields
        guard let updated = try? decoder.decode(Patient.self, from: jsonData) else { return false }

        patient.title = updated.title
        patient.firstnameTerms = updated.firstnameTerms
        patient.firstname = updated.firstname
        patient.lastname = updated.lastname
        patient.birthdate = updated.birthdate
        patient.sex = updated.sex
        patient.addresses = updated.addresses
        patient.phoneNumbers = updated.phoneNumbers
        patient.emailAddresses = updated.emailAddresses
        patient.emergencyContacts = updated.emergencyContacts
        patient.insuranceStatus = updated.insuranceStatus
        patient.insurance = updated.insurance
        patient.insuranceNumber = updated.insuranceNumber
        patient.familyDoctor = updated.familyDoctor
        patient.anamnesis = updated.anamnesis
        patient.isActive = updated.isActive
        patient.dunningLevel = updated.dunningLevel
        patient.paymentBehavior = updated.paymentBehavior
        // Don't overwrite therapies — those come as separate entities

        return true
    }

    // MARK: - Session (Therapy, TreatmentSessions, TherapySessionDocumentation)

    private static func mergeSession(jsonData: Data, decoder: JSONDecoder, change: SyncPullChange, into patient: inout Patient) -> Bool {
        // Try as Therapy first
        if let therapy = try? decoder.decode(Therapy.self, from: jsonData) {
            return mergeTherapy(therapy, into: &patient)
        }
        // Try as TreatmentSessions
        if let session = try? decoder.decode(TreatmentSessions.self, from: jsonData) {
            return mergeTreatmentSession(session, into: &patient)
        }
        // Try as TherapySessionDocumentation
        if let doc = try? decoder.decode(TherapySessionDocumentation.self, from: jsonData) {
            return mergeSessionDoc(doc, into: &patient)
        }
        return false
    }

    private static func mergeTherapy(_ therapy: Therapy, into patient: inout Patient) -> Bool {
        if let idx = patient.therapies.firstIndex(where: { $0?.id == therapy.id }) {
            // Update existing — preserve nested collections from local
            var existing = patient.therapies[idx]!
            existing.therapistId = therapy.therapistId
            existing.title = therapy.title
            existing.goals = therapy.goals
            existing.risks = therapy.risks
            existing.startDate = therapy.startDate
            existing.endDate = therapy.endDate
            existing.tags = therapy.tags
            existing.isAgreed = therapy.isAgreed
            existing.billingPeriod = therapy.billingPeriod
            patient.therapies[idx] = existing
        } else {
            patient.therapies.append(therapy)
        }
        return true
    }

    private static func mergeTreatmentSession(_ session: TreatmentSessions, into patient: inout Patient) -> Bool {
        for tIdx in patient.therapies.indices {
            guard var therapy = patient.therapies[tIdx] else { continue }
            for pIdx in therapy.therapyPlans.indices {
                if let sIdx = therapy.therapyPlans[pIdx].treatmentSessions.firstIndex(where: { $0.id == session.id }) {
                    therapy.therapyPlans[pIdx].treatmentSessions[sIdx] = session
                    patient.therapies[tIdx] = therapy
                    return true
                }
            }
        }
        // New session — append to first plan of first therapy if possible
        if let tIdx = patient.therapies.firstIndex(where: { $0 != nil }),
           var therapy = patient.therapies[tIdx],
           !therapy.therapyPlans.isEmpty {
            therapy.therapyPlans[0].treatmentSessions.append(session)
            patient.therapies[tIdx] = therapy
            return true
        }
        return false
    }

    private static func mergeSessionDoc(_ doc: TherapySessionDocumentation, into patient: inout Patient) -> Bool {
        for tIdx in patient.therapies.indices {
            guard var therapy = patient.therapies[tIdx] else { continue }
            for pIdx in therapy.therapyPlans.indices {
                if let dIdx = therapy.therapyPlans[pIdx].sessionDocs.firstIndex(where: { $0.id == doc.id }) {
                    therapy.therapyPlans[pIdx].sessionDocs[dIdx] = doc
                    patient.therapies[tIdx] = therapy
                    return true
                }
            }
        }
        return false
    }

    // MARK: - Assessment (Diagnosis, Finding, Exercise)

    private static func mergeAssessment(jsonData: Data, decoder: JSONDecoder, change: SyncPullChange, into patient: inout Patient) -> Bool {
        if let diagnosis = try? decoder.decode(Diagnosis.self, from: jsonData) {
            return mergeDiagnosis(diagnosis, into: &patient)
        }
        if let finding = try? decoder.decode(Finding.self, from: jsonData) {
            return mergeFinding(finding, into: &patient)
        }
        if let exercise = try? decoder.decode(Exercise.self, from: jsonData) {
            return mergeExercise(exercise, into: &patient)
        }
        return false
    }

    private static func mergeDiagnosis(_ diagnosis: Diagnosis, into patient: inout Patient) -> Bool {
        for tIdx in patient.therapies.indices {
            guard var therapy = patient.therapies[tIdx] else { continue }
            if let dIdx = therapy.diagnoses.firstIndex(where: { $0.id == diagnosis.id }) {
                therapy.diagnoses[dIdx] = diagnosis
                patient.therapies[tIdx] = therapy
                return true
            }
        }
        return false
    }

    private static func mergeFinding(_ finding: Finding, into patient: inout Patient) -> Bool {
        for tIdx in patient.therapies.indices {
            guard var therapy = patient.therapies[tIdx] else { continue }
            if let fIdx = therapy.findings.firstIndex(where: { $0.id == finding.id }) {
                therapy.findings[fIdx] = finding
                patient.therapies[tIdx] = therapy
                return true
            }
        }
        return false
    }

    private static func mergeExercise(_ exercise: Exercise, into patient: inout Patient) -> Bool {
        for tIdx in patient.therapies.indices {
            guard var therapy = patient.therapies[tIdx] else { continue }
            if let eIdx = therapy.exercises.firstIndex(where: { $0.id == exercise.id }) {
                therapy.exercises[eIdx] = exercise
                patient.therapies[tIdx] = therapy
                return true
            }
        }
        return false
    }

    // MARK: - Invoice

    private static func mergeInvoice(jsonData: Data, decoder: JSONDecoder, change: SyncPullChange, into patient: inout Patient) -> Bool {
        guard let invoice = try? decoder.decode(Invoice.self, from: jsonData) else { return false }
        for tIdx in patient.therapies.indices {
            guard var therapy = patient.therapies[tIdx] else { continue }
            if let iIdx = therapy.invoices.firstIndex(where: { $0.id == invoice.id }) {
                therapy.invoices[iIdx] = invoice
                patient.therapies[tIdx] = therapy
                return true
            }
        }
        return false
    }
}
