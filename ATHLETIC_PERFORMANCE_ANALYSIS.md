# AthleticPerformance — Complete Analysis for Nexus Integration

> Generated: 2026-02-14
> Status: ANALYSIS COMPLETE — awaiting decisions before implementation

---

## 1. App Architecture

**Pattern: Store-based MVVM (partial) with SwiftUI**

The app uses a hybrid architecture — not a strict MVVM, but a store-driven pattern
common in SwiftUI apps:

| Layer                | Implementation                                                                      |
| -------------------- | ----------------------------------------------------------------------------------- |
| **Entry Point**      | `AthleticsPerformanceApp.swift` — SwiftUI `@main` App                               |
| **Navigation**       | `AppNavigationContainer` — three-pane `NavigationSplitView` (sidebar, list, detail) |
| **State Management** | Three `ObservableObject` stores injected as `@StateObject` / `@EnvironmentObject`   |
| **Persistence**      | File-based JSON — no Core Data, no SQLite                                           |
| **UI**               | Pure SwiftUI (iPadOS 17+)                                                           |

### Stores (act as ViewModels)

| Store                    | Scope                            | Key State                                                         |
| ------------------------ | -------------------------------- | ----------------------------------------------------------------- |
| `PatientStore`           | `@MainActor`, `ObservableObject` | `@Published patients: [Patient]` — all patients in memory         |
| `AppNavigationStore`     | `ObservableObject`               | `@Published selectedMainMenu`, `selectedPatientID`                |
| `AppGlobals` (singleton) | `ObservableObject`               | `@Published practiceInfo`, `publicAddresses` + all reference data |
| `HolidayStore`           | `ObservableObject`               | `@Published holidays` — German public holidays                    |
| `AvailabilityStore`      | `ObservableObject`               | `@Published slots` — therapist availability                       |

### Main Menu Structure

	MainMenu enum:
	  .appointments  → MultiPatientCalendarView (Day/Week/Month)
	  .patients      → PatientListView → PatientDetailContainerView
	  .billing       → BillingMainView / ClaimsMainView
	  .sync          → BackupView / RestoreView
	  .settings      → PracticeInfo / Insurances / Specialties / Availability

### App Startup Sequence

1. Check for `Documents.zip` in bundle (productive data import)
2. `setupAppDirectories()` — create `patients/`, `resources/templates/`, `resources/parameter/`
3. Copy parameter JSON files from bundle → Documents (if newer)
4. `loadAppData()` — loads all parameters into `AppGlobals.shared`
5. `patientStore.loadAllPatients()` — reads all patient JSON files from disk
6. `CalendarIndexBackfiller.runAtAppStart()` — backfills missing session serial numbers
7. Request camera permission

---

## 2. Data Models — Complete Inventory with Nexus Mapping

### Master Data (Nexus: `master_data`, iPad wins)

| Model                  | ID Type  | Nexus Entity Type | Notes                                                                                                      |
| ---------------------- | -------- | ----------------- | ---------------------------------------------------------------------------------------------------------- |
| **`Patient`**          | `UUID`   | `patient`         | Core entity. Contains demographics, contacts, insurance, anamnesis. Wrapped in `PatientFile` with version. |
| **`EmergencyContact`** | embedded | `contact`         | Nested in `Patient.emergencyContacts` as `LabeledValue<EmergencyContact>`                                  |
| **`Address`**          | embedded | part of `patient` | Multiple labeled addresses per patient (private, work, other)                                              |
| **`Anamnesis`**        | embedded | part of `patient` | Medical history + lifestyle. Nested inside Patient.                                                        |

**Patient properties:** `id: UUID`, `title: PatientTitle`, `firstname`, `lastname`,
`birthdate: Date`, `sex: Gender`, `addresses: [LabeledValue<Address>]`,
`phoneNumbers: [LabeledValue<String>]`, `emailAddresses: [LabeledValue<String>]`,
`emergencyContacts: [LabeledValue<EmergencyContact>]`, `insuranceStatus: InsuranceStatus`,
`insurance: String?`, `insuranceNumber: String?`, `familyDoctor: String?`,
`anamnesis: Anamnesis?`, `therapies: [Therapy?]`, `isActive: Bool`, `dunningLevel: Int`,
`paymentBehavior: PaymentBehavior`, `createdDate: Date`, `changedDate: Date`

### Transactional Data (Nexus: `transactional_data`, iPad wins)

