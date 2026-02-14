//
//  PatientStore.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 18.03.25.
//

import Foundation
import SwiftUI

@MainActor
final class PatientStore: ObservableObject {
    static let shared = PatientStore()
    @Published private(set) var patients: [Patient] = []

    /// Callback invoked after a patient is saved. Parameters: (new, old).
    /// The SyncCoordinator wires this to detect changes and enqueue to the outbound queue.
    var onPatientChanged: ((Patient, Patient?) -> Void)?

    private let baseURL: URL
    private let fileStampFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyyMMdd-HHmmss"
        df.locale = .init(identifier: "en_US_POSIX")
        return df
    }()

    init() {
        baseURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("patients", isDirectory: true)
        try? FileManager.default.createDirectory(at: baseURL, withIntermediateDirectories: true)

        Task { await loadAllPatients() }
    }

    // MARK: - In-Memory (MainActor)
    
    func getPatient(by id: UUID) -> Patient? {
        patients.first { $0.id == id }
    }
    
    @MainActor
    func applyPatient(_ newPatient: Patient) {
        if let idx = patients.firstIndex(where: { $0.id == newPatient.id }) {
            var copy = patients
            copy[idx] = newPatient
            patients = copy
        } else {
            patients = patients + [newPatient]
        }
    }
    
    @MainActor
    func removePatientFromMemory(_ id: UUID) {
        patients = patients.filter { $0.id != id }  
    }

    // MARK: Update patient
    
    func updatePatientAsync(_ updated: Patient) async {
        // 0) Persistierten Altstand holen (robuster als In-Memory)
        let oldDisk = self.loadPatientSync(with: updated.id)

        // 1) changedDate setzen, wenn sich Inhalt geändert hat
        var newValue = updated
        if let oldDisk, !patientsEqualIgnoringChangedDate(oldDisk, newValue) {
            newValue.changedDate = Date()
        }

        // 2) Diff VOR Publish – aber gegen oldDisk
        let changes: [FieldChange]
        if let oldDisk {
            changes = diffPatient(old: oldDisk, new: newValue, therapistId: AppGlobals.shared.therapistId)
        } else {
            // Neu angelegt – optionaler „Alles neu“-Eintrag, sonst []
            changes = [
                FieldChange(path: "/", oldValue: .null, newValue: .object([:]), therapistId: AppGlobals.shared.therapistId)
            ]
        }

        // 3) Publish
        applyPatient(newValue)

        // 4) Change-Log + Persist
        await handleDetectedChangesAsync(changes, for: newValue.id)
        await savePatientAsync(newValue)

        // 5) Notify sync system
        onPatientChanged?(newValue, oldDisk)
    }

    func updatePatient(_ updated: Patient, waitUntilSaved: Bool = false) {
        let oldDisk = self.loadPatientSync(with: updated.id)

        var newValue = updated
        if let oldDisk, !patientsEqualIgnoringChangedDate(oldDisk, newValue) {
            newValue.changedDate = Date()
        }

        let changes: [FieldChange]
        if let oldDisk {
            changes = diffPatient(old: oldDisk, new: newValue, therapistId: AppGlobals.shared.therapistId)
        } else {
            changes = [
                FieldChange(path: "/", oldValue: .null, newValue: .object([:]), therapistId: AppGlobals.shared.therapistId)
            ]
        }

        applyPatient(newValue)

        let baseURL = self.baseURL
        let snapshot = newValue
        
        if waitUntilSaved {
//            if !changes.isEmpty {
//                print("💾 [updatePatient] Änderungen erkannt für Patient \(snapshot.fullName):")
//                for ch in changes {
//                    print("   ▪️ \(ch.path)")
//                    print("     alt: \(String(describing: ch.oldValue))")
//                    print("     neu: \(String(describing: ch.newValue))")
//                }
//                print("   → \(changes.count) Änderungen werden synchron gespeichert…")
//            } else {
//                print("💾 [updatePatient] Keine Änderungen für \(snapshot.fullName)")
//            }

            writeChangeLogSync(changes, patientId: snapshot.id, baseURL: baseURL)
            savePatientSync(snapshot, baseURL: baseURL)
            //print("✅ [updatePatient] Patient synchron gespeichert: \(snapshot.fullName) (\(snapshot.id))")

            // Notify sync system
            onPatientChanged?(newValue, oldDisk)

        } else {
            Task.detached(priority: .utility) { [baseURL, snapshot, changes] in
//                if !changes.isEmpty {
//                    print("💾 [updatePatient async] Änderungen erkannt für Patient \(snapshot.fullName):")
//                    for ch in changes {
//                        print("   ▪️ \(ch.path)")
//                        print("     alt: \(String(describing: ch.oldValue))")
//                        print("     neu: \(String(describing: ch.newValue))")
//                    }
//                    print("   → \(changes.count) Änderungen werden asynchron gespeichert…")
//                } else {
//                    print("💾 [updatePatient async] Keine Änderungen für \(snapshot.fullName)")
//                }

                await self.writeChangeLogSync(changes, patientId: snapshot.id, baseURL: baseURL)
                await self.savePatientAsync(snapshot)
                //print("✅ [updatePatient async] Patient asynchron gespeichert: \(snapshot.fullName) (\(snapshot.id))")

                // Notify sync system
                await MainActor.run { self.onPatientChanged?(snapshot, oldDisk) }
            }
        }
    }

    
    // MARK: - Add patient
    func addPatient(_ patient: Patient) async {
        applyPatient(patient)
        await savePatientAsync(patient)
        onPatientChanged?(patient, nil)
    }

    // MARK: - Delete patient
    func deletePatient(_ patient: Patient) async {
        removePatientFromMemory(patient.id)
        await deletePatientFile(patient.id)
    }
    
    @MainActor
    func togglePatientStatus(for id: UUID) {
        guard let idx = patients.firstIndex(where: { $0.id == id }) else { return }
        let old = patients[idx]
        var copy = patients
        copy[idx].isActive.toggle()
        let updated = copy[idx]
        patients = copy                      // <- Reassign
        Task { await savePatientAsync(updated) }
        onPatientChanged?(updated, old)
    }
      
    @MainActor
    func bindingForPatient(id: UUID) -> Binding<Patient>? {
        guard let initial = patients.first(where: { $0.id == id }) else { return nil }
        var cache = initial

        return Binding(
            get: {
                if let current = self.patients.first(where: { $0.id == id }) {
                    cache = current
                }
                return cache
            },
            set: { newValue in
                // Nur UI/In-Memory aktualisieren – KEINE Persistenz, KEIN Change-Log
                self.applyPatient(newValue)
            }
        )
    }
    

    // MARK: - Load patient(s)
    func loadAllPatients() async {
        let baseURL = self.baseURL
        let loaded: [Patient] = await Task.detached(priority: .utility) { () -> [Patient] in
            do {
                let fm = FileManager.default
                let folders = try fm.contentsOfDirectory(at: baseURL, includingPropertiesForKeys: nil)
                var result: [Patient] = []

                for folder in folders {
                    let fileURL = folder.appendingPathComponent("patient.json")
                    guard fm.fileExists(atPath: fileURL.path) else { continue }
                    let data = try Data(contentsOf: fileURL)
                    let file = try JSONDecoder().decode(PatientFile.self, from: data)
                    var patient = file.patient

                    // Medienpfade und patientId in Sessions bereinigen
                    if !patient.therapies.isEmpty {
                        for tIdx in patient.therapies.indices {
                            if var therapy = patient.therapies[tIdx] {
                                // Medien validieren
                                for dIdx in therapy.diagnoses.indices {
                                    therapy.diagnoses[dIdx].mediaFiles = therapy.diagnoses[dIdx].mediaFiles.filter {
                                        let p = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                                            .appendingPathComponent($0.relativePath)
                                        return FileManager.default.fileExists(atPath: p.path)
                                    }
                                }
                                // patientId in Sessions
                                for pIdx in therapy.therapyPlans.indices {
                                    var plan = therapy.therapyPlans[pIdx]
                                    for sIdx in plan.treatmentSessions.indices {
                                        if plan.treatmentSessions[sIdx].patientId == nil {
                                            plan.treatmentSessions[sIdx].patientId = patient.id
                                        }
                                    }
                                    therapy.therapyPlans[pIdx] = plan
                                }
                                patient.therapies[tIdx] = therapy
                            }
                        }
                    }

                    result.append(patient)
                }

                return result.sorted { $0.lastname.localizedCaseInsensitiveCompare($1.lastname) == .orderedAscending }
            } catch {
                //print("⚠️ loadAllPatients() Fehler: \(error)")
                return []
            }
        }.value

        self.patients = loaded
    }
    
    private func loadPatientSync(with id: UUID) -> Patient? {
        let fileURL = baseURL.appendingPathComponent(id.uuidString).appendingPathComponent("patient.json")
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        do {
            let data = try Data(contentsOf: fileURL)
            let file = try JSONDecoder().decode(PatientFile.self, from: data)
            return file.patient
        } catch {
            //print("⚠️ loadPatientSync Fehler \(id): \(error)")
            return nil
        }
    }

    // MARK: Save patient

    func savePatientAsync(_ patient: Patient) async {
        let baseURL = self.baseURL
        await Task.detached(priority: .utility) {
            await self.savePatientSync(patient, baseURL: baseURL)
        }.value
    }

    private func savePatientSync(_ patient: Patient, baseURL: URL) {
        do {
            let fm = FileManager.default
            let folder = baseURL.appendingPathComponent(patient.id.uuidString, isDirectory: true)
            if !fm.fileExists(atPath: folder.path) {
                try fm.createDirectory(at: folder, withIntermediateDirectories: true)
            }
            let fileURL = folder.appendingPathComponent("patient.json")
            let file = PatientFile(version: 1, patient: patient)
            let enc = JSONEncoder()
            let data = try enc.encode(file)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            //print("❌ Speichern fehlgeschlagen für \(patient.fullName): \(error)")
        }
    }

    func deletePatientFile(_ patientId: UUID) async {
        let baseURL = self.baseURL
        await Task.detached(priority: .utility) {
            let fm = FileManager.default
            let folder = baseURL.appendingPathComponent(patientId.uuidString, isDirectory: true)
            do { if fm.fileExists(atPath: folder.path) { try fm.removeItem(at: folder) } }
            catch {
                //print("⚠️ Löschen fehlgeschlagen \(patientId): \(error)")
            }
        }.value
    }

    // MARK: Log changes

    private func handleDetectedChangesAsync(_ changes: [FieldChange], for patientId: UUID) async {
        guard !changes.isEmpty else { return }
        let baseURL = self.baseURL
        await Task.detached(priority: .utility) {
            await self.writeChangeLogSync(changes, patientId: patientId, baseURL: baseURL)
        }.value
    }

    private func writeChangeLogSync(_ changes: [FieldChange], patientId: UUID, baseURL: URL) {
        guard !changes.isEmpty else { return }

        let now = Date()
        let stamp = fileStampFormatter.string(from: now)
        let folder = baseURL.appendingPathComponent(patientId.uuidString, isDirectory: true)
            .appendingPathComponent("changes", isDirectory: true)
        let fm = FileManager.default

        do {
            if !fm.fileExists(atPath: folder.path) {
                try fm.createDirectory(at: folder, withIntermediateDirectories: true)
            }
            let fileURL = folder.appendingPathComponent(stamp).appendingPathExtension("json")

            let log = ChangeLog(
                changes: changes.map { ch in
                    .init(
                        path: ch.path,
                        oldValue: String(describing: ch.oldValue),
                        newValue: String(describing: ch.newValue),
                        therapistId: ch.therapistId
                    )
                }
            )

            let enc = JSONEncoder()
            enc.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            let data = try enc.encode(log)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            //print("❌ ChangeLog schreiben fehlgeschlagen: \(error)")
        }
    }
}

