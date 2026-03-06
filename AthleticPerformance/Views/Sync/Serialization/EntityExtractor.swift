import Foundation
import CryptoKit

/// Decomposes the monolithic Patient object into flat sync change records.
/// This implements "flatten at sync time" — the app keeps its nested patient.json
/// internally, but produces individual entity records for the sync protocol.
///
/// Each extracted entity carries parent FK references so the server can
/// reconstruct the hierarchy (see DWH_DEFINITION.md §7.1.2 C).
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
                entities.append(extractDiagnosis(diagnosis, patientId: patient.id, therapyId: therapy.id))

                for treatment in diagnosis.treatments {
                    entities.append(extractDiagnosisTreatment(treatment, patientId: patient.id, therapyId: therapy.id, diagnosisId: diagnosis.id))
                }

                for media in diagnosis.mediaFiles {
                    entities.append(extractMediaMeta(media, patientId: patient.id))
                }
            }

            for finding in therapy.findings {
                entities.append(extractFinding(finding, patientId: patient.id, therapyId: therapy.id))

                // Clinical observations from findings
                entities.append(contentsOf: extractClinicalObservations(
                    from: finding, parentType: "finding", parentId: finding.id, patientId: patient.id
                ))

                for media in finding.mediaFiles {
                    entities.append(extractMediaMeta(media, patientId: patient.id))
                }
            }

            // Pre-treatment documentation
            entities.append(extractPreTreatment(therapy.preTreatment, patientId: patient.id, therapyId: therapy.id))

            for exercise in therapy.exercises {
                entities.append(extractExercise(exercise, patientId: patient.id, therapyId: therapy.id))

                for media in exercise.mediaFiles {
                    entities.append(extractMediaMeta(media, patientId: patient.id))
                }
            }

            for plan in therapy.therapyPlans {
                entities.append(extractTherapyPlan(plan, patientId: patient.id, therapyId: therapy.id))

                for session in plan.treatmentSessions {
                    entities.append(extractSession(session, patientId: patient.id, therapyId: therapy.id, therapyPlanId: plan.id))
                }

                for doc in plan.sessionDocs {
                    entities.append(extractSessionDoc(doc, patientId: patient.id, therapyId: therapy.id, therapyPlanId: plan.id))

                    // Applied treatments from session docs
                    for treatment in doc.appliedTreatments {
                        entities.append(extractAppliedTreatment(treatment, patientId: patient.id, sessionDocId: doc.id, sessionId: doc.sessionId))
                    }

                    // Clinical observations from session docs
                    entities.append(contentsOf: extractClinicalObservations(
                        from: doc, parentType: "session_doc", parentId: doc.id, patientId: patient.id
                    ))
                }
            }

            // Discharge report
            if let discharge = therapy.dischargeReport {
                entities.append(extractDischargeReport(discharge, patientId: patient.id, therapyId: therapy.id))

                for media in discharge.attachedMedia {
                    entities.append(extractMediaMeta(media, patientId: patient.id))
                }
            }

            // NOTE: Invoices are stored as separate files (patients/{uuid}/invoices/*.json),
            // NOT inline in patient.json. Use extractInvoicesFromFiles() instead.
            // therapy.invoices is legacy and may be stale/empty.
        }

        return entities
    }

    /// Extracts availability entries as sync entities (not patient-scoped).
    static func extractAvailability(slots: [AvailabilitySlot], therapistId: UUID) -> [ExtractedEntity] {
        slots.map { slot in
            var data = encodeToDictionary(slot)
            data["therapistId"] = AnyCodable(therapistId.uuidString)
            return ExtractedEntity(
                entityType: .availability,
                entityId: slot.id,
                patientId: nil,
                dataCategory: .transactionalData,
                data: data
            )
        }
    }

    /// Extracts practice info, therapists, and services as parameter entities for DWH dimensions.
    /// Uses deterministic UUIDs for practice (since it uses Int id, not UUID).
    static func extractPracticeInfo(_ practice: PracticeInfo) -> [ExtractedEntity] {
        var entities: [ExtractedEntity] = []

        // Practice entity — deterministic UUID from practice id
        let practiceUUID = deterministicUUID(from: "practice/\(practice.id)")
        var practiceData: [String: AnyCodable] = [
            "practiceId": AnyCodable(practice.id),
            "name": AnyCodable(practice.name),
            "phone": AnyCodable(practice.phone),
            "email": AnyCodable(practice.email),
            "website": AnyCodable(practice.website),
            "taxNumber": AnyCodable(practice.taxNumber),
            "bank": AnyCodable(practice.bank),
            "iban": AnyCodable(practice.iban),
            "bic": AnyCodable(practice.bic),
        ]
        let addressData = encodeToDictionary(practice.address)
        practiceData["street"] = addressData["street"]
        practiceData["postalCode"] = addressData["postalCode"]
        practiceData["city"] = addressData["city"]
        practiceData["country"] = addressData["country"]

        entities.append(ExtractedEntity(
            entityType: .practice,
            entityId: practiceUUID,
            patientId: nil,
            dataCategory: .parameter,
            data: practiceData
        ))

        // Therapist entities
        for therapist in practice.therapists {
            let data: [String: AnyCodable] = [
                "firstname": AnyCodable(therapist.firstname),
                "lastname": AnyCodable(therapist.lastname),
                "email": AnyCodable(therapist.email),
                "isActive": AnyCodable(therapist.isActive),
                "practiceId": AnyCodable(practice.id),
            ]
            entities.append(ExtractedEntity(
                entityType: .therapist,
                entityId: therapist.id,
                patientId: nil,
                dataCategory: .parameter,
                data: data
            ))
        }

        // Service entities
        for service in practice.services {
            let data: [String: AnyCodable] = [
                "catalogCode": AnyCodable(service.id),
                "de": AnyCodable(service.de),
                "en": AnyCodable(service.en),
                "billingCode": AnyCodable(service.billingCode as Any),
                "quantity": AnyCodable(service.quantity as Any),
                "unit": AnyCodable(service.unit as Any),
                "price": AnyCodable(service.price as Any),
                "isBillable": AnyCodable(service.isBillable),
                "practiceId": AnyCodable(practice.id),
            ]
            entities.append(ExtractedEntity(
                entityType: .service,
                entityId: service.internalId,
                patientId: nil,
                dataCategory: .parameter,
                data: data
            ))
        }

        return entities
    }

    /// Extracts change log entries from JSON files in a patient's changes/ directory.
    /// Each ChangeEntry becomes a separate sync entity matching the server's fact_change_log schema.
    /// Returns extracted entities plus the list of filenames processed (for marker tracking).
    static func extractChangeLogs(
        from changesDirectory: URL,
        patientId: UUID,
        afterFile: String? = nil
    ) -> (entities: [ExtractedEntity], processedFiles: [String]) {
        let fm = FileManager.default
        guard fm.fileExists(atPath: changesDirectory.path) else { return ([], []) }

        guard let files = try? fm.contentsOfDirectory(atPath: changesDirectory.path)
            .filter({ $0.hasSuffix(".json") })
            .sorted()
        else { return ([], []) }

        // Only process files newer than the marker
        let newFiles: [String]
        if let marker = afterFile {
            newFiles = files.filter { $0 > marker }
        } else {
            newFiles = files
        }

        guard !newFiles.isEmpty else { return ([], []) }

        var entities: [ExtractedEntity] = []
        let decoder = JSONDecoder()

        for filename in newFiles {
            let fileURL = changesDirectory.appendingPathComponent(filename)
            guard let data = try? Data(contentsOf: fileURL) else {
                print("[ChangeLog] Failed to read file: \(fileURL.lastPathComponent)")
                continue
            }
            let log: ChangeLog
            do {
                log = try decoder.decode(ChangeLog.self, from: data)
            } catch {
                print("[ChangeLog] Decode failed for \(filename): \(error)")
                if let raw = String(data: data, encoding: .utf8)?.prefix(300) {
                    print("[ChangeLog] Raw content: \(raw)")
                }
                continue
            }

            // Parse timestamp from filename (yyyyMMdd-HH:mm:ss.json)
            let stem = filename.replacingOccurrences(of: ".json", with: "")
            let changedAtISO: String
            if let parsedDate = fileStampFormatter.date(from: stem) {
                changedAtISO = ISO8601DateFormatter.syncFormatter.string(from: parsedDate)
            } else {
                changedAtISO = ISO8601DateFormatter.syncFormatter.string(from: Date())
            }

            for (index, entry) in log.changes.enumerated() {
                // Deterministic UUID from patientId + filename + index
                let entityId = deterministicUUID(from: "\(patientId.uuidString)/\(filename)/\(index)")

                var entryData: [String: AnyCodable] = [
                    "changedAt": AnyCodable(changedAtISO),
                    "fieldPath": AnyCodable(entry.path),
                    "oldValue": AnyCodable(entry.oldValue),
                    "newValue": AnyCodable(entry.newValue),
                    "patientId": AnyCodable(patientId.uuidString),
                ]
                // Derive entityType from the field path (first path component)
                let pathComponents = entry.path.split(separator: "/").map(String.init)
                if let firstComponent = pathComponents.first {
                    entryData["entityType"] = AnyCodable(firstComponent)
                }
                if let therapistId = entry.therapistId {
                    entryData["therapistId"] = AnyCodable(therapistId.uuidString)
                }

                entities.append(ExtractedEntity(
                    entityType: .changeLog,
                    entityId: entityId,
                    patientId: patientId,
                    dataCategory: .transactionalData,
                    data: entryData
                ))
            }
        }

        return (entities, newFiles)
    }

    /// Extracts invoices and invoice items from the patient's invoices/ directory.
    /// Reads separate JSON files (the source of truth for invoices), NOT therapy.invoices.
    static func extractInvoicesFromFiles(
        invoicesDirectory: URL,
        patientId: UUID
    ) -> [ExtractedEntity] {
        let fm = FileManager.default
        guard fm.fileExists(atPath: invoicesDirectory.path) else { return [] }

        guard let files = try? fm.contentsOfDirectory(atPath: invoicesDirectory.path)
            .filter({ $0.hasSuffix(".json") })
        else { return [] }

        var entities: [ExtractedEntity] = []
        // Invoice files are saved with default JSONEncoder (Apple epoch dates)
        let decoder = JSONDecoder()

        for filename in files {
            let fileURL = invoicesDirectory.appendingPathComponent(filename)
            guard let data = try? Data(contentsOf: fileURL),
                  let invoice = try? decoder.decode(Invoice.self, from: data) else { continue }

            entities.append(extractInvoice(invoice, patientId: patientId))

            for item in invoice.items {
                entities.append(extractInvoiceItem(item, patientId: patientId, invoiceId: invoice.id))
            }
        }

        return entities
    }

    /// Extracts bundled reference data JSON files as parameter entities.
    /// Each reference file maps to its own entity type and warehouse dimension table.
    static func extractReferenceParameters() -> [ExtractedEntity] {
        var entities: [ExtractedEntity] = []

        // Simple reference files: items have { id, de, en }
        let simpleFiles: [(String, SyncEntityType)] = [
            ("assessments", .assessmentRef),
            ("joints", .jointRef),
            ("jointMovementPatterns", .jointMovementPattern),
            ("muscleGroups", .muscleGroup),
            ("tissues", .tissueRef),
            ("tissueStates", .tissueState),
            ("endFeelings", .endFeeling),
            ("painQualities", .painQuality),
            ("painStructures", .painStructure),
        ]

        for (filename, entityType) in simpleFiles {
            guard let items = loadReferenceItems(named: filename) else { continue }
            for item in items {
                guard let idStr = item["id"] as? String, let uuid = UUID(uuidString: idStr) else { continue }
                let data: [String: AnyCodable] = [
                    "de": AnyCodable(item["de"] as? String ?? ""),
                    "en": AnyCodable(item["en"] as? String ?? ""),
                ]
                entities.append(ExtractedEntity(
                    entityType: entityType,
                    entityId: uuid,
                    patientId: nil,
                    dataCategory: .parameter,
                    data: data
                ))
            }
        }

        // Specialties: items have { id, name: { de, en }, source }
        if let items = loadReferenceItems(named: "specialties") {
            for item in items {
                guard let idStr = item["id"] as? String, let uuid = UUID(uuidString: idStr) else { continue }
                let nameDict = item["name"] as? [String: Any]
                let data: [String: AnyCodable] = [
                    "de": AnyCodable(nameDict?["de"] as? String ?? ""),
                    "en": AnyCodable(nameDict?["en"] as? String ?? ""),
                ]
                entities.append(ExtractedEntity(
                    entityType: .specialtyRef,
                    entityId: uuid,
                    patientId: nil,
                    dataCategory: .parameter,
                    data: data
                ))
            }
        }

        // Insurances: items have { id, name (string), source }
        if let items = loadReferenceItems(named: "insurances") {
            for item in items {
                guard let idStr = item["id"] as? String, let uuid = UUID(uuidString: idStr) else { continue }
                let data: [String: AnyCodable] = [
                    "de": AnyCodable(item["name"] as? String ?? ""),
                    "name": AnyCodable(item["name"] as? String ?? ""),
                ]
                entities.append(ExtractedEntity(
                    entityType: .insuranceRef,
                    entityId: uuid,
                    patientId: nil,
                    dataCategory: .parameter,
                    data: data
                ))
            }
        }

        // Diagnose categories: flatten category → term into one row per term
        if let items = loadReferenceItems(named: "diagnoseReferenceData"),
           let first = items.first,
           let categories = first["diagnoseCategories"] as? [[String: Any]] {
            for category in categories {
                let catDe = category["category_de"] as? String ?? ""
                let catEn = category["category_en"] as? String ?? ""
                guard let terms = category["terms"] as? [[String: Any]] else { continue }
                for term in terms {
                    let de = term["de"] as? String ?? ""
                    let en = term["en"] as? String ?? ""
                    let entityId = deterministicUUID(from: "diagnose/\(catDe)/\(de)")
                    entities.append(ExtractedEntity(
                        entityType: .diagnoseCategory,
                        entityId: entityId,
                        patientId: nil,
                        dataCategory: .parameter,
                        data: [
                            "de": AnyCodable(de),
                            "en": AnyCodable(en),
                            "category_de": AnyCodable(catDe),
                            "category_en": AnyCodable(catEn),
                        ]
                    ))
                }
            }
        }

        // Body regions: flatten region → part into one row per part
        // Also includes fascia regions, myofascial chains, neurological areas, functional units
        if let items = loadReferenceItems(named: "physioReferenceData"),
           let first = items.first {

            // Body region parts
            if let regions = first["bodyRegions"] as? [[String: Any]] {
                for region in regions {
                    let regDe = region["region_de"] as? String ?? ""
                    let regEn = region["region_en"] as? String ?? ""
                    guard let parts = region["parts"] as? [[String: Any]] else { continue }
                    for part in parts {
                        let de = part["de"] as? String ?? ""
                        let en = part["en"] as? String ?? ""
                        let entityId = deterministicUUID(from: "bodyRegion/\(regDe)/\(de)")
                        entities.append(ExtractedEntity(
                            entityType: .bodyRegion,
                            entityId: entityId,
                            patientId: nil,
                            dataCategory: .parameter,
                            data: [
                                "de": AnyCodable(de),
                                "en": AnyCodable(en),
                                "region_de": AnyCodable(regDe),
                                "region_en": AnyCodable(regEn),
                                "sub_type": AnyCodable("body_part"),
                            ]
                        ))
                    }
                }
            }

            // Fascia regions
            if let regions = first["fasciaRegions"] as? [[String: Any]] {
                for region in regions {
                    let regDe = region["region_de"] as? String ?? ""
                    let regEn = region["region_en"] as? String ?? ""
                    guard let fasciae = region["fasciae"] as? [[String: Any]] else { continue }
                    for fascia in fasciae {
                        let de = fascia["de"] as? String ?? ""
                        let en = fascia["en"] as? String ?? ""
                        let entityId = deterministicUUID(from: "bodyRegion/fascia/\(regDe)/\(de)")
                        entities.append(ExtractedEntity(
                            entityType: .bodyRegion,
                            entityId: entityId,
                            patientId: nil,
                            dataCategory: .parameter,
                            data: [
                                "de": AnyCodable(de),
                                "en": AnyCodable(en),
                                "region_de": AnyCodable(regDe),
                                "region_en": AnyCodable(regEn),
                                "sub_type": AnyCodable("fascia"),
                            ]
                        ))
                    }
                }
            }

            // Flat lists: myofascial chains, neurological areas, functional units
            let flatSections: [(String, String)] = [
                ("myofascialChains", "myofascial_chain"),
                ("neurologicalAreas", "neurological"),
                ("functionalUnits", "functional_unit"),
            ]
            for (key, subType) in flatSections {
                guard let list = first[key] as? [[String: Any]] else { continue }
                for item in list {
                    let de = item["de"] as? String ?? ""
                    let en = item["en"] as? String ?? ""
                    let entityId = deterministicUUID(from: "bodyRegion/\(subType)/\(de)")
                    entities.append(ExtractedEntity(
                        entityType: .bodyRegion,
                        entityId: entityId,
                        patientId: nil,
                        dataCategory: .parameter,
                        data: [
                            "de": AnyCodable(de),
                            "en": AnyCodable(en),
                            "sub_type": AnyCodable(subType),
                        ]
                    ))
                }
            }
        }

        // Anamnesis template: flatten each condition into its own row with category
        if let url = Bundle.main.url(forResource: "anamnesis", withExtension: "json"),
           let rawData = try? Data(contentsOf: url),
           let json = try? JSONSerialization.jsonObject(with: rawData) as? [String: Any],
           let anamnesis = json["anamnesis"] as? [String: Any],
           let medHistory = anamnesis["medicalHistory"] as? [String: [String]],
           let localization = json["localization"] as? [String: Any] {
            let locEn = localization["en"] as? [String: String] ?? [:]
            let locDe = localization["de"] as? [String: String] ?? [:]
            for (category, conditions) in medHistory {
                for condition in conditions {
                    let entityId = deterministicUUID(from: "anamnesis/\(category)/\(condition)")
                    entities.append(ExtractedEntity(
                        entityType: .anamnesisTemplate,
                        entityId: entityId,
                        patientId: nil,
                        dataCategory: .parameter,
                        data: [
                            "de": AnyCodable(locDe[condition] ?? condition),
                            "en": AnyCodable(locEn[condition] ?? condition),
                            "category": AnyCodable(category),
                        ]
                    ))
                }
            }
        }

        return entities
    }

    /// Loads items array from a bundled JSON file with { version, items: [...] } structure.
    private static func loadReferenceItems(named filename: String) -> [[String: Any]]? {
        guard let url = Bundle.main.url(forResource: filename, withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let items = json["items"] as? [[String: Any]]
        else { return nil }
        return items
    }

    /// Generates a deterministic UUID from a string using SHA-256 (first 16 bytes).
    private static func deterministicUUID(from input: String) -> UUID {
        let digest = SHA256.hash(data: Data(input.utf8))
        var uuidBytes = Array(digest.prefix(16))
        uuidBytes[6] = (uuidBytes[6] & 0x0F) | 0x50 // version 5
        uuidBytes[8] = (uuidBytes[8] & 0x3F) | 0x80 // variant RFC 4122
        return UUID(uuid: (
            uuidBytes[0], uuidBytes[1], uuidBytes[2], uuidBytes[3],
            uuidBytes[4], uuidBytes[5], uuidBytes[6], uuidBytes[7],
            uuidBytes[8], uuidBytes[9], uuidBytes[10], uuidBytes[11],
            uuidBytes[12], uuidBytes[13], uuidBytes[14], uuidBytes[15]
        ))
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
        data.removeValue(forKey: "preTreatment")
        data.removeValue(forKey: "dischargeReport")
        // Ensure parent FK
        data["patientId"] = AnyCodable(patientId.uuidString)
        return ExtractedEntity(
            entityType: .therapy,
            entityId: therapy.id,
            patientId: patientId,
            dataCategory: .transactionalData,
            data: data
        )
    }

    private static func extractDiagnosis(_ diagnosis: Diagnosis, patientId: UUID, therapyId: UUID) -> ExtractedEntity {
        var data = encodeToDictionary(diagnosis)
        data.removeValue(forKey: "mediaFiles")
        // Keep "treatments" — fact_diagnosis has a JSONB treatments column.
        // Individual diagnosis_treatment entities are still extracted for fine-grained sync.
        // Parent FKs
        data["patientId"] = AnyCodable(patientId.uuidString)
        data["therapyId"] = AnyCodable(therapyId.uuidString)
        return ExtractedEntity(
            entityType: .diagnosis,
            entityId: diagnosis.id,
            patientId: patientId,
            dataCategory: .transactionalData,
            data: data
        )
    }

    private static func extractDiagnosisTreatment(_ treatment: DiagnosisTreatments, patientId: UUID, therapyId: UUID, diagnosisId: UUID) -> ExtractedEntity {
        var data = encodeToDictionary(treatment)
        data["patientId"] = AnyCodable(patientId.uuidString)
        data["therapyId"] = AnyCodable(therapyId.uuidString)
        data["diagnosisId"] = AnyCodable(diagnosisId.uuidString)
        return ExtractedEntity(
            entityType: .diagnosisTreatment,
            entityId: treatment.id,
            patientId: patientId,
            dataCategory: .transactionalData,
            data: data
        )
    }

    private static func extractFinding(_ finding: Finding, patientId: UUID, therapyId: UUID) -> ExtractedEntity {
        var data = encodeToDictionary(finding)
        data.removeValue(forKey: "mediaFiles")
        // Remove clinical status arrays — extracted as clinical_observation entities
        data.removeValue(forKey: "assessments")
        data.removeValue(forKey: "joints")
        data.removeValue(forKey: "muscles")
        data.removeValue(forKey: "tissues")
        data.removeValue(forKey: "otherAnomalies")
        data.removeValue(forKey: "symptoms")
        // Parent FKs
        data["patientId"] = AnyCodable(patientId.uuidString)
        data["therapyId"] = AnyCodable(therapyId.uuidString)
        return ExtractedEntity(
            entityType: .finding,
            entityId: finding.id,
            patientId: patientId,
            dataCategory: .transactionalData,
            data: data
        )
    }

    private static func extractExercise(_ exercise: Exercise, patientId: UUID, therapyId: UUID) -> ExtractedEntity {
        var data = encodeToDictionary(exercise)
        data.removeValue(forKey: "mediaFiles")
        data["patientId"] = AnyCodable(patientId.uuidString)
        data["therapyId"] = AnyCodable(therapyId.uuidString)
        return ExtractedEntity(
            entityType: .exercise,
            entityId: exercise.id,
            patientId: patientId,
            dataCategory: .transactionalData,
            data: data
        )
    }

    private static func extractTherapyPlan(_ plan: TherapyPlan, patientId: UUID, therapyId: UUID) -> ExtractedEntity {
        var data = encodeToDictionary(plan)
        data.removeValue(forKey: "treatmentSessions")
        data.removeValue(forKey: "sessionDocs")
        data["patientId"] = AnyCodable(patientId.uuidString)
        data["therapyId"] = AnyCodable(therapyId.uuidString)
        return ExtractedEntity(
            entityType: .therapyPlan,
            entityId: plan.id,
            patientId: patientId,
            dataCategory: .transactionalData,
            data: data
        )
    }

    private static func extractSession(_ session: TreatmentSessions, patientId: UUID, therapyId: UUID, therapyPlanId: UUID) -> ExtractedEntity {
        var data = encodeToDictionary(session)
        data.removeValue(forKey: "serialNumber") // runtime-only, not persisted
        data["patientId"] = AnyCodable(patientId.uuidString)
        data["therapyId"] = AnyCodable(therapyId.uuidString)
        data["therapyPlanId"] = AnyCodable(therapyPlanId.uuidString)
        return ExtractedEntity(
            entityType: .treatmentSession,
            entityId: session.id,
            patientId: patientId,
            dataCategory: .transactionalData,
            data: data
        )
    }

    private static func extractSessionDoc(_ doc: TherapySessionDocumentation, patientId: UUID, therapyId: UUID, therapyPlanId: UUID) -> ExtractedEntity {
        var data = encodeToDictionary(doc)
        // Remove clinical status arrays and applied treatments — extracted separately
        data.removeValue(forKey: "assessments")
        data.removeValue(forKey: "joints")
        data.removeValue(forKey: "muscles")
        data.removeValue(forKey: "tissues")
        data.removeValue(forKey: "otherAnomalies")
        data.removeValue(forKey: "symptoms")
        data.removeValue(forKey: "appliedTreatments")
        data["patientId"] = AnyCodable(patientId.uuidString)
        data["therapyId"] = AnyCodable(therapyId.uuidString)
        data["therapyPlanId"] = AnyCodable(therapyPlanId.uuidString)
        return ExtractedEntity(
            entityType: .sessionDoc,
            entityId: doc.id,
            patientId: patientId,
            dataCategory: .transactionalData,
            data: data
        )
    }

    private static func extractPreTreatment(_ preTreatment: PreTreatmentDocumentation, patientId: UUID, therapyId: UUID) -> ExtractedEntity {
        var data = encodeToDictionary(preTreatment)
        data.removeValue(forKey: "signatureFile")
        data["patientId"] = AnyCodable(patientId.uuidString)
        data["therapyId"] = AnyCodable(therapyId.uuidString)
        return ExtractedEntity(
            entityType: .preTreatment,
            entityId: preTreatment.id,
            patientId: patientId,
            dataCategory: .transactionalData,
            data: data
        )
    }

    private static func extractDischargeReport(_ report: DischargeReport, patientId: UUID, therapyId: UUID) -> ExtractedEntity {
        var data = encodeToDictionary(report)
        data.removeValue(forKey: "attachedMedia")
        data["patientId"] = AnyCodable(patientId.uuidString)
        data["therapyId"] = AnyCodable(therapyId.uuidString)
        return ExtractedEntity(
            entityType: .dischargeReport,
            entityId: report.id,
            patientId: patientId,
            dataCategory: .transactionalData,
            data: data
        )
    }

    private static func extractInvoice(_ invoice: Invoice, patientId: UUID) -> ExtractedEntity {
        var data = encodeToDictionary(invoice)
        // Remove nested items and aggregations — items extracted separately
        data.removeValue(forKey: "items")
        data.removeValue(forKey: "aggregatedItems")
        return ExtractedEntity(
            entityType: .invoice,
            entityId: invoice.id,
            patientId: patientId,
            dataCategory: .transactionalData,
            data: data
        )
    }

    private static func extractInvoiceItem(_ item: InvoiceItem, patientId: UUID, invoiceId: UUID) -> ExtractedEntity {
        var data = encodeToDictionary(item)
        data["patientId"] = AnyCodable(patientId.uuidString)
        data["invoiceId"] = AnyCodable(invoiceId.uuidString)
        return ExtractedEntity(
            entityType: .invoiceItem,
            entityId: item.id,
            patientId: patientId,
            dataCategory: .transactionalData,
            data: data
        )
    }

    private static func extractAppliedTreatment(_ treatment: AppliedTreatment, patientId: UUID, sessionDocId: UUID, sessionId: UUID) -> ExtractedEntity {
        var data = encodeToDictionary(treatment)
        data["patientId"] = AnyCodable(patientId.uuidString)
        data["sessionDocId"] = AnyCodable(sessionDocId.uuidString)
        data["sessionId"] = AnyCodable(sessionId.uuidString)
        return ExtractedEntity(
            entityType: .appliedTreatment,
            entityId: treatment.id,
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

    // MARK: - Clinical Observations

    /// Extracts clinical status entries from a Finding as individual clinical_observation entities.
    private static func extractClinicalObservations(from finding: Finding, parentType: String, parentId: UUID, patientId: UUID) -> [ExtractedEntity] {
        var observations: [ExtractedEntity] = []

        for entry in finding.assessments {
            observations.append(makeClinicalObservation(
                id: entry.id, observationType: "assessment", parentType: parentType, parentId: parentId,
                patientId: patientId, data: encodeToDictionary(entry)
            ))
        }
        for entry in finding.joints {
            observations.append(makeClinicalObservation(
                id: entry.id, observationType: "joint", parentType: parentType, parentId: parentId,
                patientId: patientId, data: encodeToDictionary(entry)
            ))
        }
        for entry in finding.muscles {
            observations.append(makeClinicalObservation(
                id: entry.id, observationType: "muscle", parentType: parentType, parentId: parentId,
                patientId: patientId, data: encodeToDictionary(entry)
            ))
        }
        for entry in finding.tissues {
            observations.append(makeClinicalObservation(
                id: entry.id, observationType: "tissue", parentType: parentType, parentId: parentId,
                patientId: patientId, data: encodeToDictionary(entry)
            ))
        }
        for entry in finding.otherAnomalies {
            observations.append(makeClinicalObservation(
                id: entry.id, observationType: "anomaly", parentType: parentType, parentId: parentId,
                patientId: patientId, data: encodeToDictionary(entry)
            ))
        }
        for entry in finding.symptoms {
            observations.append(makeClinicalObservation(
                id: entry.id, observationType: "symptom", parentType: parentType, parentId: parentId,
                patientId: patientId, data: encodeToDictionary(entry)
            ))
        }

        return observations
    }

    /// Extracts clinical status entries from a TherapySessionDocumentation.
    private static func extractClinicalObservations(from doc: TherapySessionDocumentation, parentType: String, parentId: UUID, patientId: UUID) -> [ExtractedEntity] {
        var observations: [ExtractedEntity] = []

        for entry in doc.assessments {
            observations.append(makeClinicalObservation(
                id: entry.id, observationType: "assessment", parentType: parentType, parentId: parentId,
                patientId: patientId, data: encodeToDictionary(entry)
            ))
        }
        for entry in doc.joints {
            observations.append(makeClinicalObservation(
                id: entry.id, observationType: "joint", parentType: parentType, parentId: parentId,
                patientId: patientId, data: encodeToDictionary(entry)
            ))
        }
        for entry in doc.muscles {
            observations.append(makeClinicalObservation(
                id: entry.id, observationType: "muscle", parentType: parentType, parentId: parentId,
                patientId: patientId, data: encodeToDictionary(entry)
            ))
        }
        for entry in doc.tissues {
            observations.append(makeClinicalObservation(
                id: entry.id, observationType: "tissue", parentType: parentType, parentId: parentId,
                patientId: patientId, data: encodeToDictionary(entry)
            ))
        }
        for entry in doc.otherAnomalies {
            observations.append(makeClinicalObservation(
                id: entry.id, observationType: "anomaly", parentType: parentType, parentId: parentId,
                patientId: patientId, data: encodeToDictionary(entry)
            ))
        }
        for entry in doc.symptoms {
            observations.append(makeClinicalObservation(
                id: entry.id, observationType: "symptom", parentType: parentType, parentId: parentId,
                patientId: patientId, data: encodeToDictionary(entry)
            ))
        }

        return observations
    }

    private static func makeClinicalObservation(
        id: UUID, observationType: String, parentType: String, parentId: UUID,
        patientId: UUID, data: [String: AnyCodable]
    ) -> ExtractedEntity {
        var enriched = data
        enriched["observationType"] = AnyCodable(observationType)
        enriched["parentType"] = AnyCodable(parentType)
        enriched["parentId"] = AnyCodable(parentId.uuidString)
        enriched["patientId"] = AnyCodable(patientId.uuidString)
        return ExtractedEntity(
            entityType: .clinicalObservation,
            entityId: id,
            patientId: patientId,
            dataCategory: .transactionalData,
            data: enriched
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