| Model                             | ID Type   | Nexus Entity Type         | Notes                                                                           |
| --------------------------------- | --------- | ------------------------- | ------------------------------------------------------------------------------- |
| **`Therapy`**                     | `UUID`    | `session` (container)     | Therapy case: groups diagnoses, findings, plans, sessions, invoices             |
| **`TherapyPlan`**                 | `UUID`    | `session` (sub-container) | Groups sessions under a diagnosis with scheduling rules                         |
| **`TreatmentSessions`**           | `UUID`    | `session`                 | Individual appointment: date, times, address, status flags, therapist, services |
| **`TherapySessionDocumentation`** | `UUID`    | `session` (nested)        | Clinical notes + applied treatments for a session                               |
| **`Diagnosis`**                   | `UUID`    | `assessment`              | Medical diagnosis with source, treatments, media                                |
| **`Finding`**                     | `UUID`    | `assessment`              | Clinical examination: joints, muscles, tissues, symptoms                        |
| **`Exercise`**                    | `UUID`    | `assessment` (sub)        | Prescribed exercises with reps, sets, media                                     |
| **`PreTreatmentDocumentation`**   | `UUID`    | `session` (nested)        | Pre-treatment consent, goals, risks discussed                                   |
| **`DischargeReport`**             | `UUID`    | `session` (nested)        | Therapy completion report                                                       |
| **`Invoice`**                     | `UUID`    | **unmapped**              | Billing document — needs decision (see [D3][1])                                 |
| **`MediaFile`**                   | `UUID`    | `document_meta`           | Attached images, videos, PDFs, CSVs                                             |
| **`ChangeLog`** / `FieldChange`   | timestamp | unmapped (sync audit)     | Change tracking — feeds into sync payload                                       |

**Assessment sub-models (all `UUID`, Codable, nested in Finding/SessionDoc):**

| Model                      | Purpose                                                               |
| -------------------------- | --------------------------------------------------------------------- |
| `AssessmentStatusEntry`    | Standardized assessment results (Berg Balance, Timed Up and Go, etc.) |
| `JointStatusEntry`         | Joint ROM measurements with movement patterns, pain, end-feel         |
| `MuscleStatusEntry`        | Muscle tone (-3 to +3), manual muscle testing, pain                   |
| `TissueStatusEntry`        | Tissue state, pain quality/level                                      |
| `SymptomsStatusEntry`      | Symptom tracking by body region, pain, onset date                     |
| `OtherAnomalieStatusEntry` | Free-text anomaly documentation with pain                             |
| `AppliedTreatment`         | Service applied during a session (serviceId + amount)                 |

### Parameters (Nexus: `parameter`, Server wins)

| Model                       | ID Type           | Nexus Entity Type    | Source File                                |
| --------------------------- | ----------------- | -------------------- | ------------------------------------------ |
| **`PracticeInfo`**          | `Int`             | `system_config`      | `practiceInfo.json`                        |
| **`Therapists`**            | `Int`             | `system_config`      | nested in PracticeInfo                     |
| **`TreatmentService`**      | `String` / `UUID` | `treatment_type`     | nested in PracticeInfo (has billing codes) |
| **`InsuranceCompany`**      | `String`          | `reference_data`     | `insurances.json`                          |
| **`Specialty`**             | `String`          | `reference_data`     | `specialties.json`                         |
| **`Assessments`**           | `UUID`            | `reference_data`     | `assessments.json`                         |
| **`Joints`**                | `UUID`            | `reference_data`     | `joints.json`                              |
| **`JointMovementPattern`**  | `UUID`            | `reference_data`     | `jointMovementPatterns.json`               |
| **`MuscleGroups`**          | `UUID`            | `reference_data`     | `muscleGroups.json`                        |
| **`EndFeelings`**           | `UUID`            | `reference_data`     | `endFeelings.json`                         |
| **`PainQualities`**         | `UUID`            | `reference_data`     | `painQualities.json`                       |
| **`PainStructures`**        | `UUID`            | `reference_data`     | `painStructures.json`                      |
| **`Tissues`**               | `UUID`            | `reference_data`     | `tissues.json`                             |
| **`TissueStates`**          | `UUID`            | `reference_data`     | `tissueStates.json`                        |
| **`PhysioReferenceData`**   | composite         | `reference_data`     | `physioReferenceData.json`                 |
| **`DiagnoseReferenceData`** | composite         | `icd_code` (partial) | `diagnoseReferenceData.json`               |
| **`PublicAddress`**         | `UUID`            | `reference_data`     | `publicAddresses.json`                     |