// MARK: - Diff-Helper
extension PatientStore {
    func patientsEqualIgnoringChangedDate(_ a: Patient, _ b: Patient) -> Bool {
        let enc = JSONEncoder(); enc.dateEncodingStrategy = .iso8601
        guard
            let da = try? enc.encode(a),
            let db = try? enc.encode(b),
            let oa = try? JSONSerialization.jsonObject(with: da) as? [String: Any],
            let ob = try? JSONSerialization.jsonObject(with: db) as? [String: Any]
        else { return false }

        var ra = oa; ra.removeValue(forKey: "changedDate")
        var rb = ob; rb.removeValue(forKey: "changedDate")
        return jsonContainersEqual(ra, rb)
    }

    func diffPatient(old: Patient, new: Patient, therapistId: UUID?) -> [FieldChange] {
        let enc = JSONEncoder(); enc.dateEncodingStrategy = .iso8601
        guard
            let dOld = try? enc.encode(old),
            let dNew = try? enc.encode(new),
            let oOld = try? JSONSerialization.jsonObject(with: dOld) as? [String: Any],
            let oNew = try? JSONSerialization.jsonObject(with: dNew) as? [String: Any]
        else { return [] }

        var a = oOld; a.removeValue(forKey: "changedDate")
        var b = oNew; b.removeValue(forKey: "changedDate")

        var out: [FieldChange] = []
        diffRecursive(old: a, new: b, basePath: "", out: &out, therapistId: therapistId)
        return out
    }

