import Foundation

/// Decomposes the monolithic Patient object into flat sync change records.
/// This implements "flatten at sync time" — the app keeps its nested patient.json
/// internally, but produces individual entity records for the sync protocol.
enum EntityExtractor {

    struct ExtractedEntity {
        let entityType: SyncEntityType
        let entityId: UUID
        let patientId: UUID?
        let dataCategory: SyncDataCategory
        let data: [String: AnyCodable]
    }

    /// Extracts all sync entities from a Patient.
    static func extractAll(from patient: Patient) -> [ExtractedEntity] {
        var entities: [ExtractedEntity] = []

        // Patient demographics (master_data)
        entities.append(extractPatientDemographics(patient))

        // Therapies and their nested entities
        for therapy in patient.therapies.compactMap({ $0 }) {
            entities.append(extractTherapy(therapy, patientId: patient.id))

            for diagnosis in therapy.diagnoses {
                entities.append(extractDiagnosis(diagnosis, patientId: patient.id))
            }

            for finding in therapy.findings {
                entities.append(extractFinding(finding, patientId: patient.id))
            }

            for exercise in therapy.exercises {
                entities.append(extractExercise(exercise, patientId: patient.id))
            }

            for plan in therapy.therapyPlans {
                for session in plan.treatmentSessions {
                    entities.append(extractSession(session, patientId: patient.id))
                }
                for doc in plan.sessionDocs {
                    entities.append(extractSessionDoc(doc, patientId: patient.id))
                }
            }

            for invoice in therapy.invoices {
                entities.append(extractInvoice(invoice, patientId: patient.id))
            }

            // Media file metadata from diagnoses
            for diagnosis in therapy.diagnoses {
                for media in diagnosis.mediaFiles {
                    entities.append(extractMediaMeta(media, patientId: patient.id))
                }
            }
        }

        return entities
    }

    // MARK: - Individual Extractors

    private static func extractPatientDemographics(_ patient: Patient) -> ExtractedEntity {
        let data = encodeToDictionary(patient)
        // Remove nested therapies — those are separate entities
        var demographics = data
        demographics.removeValue(forKey: "therapies")
        return ExtractedEntity(
            entityType: .patient,
            entityId: patient.id,
            patientId: patient.id,
            dataCategory: .masterData,
            data: demographics
        )
    }

    private static func extractTherapy(_ therapy: Therapy, patientId: UUID) -> ExtractedEntity {
        var data = encodeToDictionary(therapy)
        // Remove nested collections — they become separate entities
        data.removeValue(forKey: "diagnoses")
        data.removeValue(forKey: "findings")
        data.removeValue(forKey: "exercises")
        data.removeValue(forKey: "therapyPlans")
        data.removeValue(forKey: "invoices")
        return ExtractedEntity(
            entityType: .session,
            entityId: therapy.id,
            patientId: patientId,
            dataCategory: .transactionalData,
            data: data
        )
    }

    private static func extractDiagnosis(_ diagnosis: Diagnosis, patientId: UUID) -> ExtractedEntity {
        var data = encodeToDictionary(diagnosis)
        data.removeValue(forKey: "mediaFiles")
        return ExtractedEntity(
            entityType: .assessment,
            entityId: diagnosis.id,
            patientId: patientId,
            dataCategory: .transactionalData,
            data: data
        )
    }

    private static func extractFinding(_ finding: Finding, patientId: UUID) -> ExtractedEntity {
        var data = encodeToDictionary(finding)
        data.removeValue(forKey: "mediaFiles")
        return ExtractedEntity(
            entityType: .assessment,
            entityId: finding.id,
            patientId: patientId,
            dataCategory: .transactionalData,
            data: data
        )
    }

    private static func extractExercise(_ exercise: Exercise, patientId: UUID) -> ExtractedEntity {
        var data = encodeToDictionary(exercise)
        data.removeValue(forKey: "mediaFiles")
        return ExtractedEntity(
            entityType: .assessment,
            entityId: exercise.id,
            patientId: patientId,
            dataCategory: .transactionalData,
            data: data
        )
    }

    private static func extractSession(_ session: TreatmentSessions, patientId: UUID) -> ExtractedEntity {
        let data = encodeToDictionary(session)
        return ExtractedEntity(
            entityType: .session,
            entityId: session.id,
            patientId: patientId,
            dataCategory: .transactionalData,
            data: data
        )
    }

    private static func extractSessionDoc(_ doc: TherapySessionDocumentation, patientId: UUID) -> ExtractedEntity {
        let data = encodeToDictionary(doc)
        return ExtractedEntity(
            entityType: .session,
            entityId: doc.id,
            patientId: patientId,
            dataCategory: .transactionalData,
            data: data
        )
    }

    private static func extractInvoice(_ invoice: Invoice, patientId: UUID) -> ExtractedEntity {
        let data = encodeToDictionary(invoice)
        return ExtractedEntity(
            entityType: .invoice,
            entityId: invoice.id,
            patientId: patientId,
            dataCategory: .transactionalData,
            data: data
        )
    }

    private static func extractMediaMeta(_ media: MediaFile, patientId: UUID) -> ExtractedEntity {
        let data = encodeToDictionary(media)
        return ExtractedEntity(
            entityType: .documentMeta,
            entityId: media.id,
            patientId: patientId,
            dataCategory: .transactionalData,
            data: data
        )
    }

    // MARK: - Helper

    private static func encodeToDictionary<T: Encodable>(_ value: T) -> [String: AnyCodable] {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(value),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return [:] }
        return dict.mapValues { AnyCodable($0) }
    }
}