### Unmapped / Needs Decision

| Model                                    | Issue                                                         | Decision Ref                  |
| ---------------------------------------- | ------------------------------------------------------------- | ----------------------------- |
| `Invoice`                                | No Nexus entity type defined                                  | [D3][2]                       |
| `BillingEntry` / `BillingPeriod`         | Runtime billing aggregation — not persisted separately        | [D3][3]                       |
| `TreatmentContract`                      | Not Codable. Generated PDFs only.                             | N/A (PDF syncs as attachment) |
| `AvailabilitySlot` / `AvailabilityEntry` | Therapist scheduling — currently per-device                   | [D4][4]                       |
| `CalendarEntry`                          | Calendar display model                                        | Maps to Nexus `event`         |
| `Therapist` (with availability/plans)    | `therapist.json` stores single therapist ID — device-specific | [D5][5]                       |
| `IcsEventData`                           | Ephemeral ICS generation model                                | Not synced                    |

---

## 3. Data Category Mapping Summary

### master\_data (iPad wins)
- `Patient` — demographics, contacts, insurance, anamnesis
- `EmergencyContact` — emergency contact persons

### transactional\_data (iPad wins)
- `Therapy` — therapy case container
- `TherapyPlan` — session grouping under diagnosis
- `TreatmentSessions` — individual appointments
- `TherapySessionDocumentation` — session clinical notes
- `Diagnosis` — medical diagnoses
- `Finding` — clinical examination results
- `Exercise` — prescribed exercises
- `PreTreatmentDocumentation` — consent/pre-treatment
- `DischargeReport` — therapy completion
- `Invoice` — billing documents (pending [D3][6])
- `MediaFile` — attachments (images, PDFs, videos)
- All assessment sub-entries (joint, muscle, tissue, symptom, anomaly)

### parameter (Server wins)
- `PracticeInfo` + `Therapists` + `TreatmentService`
- `InsuranceCompany`, `Specialty`
- All anatomical reference data (joints, muscles, tissues, pain qualities, etc.)
- `DiagnoseReferenceData`, `PhysioReferenceData`
- `PublicAddress`

---

## 4. Persistence — Current State vs. Nexus Target

### Current Storage Layout

	Documents/
	├── patients/
	│   └── {patient_uuid}/
	│       ├── patient.json              ← PatientFile { version, patient }
	│       ├── changes/
	│       │   └── yyyyMMdd-HHmmss.json  ← ChangeLog { changes: [ChangeEntry] }
	│       └── media/
	│           └── {therapy_uuid}/
	│               └── {filename}.{ext}  ← images, PDFs, videos
	├── resources/
	│   └── parameter/
	│       ├── practiceInfo.json
	│       ├── insurances.json
	│       ├── specialties.json
	│       └── ... (17 parameter files)
	├── availability_{therapistId}.json
	└── backup_*.zip                       ← manual backups

### Nexus Target Layout (from SYNC\_PROTOCOL.md)

	/NexusField/
	├── patients/
	│   └── {patient_uuid}/
	│       ├── patient.json              ← master data
	│       ├── sessions/
	│       │   └── 2026-02-14_001.json   ← session/transaction records
	│       ├── documents/
	│       │   └── *.pdf
	│       ├── images/
	│       │   └── *.jpg
	│       └── sync_meta.json            ← sync state per patient
	├── parameters/
	│   ├── treatment_types.json
	│   ├── icd_codes.json
	│   └── system_config.json
	└── sync/
	    ├── outbound_queue.json
	    ├── last_sync_state.json
	    └── conflict_log.json

### What Needs to Change

| Aspect                 | Current                                                                | Target                                                                | Effort     |
| ---------------------- | ---------------------------------------------------------------------- | --------------------------------------------------------------------- | ---------- |
| **Patient JSON**       | Entire patient + all therapies in one `patient.json`                   | Split: master data in `patient.json`, sessions in separate files      | **HIGH**   |
| **Session storage**    | Nested inside `Patient.therapies[].therapyPlans[].treatmentSessions[]` | Individual session JSON files in `sessions/` subdirectory             | **HIGH**   |
| **Media organization** | `media/{therapyId}/{filename}`                                         | `documents/*.pdf` + `images/*.jpg` separated by type                  | **MEDIUM** |
| **Sync metadata**      | `changes/` directory with change logs                                  | `sync_meta.json` per patient + global `sync/` directory               | **MEDIUM** |
| **Parameters**         | `resources/parameter/` (17 files, app-specific names)                  | `parameters/` (3 files: treatment\_types, icd\_codes, system\_config) | **MEDIUM** |
| **Outbound queue**     | None                                                                   | `sync/outbound_queue.json`                                            | **NEW**    |
| **Conflict log**       | None                                                                   | `sync/conflict_log.json`                                              | **NEW**    |