    private func diffRecursive(
        old: Any?,
        new: Any?,
        basePath: String,
        out: inout [FieldChange],
        therapistId: UUID?
    ) {
        if let o = old, let n = new, jsonContainersEqual(o, n) { return }

        if (old == nil) || (new == nil) || (type(of: old as Any) != type(of: new as Any)) {
            out.append(FieldChange(
                path: basePath.isEmpty ? "/" : basePath,
                oldValue: old.map(anyToJSONValue) ?? .null,
                newValue: new.map(anyToJSONValue) ?? .null,
                therapistId: therapistId
            ))
            return
        }

        if let od = old as? [String: Any], let nd = new as? [String: Any] {
            let keys = Set(od.keys).union(nd.keys)
            for k in keys {
                let child = basePath + "/" + escapePointerToken(k)
                diffRecursive(old: od[k], new: nd[k], basePath: child, out: &out, therapistId: therapistId)
            }
            return
        }

        if let oa = old as? [Any], let na = new as? [Any] {
            let maxCount = max(oa.count, na.count)
            for i in 0..<maxCount {
                let o = i < oa.count ? oa[i] : nil
                let n = i < na.count ? na[i] : nil
                let child = basePath + "/" + String(i)
                diffRecursive(old: o, new: n, basePath: child, out: &out, therapistId: therapistId)
            }
            return
        }

        out.append(FieldChange(
            path: basePath.isEmpty ? "/" : basePath,
            oldValue: anyToJSONValue(old as Any),
            newValue: anyToJSONValue(new as Any),
            therapistId: therapistId
        ))
    }

