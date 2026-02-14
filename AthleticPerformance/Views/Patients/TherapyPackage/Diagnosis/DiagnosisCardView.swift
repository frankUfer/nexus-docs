//
//  DiagnosisCardView.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 23.04.25.
//

import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct DiagnosisCardView: View {
    @Binding var diagnosis: Diagnosis
    @State private var selectedMedia: MediaFile? = nil
    @State private var showPhotoPicker = false
    @State private var showPDFPicker = false
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var showCSVPicker = false
    @State private var csvURL: URL? = nil
    @State private var showDeleteConfirmation = false
    @State private var treatmentToDelete: DiagnosisTreatments?
    @State private var showRemedyDeleteConfirmation = false
    var onChange: (() -> Void)? = nil
    
    let patientId: UUID
    let therapyId: UUID
    let therapyPlans: [TherapyPlan]
    
    @Binding var patient: Patient
    @EnvironmentObject var patientStore: PatientStore
    @Environment(\.locale) var locale

    let columns = [GridItem(.adaptive(minimum: 100), spacing: 12)]
    
    private var isTherapyPlanCompleted: Bool {
        patient.therapies
            .compactMap { $0 }
            .first(where: { $0.id == therapyId })?
            .therapyPlans
            .first(where: { $0.diagnosisId == diagnosis.id })?
            .isCompleted ?? false
    }

    var body: some View {

        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center) {
                TextField(NSLocalizedString("diagnosisTitle", comment: "Diagnosis title"), text: $diagnosis.title)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: diagnosis.title) {onChange?() }

                if !therapyPlans.contains(where: { $0.diagnosisId == diagnosis.id }) {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Image(systemName: "trash")
                            .foregroundColor(.deleteButton)
                            .padding(.leading, 8)
                    }
                }
            }
            
            // Notizen
            TextEditor(text: Binding(
                get: { diagnosis.notes ?? "" },
                set: { diagnosis.notes = $0 }
            ))
            .frame(height: 100)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.3)))
            .onChange(of: diagnosis.notes ?? "") { onChange?() }

            // Quelle der Diagnose
            DiagnosisSourceView(source: $diagnosis.source)

            // Behandlungen
            treatmentsSection

            // Medien
            mediaSection
        }
        .padding()
        .onChange(of: selectedItem) { _, newItem in
            guard let item = newItem else { return }

            Task {
                guard let data = try? await item.loadTransferable(type: Data.self) else { return }
                let ext = item.supportedContentTypes.first?.preferredFilenameExtension ?? "bin"
                let filename = "import.\(ext)" // Basisname egal, Store hängt UUID an

                do {
                    _ = try await patientStore.addMediaFile(
                        patientId: patientId,
                        therapyId: therapyId,
                        diagnosisId: diagnosis.id,
                        data: data,
                        originalFilename: filename,
                        fileType: FileType.from(filename: filename)
                    )

                    // Optional: lokalen Binding-Patient auf den frisch publizierten Stand setzen
                    if let refreshed = patientStore.getPatient(by: patientId) {
                        patient = refreshed
                    }

                    onChange?() // nur für UI-Flags (dirty), keine Persistenz hier
                } catch {
                    showErrorAlert(errorMessage: error.localizedDescription)
                }
            }
        }
        .confirmationDialog(NSLocalizedString("reallyDeleteDiagnosis", comment: "Really want to delete diagnosis"),
                            isPresented: $showDeleteConfirmation,
                            titleVisibility: .visible) {
            Button(NSLocalizedString("delete", comment: "Delete"), role: .destructive) {
                deleteDiagnosis()
            }
            Button(NSLocalizedString("cancel", comment: "Cancel"), role: .cancel) { }
        }
    }

    private var treatmentsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(NSLocalizedString("remedy", comment: "Remedy"))
                    .font(.headline)
                
                Spacer()
                
                Button {
                    diagnosis.treatments.append(DiagnosisTreatments())
                    onChange?()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.addButton)
                }
            }

            
            let services = AppGlobals.shared.treatmentServices

            ForEach($diagnosis.treatments, id: \.id) { $treatment in
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                                                
                        if !isTherapyPlanCompleted {
                            TextField(NSLocalizedString("remedyDescription", comment: "Remedy description"), text: $treatment.description)
                                .textFieldStyle(.roundedBorder)
                                .onChange(of: treatment.description) { onChange?() }
                            
                            Spacer()
                            
                            Picker(NSLocalizedString("treatmentService", comment: "Treatment Service"), selection: $treatment.treatmentService) {
                                Text("–").tag(UUID?.none)
                                
                                ForEach(services) { service in
                                    let name = locale.identifier.starts(with: "de") ? service.de : service.en
                                    let label = "\(name) (\(service.quantity ?? 0) \(service.unit ?? ""))"
                                    Text(label).tag(service.internalId as UUID?)
                                }
                            }
                            .pickerStyle(.menu)
                            .tint(Color.secondary)
                            .onChange(of: treatment.treatmentService) { onChange?() }
                            
                            Spacer()
                            
                            Slider(value: $treatment.number.doubleBinding, in: 1...20, step: 1)
                                .frame(width: 100)
                                .onChange(of: treatment.number) { onChange?() }
                            
                            Text("\(treatment.number)")
                                .frame(width: 30)
                            
                            if diagnosis.treatments.count > 1 {
                                Button {
                                    treatmentToDelete = treatment
                                    showRemedyDeleteConfirmation = true
                                } label: {
                                    Image(systemName: "trash")
                                        .foregroundColor(.deleteButton)
                                }
                            }
                        } else {
                            // Read-only Textanzeige
                            if let service = services.first(where: { $0.internalId == treatment.treatmentService }) {
                                let name = locale.identifier.starts(with: "de") ? service.de : service.en
                                let servicePart = "\(name) (\(service.quantity ?? 0) \(service.unit ?? ""))"
                                
                                let numberPart = "x \(treatment.number) \(NSLocalizedString("sessions", comment: "Treatment sessions"))"
                                
                                let label = "\(servicePart) \(numberPart)"
                                
                                Text(label)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            .alert(isPresented: $showRemedyDeleteConfirmation) {
                Alert(
                    title: Text(NSLocalizedString("confirmDelete", comment: "Confirm delete")),
                    message: Text(NSLocalizedString("reallyDeleteRemedy", comment: "Really delete remedy")),
                    primaryButton: .destructive(Text(NSLocalizedString("delete", comment: "Delete"))) {
                        if let target = treatmentToDelete,
                           let index = diagnosis.treatments.firstIndex(where: { $0.id == target.id }) {
                            diagnosis.treatments.remove(at: index)
                            onChange?()
                        }
                        treatmentToDelete = nil
                    },
                    secondaryButton: .cancel {
                        treatmentToDelete = nil
                    }
                )
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.frameBackground)))
    }

    private var mediaSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(NSLocalizedString("media", comment: "Media"))
                    .font(.headline)

                Spacer()

                Menu {
                    // 📷 Foto auswählen
                    Button {
                        showPhotoPicker = true
                    } label: {
                        Label(NSLocalizedString("selectImage", comment: "Select image"), systemImage: "photo.on.rectangle")
                    }

                    // 📸 Foto machen
                    Button {
                        launchDocumentScanner()
                    } label: {
                        Label(NSLocalizedString("takePicture", comment: "Take picture"), systemImage: "camera")
                    }

                    // 📄 PDF laden
                    Button {
                        showPDFPicker = true
                    } label: {
                        Label(NSLocalizedString("loadPDF", comment: "Load PDF"), systemImage: "doc.richtext")
                    }
                    // 🧾 CSV Datei laden
                    Button {
                        showCSVPicker = true
                    } label: {
                        Label(NSLocalizedString("loadCSV", comment: "Load CSV"), systemImage: "tablecells")
                    }

                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.addButton)
                }
                PhotoPickerView(isPresented: $showPhotoPicker) { item in
                    self.selectedItem = item
                }
                .background(RoundedRectangle(cornerRadius: 12).fill(Color(.frameBackground)))
                .sheet(isPresented: $showPDFPicker) {
                            DocumentPicker(allowedContentTypes: [.pdf]) { url in
                                handlePickedPDF(url)
                            }
                        }
                .sheet(isPresented: $showCSVPicker) {
                    DocumentPickerView(allowedContentTypes: [.commaSeparatedText]) { selectedURL in
                        if let url = selectedURL {
                            handleImportedCSV(from: url)
                        }
                    }
                }
            }
           
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(diagnosis.mediaFiles, id: \.id) { media in
                    MediaPreviewThumbnail(
                        media: media,
                        mediaFiles: $diagnosis.mediaFiles,
                        diagnosis: $diagnosis,
                        selectedPatient: patient,
                        therapyId: therapyId,
                        onChange: {onChange?() }
                    )
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.frameBackground)))
    }
    
    func launchDocumentScanner() {
        guard let topVC = UIApplication.shared.topMostViewController() else {
            showErrorAlert(errorMessage: NSLocalizedString("errorViewController", comment: "No view controller available to present the scanner."))
            return
        }

        ScannerLauncher.presentScanner(from: topVC) { result in
            Task { @MainActor in
                switch result {
                case .success(.image(let image)):
                    guard let data = image.jpegData(compressionQuality: 0.85) else { return }
                    do {
                        // Basisname (der Store hängt ohnehin eine UUID an)
                        let originalFilename = "scan.jpg"
                        // Falls du selbst eine UUID vorgeben willst:
                        // let originalFilename = "\(UUID().uuidString).jpg"

                        _ = try await patientStore.addMediaFile(
                            patientId: patientId,
                            therapyId: therapyId,
                            diagnosisId: diagnosis.id,
                            data: data,
                            originalFilename: originalFilename,
                            fileType: .image
                        )

                        // Binding zum aktuellen Stand auffrischen
                        if let refreshed = patientStore.getPatient(by: patientId) {
                            patient = refreshed
                        }
                        onChange?()

                    } catch {
                        let msg = String(
                            format: NSLocalizedString("errorSavingFile", comment: "Error saving file: %@"),
                            error.localizedDescription
                        )
                        showErrorAlert(errorMessage: msg)
                    }

                case .success(.pdf(let data)):
                    do {
                        let originalFilename = "scan.pdf"
                        // Oder mit eigener UUID:
                        // let originalFilename = "\(UUID().uuidString).pdf"

                        _ = try await patientStore.addMediaFile(
                            patientId: patientId,
                            therapyId: therapyId,
                            diagnosisId: diagnosis.id,
                            data: data,
                            originalFilename: originalFilename,
                            fileType: .pdf
                        )

                        if let refreshed = patientStore.getPatient(by: patientId) {
                            patient = refreshed
                        }
                        onChange?()

                    } catch {
                        let msg = String(
                            format: NSLocalizedString("errorSavingFile", comment: "Error saving file: %@"),
                            error.localizedDescription
                        )
                        showErrorAlert(errorMessage: msg)
                    }

                case .failure(let error):
                    let message = String(
                        format: NSLocalizedString("errorScanning", comment: "Error scanning document: %@"),
                        error.localizedDescription
                    )
                    showErrorAlert(errorMessage: message)
                }
            }
        }
    }
    
    private func handlePickedPDF(_ url: URL) {
        Task { @MainActor in
            // ⚠️ Bei Dokumenten aus dem Files-Picker: Zugriff anfordern
            guard url.startAccessingSecurityScopedResource() else {
                showErrorAlert(errorMessage: NSLocalizedString("errorNoAccessToFile", comment: "No access to file."))
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }

            do {
                // Datei laden (sync; hier ok, wir sind bereits in einem Task)
                let data = try Data(contentsOf: url)

                // Basisname an den Store übergeben; der Store erzeugt einen eindeutigen Dateinamen
                let originalName = url.lastPathComponent.isEmpty ? "import.pdf" : url.lastPathComponent

                // ⭐️ Datei speichern + Patient persistieren + Change-Log im Store
                _ = try await patientStore.addMediaFile(
                    patientId: patientId,
                    therapyId: therapyId,
                    diagnosisId: diagnosis.id,
                    data: data,
                    originalFilename: originalName,
                    fileType: .pdf
                )

                // Lokalen Binding-Patient auf den frisch publizierten Stand heben (optional, aber oft hilfreich fürs UI)
                if let refreshed = patientStore.getPatient(by: patientId) {
                    patient = refreshed
                }

                // UI-Flag/Refresh für die aufrufende View
                onChange?()

            } catch {
                let message = String(
                    format: NSLocalizedString("errorImportingPDFFile", comment: "Error importing PDF file: %@"),
                    error.localizedDescription
                )
                showErrorAlert(errorMessage: message)
            }
        }
    }
    
    private func handleImportedCSV(from url: URL) {
        guard url.startAccessingSecurityScopedResource() else {
            showErrorAlert(errorMessage: NSLocalizedString("errorNoAccessToFile", comment: "No access to file."))
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }

        do {
            // CSV in Memory laden
            let data = try Data(contentsOf: url)

            // Eindeutiger Basisname (der Store kann zusätzlich eine UUID anhängen — wir geben hier explizit eine UUID vor)
            let originalFilename = "\(UUID().uuidString).csv"
            // Alternative, falls du den Namen stabil halten willst und die Eindeutigkeit nur im Store erzeugt wird:
            // let originalFilename = "import.csv"

            Task { @MainActor in
                do {
                    _ = try await patientStore.addMediaFile(
                        patientId: patientId,
                        therapyId: therapyId,
                        diagnosisId: diagnosis.id,
                        data: data,
                        originalFilename: originalFilename,
                        fileType: .csv
                    )

                    // Binding mit dem gespeicherten Stand aktualisieren
                    if let refreshed = patientStore.getPatient(by: patientId) {
                        patient = refreshed
                    }
                    onChange?()

                } catch {
                    let message = String(
                        format: NSLocalizedString("errorSavingFile", comment: "Error saving file: %@"),
                        error.localizedDescription
                    )
                    showErrorAlert(errorMessage: message)
                }
            }
        } catch {
            let message = String(
                format: NSLocalizedString("errorImportingCSVFile", comment: "Error importing CSV file: %@"),
                error.localizedDescription
            )
            showErrorAlert(errorMessage: message)
        }
    }
    
    private func deleteDiagnosis() {
        // 1. Finde Index der Therapie
        guard let therapyIndex = patient.therapies.firstIndex(where: { $0?.id == therapyId }),
              var therapy = patient.therapies[therapyIndex] else {
            showErrorAlert(errorMessage: NSLocalizedString("errorTherapyNotFound", comment: "Therapy not found."))
            return
        }

        // 2. Lösche verknüpfte Mediendateien aus Dateisystem
        for media in diagnosis.mediaFiles {
            let filePath = FileManager.default
                .urls(for: .documentDirectory, in: .userDomainMask).first!
                .appendingPathComponent(media.relativePath)
            try? FileManager.default.removeItem(at: filePath)
        }

        // 3. Entferne Diagnose aus der Therapie
        therapy.diagnoses.removeAll(where: { $0.id == diagnosis.id })

        // 4. Setze aktualisierte Therapie zurück in Patient
        patient.therapies[therapyIndex] = therapy

        // 5. Speicher Patient
        patientStore.updatePatient(patient)

        // 6. Trigger UI-Update
        onChange?()
    }
}

extension Binding where Value == Int {
    var doubleBinding: Binding<Double> {
        Binding<Double>(
            get: { Double(self.wrappedValue) },
            set: { self.wrappedValue = Int($0) }
        )
    }
}

extension UIApplication {
    func topMostViewController(base: UIViewController? = nil) -> UIViewController? {
        let base = base ?? connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }
            .first?.rootViewController

        if let nav = base as? UINavigationController {
            return topMostViewController(base: nav.visibleViewController)
        }
        if let tab = base as? UITabBarController {
            return topMostViewController(base: tab.selectedViewController)
        }
        if let presented = base?.presentedViewController {
            return topMostViewController(base: presented)
        }

        return base
    }
}