### Critical Architectural Concern: Monolithic patient.json

The current app stores **everything about a patient** (demographics, all therapies,
all sessions, all diagnoses, all findings, all exercises, all invoices) in a single
`patient.json` file. This is the biggest structural gap — see [D1][7].

---

## 5. Networking — Current State

**The `Networking/` directory is empty.** There is zero networking code in the app.

The only network-adjacent features are:
- **MultipeerConnectivity** (`RemoteCameraSession`) — external camera pairing, not data sync
- **MapKit** (`TravelTimeService`, `GeocodingService`) — travel time and geocoding
- **MessageUI** — sending emails/SMS to patients

### Comparison to Nexus Sync Protocol

| Sync Protocol Requirement                        | App Status                              |
| ------------------------------------------------ | --------------------------------------- |
| `POST /sync/push` — send changes                 | Not implemented                         |
| `GET /sync/pull` — receive changes               | Not implemented                         |
| `POST /sync/upload` — binary attachments         | Not implemented                         |
| `GET /sync/download/{token}` — fetch attachments | Not implemented                         |
| `GET /sync/status` — health check                | Not implemented                         |
| Device identity (device\_id, JWT)                | Not implemented                         |
| Outbound queue for offline changes               | Not implemented (but change logs exist) |
| Three-tier conflict resolution                   | Not implemented                         |
| Version tracking (last\_pull\_version)           | Not implemented                         |
| Background sync scheduling                       | Not implemented                         |

**Positive:** The existing change tracking (`diffPatient`, `ChangeLog`, `FieldChange`)
is structurally close to what the sync push payload needs. `FieldChange` has `path`,
`oldValue`, `newValue`, `therapistId` — these map to sync change records.

---

## 6. Dependencies

| Framework/Package                 | Usage                               | Nexus Impact                         |
| --------------------------------- | ----------------------------------- | ------------------------------------ |
| **SwiftUI**                       | Entire UI layer                     | None                                 |
| **Foundation**                    | JSON, FileManager, Date, URLSession | URLSession available for sync        |
| **Combine**                       | `@Published` properties             | None                                 |
| **PDFKit**                        | PDF viewing and text extraction     | Attachments for sync                 |
| **Vision**                        | OCR text recognition                | None                                 |
| **VisionKit**                     | Document camera scanning            | None                                 |
| **CoreText**                      | PDF text rendering                  | None                                 |
| **EventKit / EventKitUI**         | iOS Calendar integration            | Calendar events need sync mapping    |
| **MessageUI**                     | Email/SMS composition               | None                                 |
| **LocalAuthentication**           | FaceID/TouchID                      | Could secure sync operations         |
| **MapKit**                        | Travel time, geocoding              | None                                 |
| **MultipeerConnectivity**         | External camera peer-to-peer        | None                                 |
| **ZIPFoundation**                 | Backup ZIP creation/extraction      | Keep for local backup alongside sync |
| **MediaInputKit** (local package) | Camera, scanner, drawing, gallery   | iOS 17+, no external deps            |

**No external networking libraries.** URLSession from Foundation is sufficient for the
Nexus REST API.

---

## 7. Calendar / Events / Scheduling

The app has a sophisticated scheduling system:

### Data Flow
	TherapyPlan (frequency, weekdays, timeOfDay, numberOfSessions)
	    → SessionPlanning (GenerateTreatmentProposals)
	        → SlotFinder (finds available time slots)
	            → TravelTimeManager (calculates travel between locations)
	                → AvailabilityStore (therapist schedules)
	                    → HolidayStore (German public holidays)
	    → TreatmentSessions (concrete appointments)
	        → IcsGenerator (ICS calendar files)
	            → LocalCalendarManager (iOS Calendar sync)

### Key Components