    private func jsonContainersEqual(_ a: Any, _ b: Any) -> Bool {
        switch (a, b) {
        case let (da as [String: Any], db as [String: Any]):
            if da.count != db.count { return false }
            for (k, va) in da {
                guard let vb = db[k], jsonContainersEqual(va, vb) else { return false }
            }
            return true
        case let (aa as [Any], ab as [Any]):
            guard aa.count == ab.count else { return false }
            for i in 0..<aa.count where !jsonContainersEqual(aa[i], ab[i]) { return false }
            return true
        case let (na as NSNumber, nb as NSNumber):
            return na == nb
        case let (sa as String, sb as String):
            return sa == sb
        case (_ as NSNull, _ as NSNull):
            return true
        default:
            return (a as AnyObject).isEqual(b)
        }
    }

    private func anyToJSONValue(_ any: Any) -> JSONValue {
        switch any {
        case is NSNull:                return .null
        case let b as Bool:            return .bool(b)
        case let n as NSNumber:        return .number(n.doubleValue)
        case let s as String:          return .string(s)
        case let arr as [Any]:         return .array(arr.map(anyToJSONValue))
        case let dict as [String: Any]:
            var out: [String: JSONValue] = [:]
            for (k, v) in dict { out[k] = anyToJSONValue(v) }
            return .object(out)
        default:
            return .string(String(describing: any))
        }
    }