| Component                                        | Purpose                                                                                     |
| ------------------------------------------------ | ------------------------------------------------------------------------------------------- |
| `TreatmentSessions`                              | Session model with status lifecycle: `draft → planned → scheduled → done → invoiced → paid` |
| `TherapyPlan`                                    | Groups sessions, auto-renumbers with serial numbers (x/y)                                   |
| `SessionPlanning` / `GenerateTreatmentProposals` | Auto-generates session proposals based on frequency, weekday preferences, time-of-day       |
| `SlotFinder`                                     | Finds clustered slots near existing same-week sessions                                      |
| `TravelTimeManager`                              | Apple Maps-based travel time between treatment locations                                    |
| `AvailabilityStore`                              | Therapist availability (available, vacation, training, blocked)                             |
| `HolidayStore`                                   | German public holidays via Gauss Easter algorithm                                           |
| `IcsGenerator`                                   | Generates ICS 2.0 calendar files with VALARM, ATTENDEE, SEQUENCE                            |
| `LocalCalendarManager`                           | Writes events to iOS Calendar via EventKit                                                  |

### Nexus Mapping
- `TreatmentSessions` → Nexus `event` entity type (bidirectional sync)
- `AvailabilityEntry` → needs decision (see [D4][8])
- ICS generation stays local (patient communication feature, not sync data)

---

## 8. Gaps and Concerns

### Well-Built

- **Data model richness** — Comprehensive clinical models covering the full therapy
  workflow (patient → diagnosis → finding → plan → session → documentation → invoice → discharge)
- **Change tracking** — `diffPatient()` with recursive JSON comparison and field-level
  change logs is an excellent sync foundation
- **File-based persistence** — Already aligned with Nexus philosophy (no Core Data/SQLite)
- **Codable everywhere** — Every model conforms to `Codable` with careful custom decoders
  for backward compatibility
- **UUID identifiers** — Most entities use `UUID`, matching Nexus `entity_id`
- **Bilingual support** — German/English localization with `de`/`en` properties on reference data
- **Media handling** — Robust document scanning, OCR, photo/video capture, PDF generation
- **PatientDeletionBlocker** — Safety guards prevent accidental data loss (aligns with
  Nexus deletion-rejection philosophy)

### Fragile / Concerning

- **Monolithic patient.json** — The entire patient graph (demographics + all therapies +
  all sessions + all diagnoses + all invoices) lives in one JSON file. For active patients
  with many sessions, this file grows unbounded. A single corrupt write loses everything
  for that patient. See [D1][9].
- **In-memory full load** — `loadAllPatients()` reads every patient into memory at startup.
  With hundreds of patients, this will cause startup latency and memory pressure.
- **Therapist ID as `Int`** — `Therapists.id` and `Therapist.id` use `Int`, not `UUID`.
  This will collide across iPads and doesn't match the UUID-based Nexus model. See [D5][10].
- **No atomic transactions** — Updates read from disk, diff in memory, write back. No file
  locking or transaction safety if the app crashes mid-write.
- **`PatientStore.bindingForPatient()`** — Creates a SwiftUI binding that updates memory
  only (no persistence). If the app terminates mid-edit, changes are lost.
- **Entitlements mismatch** — References `iCloud.com.ufer-solutions.KontoauszugsReader`
  (a different app). Copy-paste artifact.
- **Empty Networking/ directory** — No sync infrastructure exists. This is the largest gap.
- **No data validation on load** — If `patient.json` is malformed, the patient silently
  fails to load with no recovery mechanism.
- **Invoice model marked for removal** — `Therapy.invoices` has a comment suggesting
  invoices will move elsewhere, but no migration path exists.

### Missing Features

| Feature                            | Status      | Priority for Nexus               |
| ---------------------------------- | ----------- | -------------------------------- |
| Sync API client (NexusSync module) | Not started | **Critical**                     |
| JWT authentication                 | Not started | **Critical**                     |
| Outbound change queue              | Not started | **High**                         |
| Three-tier conflict resolution     | Not started | **High**                         |
| Sync metadata (version tracking)   | Not started | **High**                         |
| Background sync scheduling         | Not started | **High**                         |
| Device registration flow           | Not started | **High**                         |
| Network reachability monitoring    | Not started | **Medium**                       |
| Session-level storage (decomposed) | Not started | **Medium** (depends on [D1][11]) |
| Attachment upload/download         | Not started | **Medium**                       |
| Sync status UI                     | Not started | **Medium**                       |
| WireGuard VPN awareness            | Not started | **Low** (OS-level)               |

---

## 9. Proposed Integration Plan

### Phase 1: Foundation (HIGH complexity)

**1.1 — Define sync entity serialization layer**
- Create a `NexusSyncPayload` module that serializes nested app models into flat sync
  change records matching the `POST /sync/push` schema
- Map: `Patient` → `master_data/patient`, `TreatmentSessions` → `transactional_data/session`,
  `Diagnosis` → `transactional_data/assessment`, etc.
- Approach depends on [D1][12]
- Complexity: **HIGH**

**1.2 — Build NexusSync API client**
- Implement in the empty `Networking/` directory
- HTTP client using URLSession for all 5 endpoints: push, pull, upload, download, status
- JWT token storage in Keychain
- Request/response models matching SYNC\_PROTOCOL.md
- Complexity: **MEDIUM**

**1.3 — Device identity and authentication**
- Device registration flow (admin-initiated, one-time)
- Store `device_id`, `device_name`, `api_token` in Keychain
- Token refresh logic
- Complexity: **MEDIUM**

### Phase 2: Sync Engine (HIGH complexity)

**2.1 — Outbound queue**
- Hook into `PatientStore.updatePatientAsync()` to queue changes
- Create `sync/outbound_queue.json` tracking pending push items
- Convert existing `FieldChange` objects into sync push payload format
- Entity-level change detection (not just field-level)
- Complexity: **HIGH**

**2.2 — Three-tier conflict resolution**
- Master data + transactional data: iPad wins (already server-side, client just
  accepts server acknowledgment)
- Parameters: server wins (client applies server version to local parameter files)
- Deletions: never sent (enforce in outbound queue)
- Complexity: **MEDIUM**

**2.3 — Sync state tracking**
- Add `sync_meta.json` per patient (last sync version, sync status)
- Add global `sync/last_sync_state.json` (last\_pull\_version)
- Add `sync/conflict_log.json`
- Complexity: **LOW**

**2.4 — Pull and merge**
- Implement pull response processing
- Parameter updates: overwrite local parameter files, reload `AppGlobals`
- Patient/session updates from other devices: merge into local patient.json
- Complexity: **HIGH** (merge logic for nested patient structure is complex)

### Phase 3: Attachments (MEDIUM complexity)

**3.1 — Attachment upload**
- After successful push, upload pending media files via `POST /sync/upload`
- Track upload status per file (checksum verification)
- Complexity: **MEDIUM**

**3.2 — Attachment download**
- On pull, download new/changed attachments via `GET /sync/download/{token}`
- Store in patient media directory
- Complexity: **MEDIUM**

### Phase 4: Background Sync & UX (MEDIUM complexity)

**4.1 — Background sync scheduling**
- Connectivity monitoring (VPN reachability check via `/sync/status`)
- Automatic push when changes queued + network available
- Periodic pull for parameter updates
- Complexity: **MEDIUM**

**4.2 — Sync UI**
- Replace or augment current `SyncMenuView` (backup/restore) with sync status dashboard
- Show: last sync time, pending changes, conflicts, errors
- Manual sync trigger button
- Keep local backup as separate feature alongside server sync
- Complexity: **LOW**

### Phase 5: Hardening (LOW-MEDIUM complexity)

**5.1 — Fix Therapist ID type** (see [D5][13])
- Migrate `Therapists.id` and `Therapist.id` from `Int` to `UUID`
- Update all references across models and views
- Complexity: **MEDIUM** (widespread references)

**5.2 — Parameter file consolidation**
- Map current 17 parameter files to Nexus parameter entity types
  (`treatment_type`, `icd_code`, `system_config`, `reference_data`)
- Complexity: **LOW**

**5.3 — Fix entitlements**
- Remove `KontoauszugsReader` iCloud references
- Add appropriate entitlements for network access
- Complexity: **LOW**

**5.4 — Error recovery**
- Add patient.json validation on load with recovery from `changes/` backup
- Complexity: **LOW**

### Phase Dependencies

| Phase | Description              | Complexity | Dependencies       |
| ----- | ------------------------ | ---------- | ------------------ |
| 1.1   | Sync serialization layer | HIGH       | [D1][14], [D2][15] |
| 1.2   | API client               | MEDIUM     | None               |
| 1.3   | Device auth              | MEDIUM     | 1.2                |
| 2.1   | Outbound queue           | HIGH       | 1.1                |
| 2.2   | Conflict resolution      | MEDIUM     | 1.2                |
| 2.3   | Sync state tracking      | LOW        | None               |
| 2.4   | Pull and merge           | HIGH       | 1.2, 2.3           |
| 3.1   | Attachment upload        | MEDIUM     | 2.1                |
| 3.2   | Attachment download      | MEDIUM     | 2.4                |
| 4.1   | Background sync          | MEDIUM     | 2.1, 2.4           |
| 4.2   | Sync UI                  | LOW        | 2.1                |
| 5.1   | Fix therapist IDs        | MEDIUM     | [D5][16]           |
| 5.2   | Parameter consolidation  | LOW        | 2.2                |
| 5.3   | Fix entitlements         | LOW        | None               |
| 5.4   | Error recovery           | LOW        | None               |