    private func escapePointerToken(_ raw: String) -> String {
        raw.replacingOccurrences(of: "~", with: "~0")
           .replacingOccurrences(of: "/", with: "~1")
    }
}

@MainActor
extension PatientStore {
    /// Zentrale Dateiprüfung (Store kennt seinen `baseURL`)
    func hasContractPDF(_ patientId: UUID) -> Bool {
        let url = baseURL
            .appendingPathComponent(patientId.uuidString, isDirectory: true)
            .appendingPathComponent("contract.pdf")
        return FileManager.default.fileExists(atPath: url.path)
    }

    func canDeletePatient(_ patient: Patient) -> Bool {
        PatientDeletionPolicy.canDelete(patient, hasContractPDF: hasContractPDF(_:))
    }

    func deletionBlockers(for patient: Patient) -> Set<PatientDeletionBlocker> {
        PatientDeletionPolicy.blockers(for: patient, hasContractPDF: hasContractPDF(_:))
    }
}

@MainActor
extension PatientStore {
    enum MediaSaveError: Error {
        case patientNotFound
        case therapyNotFound
        case diagnosisNotFound
        case writeFailed(Error)
    }

    /// Speichert eine Mediendatei unter patients/<pid>/media/<therapyId>/<filename>
    /// und hängt sie an die gegebene Diagnose an. Persistiert den Patient via `updatePatientAsync`.
    @discardableResult
    func addMediaFile(
        patientId: UUID,
        therapyId: UUID,
        diagnosisId: UUID,
        data: Data,
        originalFilename: String,
        fileType: FileType
    ) async throws -> MediaFile {
        // 1) Patient besorgen
        guard var patient = getPatient(by: patientId) ?? loadPatientSync(with: patientId)
        else { throw MediaSaveError.patientNotFound }

        // 2) Zielordner + Dateiname
        //    -> zentral: .../patients/<pid>/media/<therapyId>/<filename>
        let patientFolder = baseURL.appendingPathComponent(patientId.uuidString, isDirectory: true)
        let mediaFolder   = patientFolder.appendingPathComponent("media", isDirectory: true)
            .appendingPathComponent(therapyId.uuidString, isDirectory: true)

        let ext = (originalFilename as NSString).pathExtension.isEmpty
            ? fileType.preferredExtension // optional helper, s.u.
            : (originalFilename as NSString).pathExtension

        let safeBase = ((originalFilename as NSString).deletingPathExtension)
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")

        // eindeutiger name
        let filename = "\(safeBase.isEmpty ? UUID().uuidString : safeBase)-\(UUID().uuidString).\(ext)"
        let fileURL  = mediaFolder.appendingPathComponent(filename)
        let relative = "patients/\(patientId.uuidString)/media/\(therapyId.uuidString)/\(filename)"

        // 3) Datei schreiben (HDD/Background-Thread)
        do {
            try FileManager.default.createDirectory(at: mediaFolder, withIntermediateDirectories: true)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            throw MediaSaveError.writeFailed(error)
        }

        // 4) MediaFile an Diagnose hängen (in-memory)
        let newMedia = MediaFile(
            id: UUID(),
            filename: filename,
            date: Date(),
            relativePath: relative,
            linkedDiagnosisId: diagnosisId
        )

        guard let tIdx = patient.therapies.firstIndex(where: { $0?.id == therapyId }),
              var therapy = patient.therapies[tIdx]
        else { throw MediaSaveError.therapyNotFound }

        guard let dIdx = therapy.diagnoses.firstIndex(where: { $0.id == diagnosisId })
        else { throw MediaSaveError.diagnosisNotFound }

        therapy.diagnoses[dIdx].mediaFiles.append(newMedia)
        patient.therapies[tIdx] = therapy

        // 5) Persistieren (inkl. Change-Log + changedDate setzen)
        await updatePatientAsync(patient)

        return newMedia
    }
}