Phases 1.1 + 1.2 can run in parallel. Phases 2.1-2.4 are the core sync engine.
Phase 3 depends on Phase 2. Phase 5 items can happen anytime.

---

## 10. Decisions — RESOLVED

All decisions finalized 2026-02-14. Summary:

| # | Decision | Resolution |
|---|----------|------------|
| **D1** | Monolithic patient.json | **Option A — Flatten at sync time.** Keep monolithic patient.json internally. Build serialization layer to decompose into individual sync records for push, merge back on pull. |
| **D2** | Sync granularity | **Entity-level snapshots for sync, field-level change logs for audit.** Sync pushes complete entity snapshots. Existing `FieldChange` / `ChangeLog` stays for audit trail. |
| **D3** | Invoice entity type | **Option A — New `transactional_data` entity type `invoice`.** Add to DATA_DICTIONARY.md, sync protocol, and nexus-core. Must link to patient and therapy plan. |
| **D4** | Availability data | **Sync per therapist, iPad wins.** Availability is the therapist's own calendar, stored separately by therapist in Nexus, synced bidirectionally. iPad wins on conflict. |
| **D5** | Therapist ID | **Option A — Migrate `Int` → `UUID` now.** Clean up before sync integration. Must handle migration of existing data on disk. |
| **D6** | Sync module location | **Inside the app.** Sync code lives in the app's Synchronization menu/view area, not a separate package. |
| **D7** | Local backup/restore | **Option B — Replace with sync.** Remove ZIP-based backup/restore. Server becomes the backup via sync. |
| **D8** | App naming | **Option A — Keep "AthleticPerformance".** "nexus-field" is the architectural role name only. |

---

### D1: Monolithic patient.json — flatten at sync time or refactor storage? {#d1}

The current app stores the entire patient object graph (demographics, therapies,
sessions, diagnoses, findings, exercises, invoices) in a single `patient.json`.
The Nexus sync protocol expects individual entity records (one per session, one
per assessment, etc.) that can be synced independently.

**Option A — Flatten at sync time (recommended)**
Keep the monolithic `patient.json` internally. Build a serialization layer that
decomposes it into individual sync records when pushing, and merges incoming
records back into the monolith when pulling.
- Lower risk: no changes to existing app logic or views
- Higher sync-layer complexity
- patient.json still grows unbounded long-term

**Option B — Refactor storage to match Nexus layout**
Split `patient.json` into separate files: `patient.json` (master data only),
`sessions/{id}.json`, `assessments/{id}.json`, etc. Refactor PatientStore and
all views to work with decomposed storage.
- Higher risk: touches every view and store in the app
- Cleaner long-term architecture
- Directly maps to sync protocol
- Addresses the unbounded file growth concern

**Option C — Hybrid: flatten now, refactor later**
Start with Option A to get sync working. Plan Option B as a follow-up phase
once sync is stable.

**Your decision:**

Go with recommended option A - flatten at sync time.

---

### D2: Sync granularity — what is a "change record"? {#d2}

The sync protocol sends `changes[]` where each change has an `entity_type`,
`entity_id`, `operation`, and `data`. The app currently tracks changes at
the field level (`FieldChange` with JSON paths like `/therapies/0/diagnoses/2/title`).

**Option A — Entity-level sync (recommended)**
Each sync change record is a complete entity snapshot (e.g., the full Patient
object, or a full TreatmentSessions object). When any field changes, the
entire entity is pushed.
- Simpler to implement
- Matches the sync protocol design
- More data per sync (but entities are small)

**Option B — Field-level sync**
Send only changed fields per entity, requiring the server to apply patches.
- More efficient bandwidth
- Much more complex (server needs patch logic)
- Doesn't match current sync protocol design

**Your decision:**

Well, these changes are more or less just for audit purposes. If you have a better idea on how to store the changes to fulfill audit requirements and to use this information for data sync, please feel free to implement it.

---

### D3: Invoice entity type {#d3}

`Invoice` has no corresponding Nexus entity type. Invoices are currently stored
inside `Therapy.invoices[]` in patient.json.

**Option A — Add `invoice` as a new transactional\_data entity type**
Define it in DATA\_DICTIONARY.md, add to sync protocol, implement in nexus-core.

**Option B — Treat invoices as part of the session/therapy entity**
Keep invoices nested in the therapy data that gets synced. Server extracts
invoice data during ETL.

**Option C — Don't sync invoices (keep local only)**
Invoices are billing artifacts that may not need central sync. Only the
generated PDF (as an attachment) gets synced.

**Your decision:**

Go with option A as new transactional data which must be linked at least to patient and therapy plan.

---

### D4: Availability data — sync or device-local? {#d4}

`AvailabilitySlot` / `AvailabilityEntry` represents therapist scheduling
(available, vacation, training, blocked). Currently stored per-device in
`availability_{therapistId}.json`.

**Option A — Sync as `event` entity type (bidirectional)**
Availability becomes shared across all iPads via the sync protocol.
One therapist's vacation shows on all devices.

**Option B — Sync as `system_config` parameter (server wins)**
Availability is managed centrally, pushed to all iPads.

**Option C — Keep device-local (no sync)**
Each iPad manages its own availability. Simplest, but risks scheduling
conflicts when multiple iPads schedule for the same therapist.

**Your decision:**

The availability must be considered and managed by therapist. It should be stored in nexus separately by therapist. It is their own calendar!

---

### D5: Therapist ID migration — Int to UUID? {#d5}

`Therapists.id` and `Therapist.id` currently use `Int` (e.g., `1`, `2`).
This will collide across iPads (both devices have therapist ID `1`) and
doesn't match the UUID-based Nexus entity model.

**Option A — Migrate to UUID before sync integration**
Change all therapist IDs to UUID, update all model references, migrate
existing data. Do this before building the sync layer.
- Clean foundation for sync
- Risk: widespread changes across models and views (\~40+ references)

**Option B — Map Int→UUID at sync boundary**
Keep Int internally, maintain a mapping table `Int ↔ UUID` for sync.
- Lower risk to existing code
- Adds mapping complexity in sync layer
- Mapping must be consistent across devices (who assigns the UUID?)

**Option C — Defer until later**
Don't change therapist IDs now. Address when it becomes a concrete problem.

**Your decision:**

Go with option A and clean up now. We need to have in mind that the clean up must be carried out on existing data.

---

### D6: Sync module location — inside app or separate Swift package? {#d6}

The NexusSync module needs a home.

**Option A — Inside the app in `Networking/` directory**
Simple, direct access to all app models. No package overhead.

**Option B — Local Swift package `NexusSync`**
Create `Packages/NexusSync/` alongside `MediaInputKit`. Clean separation,
independently testable, could potentially be shared with other apps.

**Your decision:**

The home will be the Synchronization menu/view of the app.

---

### D7: What happens to local backup/restore? {#d7}

The current `BackupView` / `RestoreView` provides ZIP-based local backup.
Once sync is implemented:

**Option A — Keep alongside sync**
Local backup remains as a safety net. Sync handles server communication,
ZIP backup handles local disaster recovery.

**Option B — Replace with sync**
Remove local backup once sync is reliable. Server becomes the backup.

**Option C — Keep but rebrand**
Rename from "Sync" menu to "Backup" and add a separate "Sync" section
for the Nexus server sync.

**Your decision:**

Replace ist with sync.

---

### D8: nexus-field naming — rename app or keep AthleticPerformance? {#d8}

The Nexus architecture documents refer to the iPad app as "nexus-field".
The actual app is called "AthleticPerformance".

**Option A — Keep AthleticPerformance as the app name**
The Nexus sync module lives inside it but the app identity stays.
"nexus-field" is just the architectural role name.

**Option B — Rename to NexusField**
Full rebrand to align with architecture docs. Major change.

**Your decision:**

Go with option A. The name Athletic Performance has priority.

[1]:	#d3
[2]:	#d3
[3]:	#d3
[4]:	#d4
[5]:	#d5
[6]:	#d3
[7]:	#d1
[8]:	#d4
[9]:	#d1
[10]:	#d5
[11]:	#d1
[12]:	#d1
[13]:	#d5
[14]:	#d1
[15]:	#d2
[16]:	#d5