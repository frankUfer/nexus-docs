# Nexus Data Warehouse Definition

> Status: WORK IN PROGRESS — built bottom-up from actual source systems
>
> This document defines the data warehouse by starting from each source system's
> real data structures. Every source table is documented with columns, data types,
> nullability, and relationships. The warehouse star model will be derived from
> these definitions — not the other way around.

## How to read this document

Each source is documented as follows:

1. **Source table** — the struct/model as it exists in the source system
2. **Columns** — every field with its data type and constraints
3. **Relationships** — foreign keys and parent/child links to other source tables
4. **Enums** — allowed values for enum-typed columns
5. **Storage** — how and where the data is persisted in the source system
6. **DWH mapping** — (added later) how this source maps to warehouse tables

---

# Source: iPad App (AthleticPerformance)

## 1. AvailabilityEntry

A calendar entry representing a time period with an availability type for a
therapist. Used to manage therapist schedules — when they are available for
appointments, on vacation, in training, or blocked.

**iPad storage**: JSON file per therapist, nested in `Therapist.availability[]`

### 1.1 Columns

| Column       | Type               | Nullable | Description                                      |
|--------------|--------------------|----------|--------------------------------------------------|
| id           | UUID               | no       | PK — unique identifier for this entry            |
| therapistId  | UUID               | no       | FK → Therapists.id — which therapist this belongs to |
| startDate    | DateTime           | no       | Start of the availability period (date + time)   |
| endDate      | DateTime           | no       | End of the availability period (date + time)     |
| type         | AvailabilityType   | no       | What kind of availability this represents        |
| note         | String             | yes      | Free-text comment                                |
| source       | AvailabilitySource | yes      | How this entry was created                       |

### 1.2 Enums

**AvailabilityType**

| Value     | Description                                    |
|-----------|------------------------------------------------|
| available | Therapist is available for appointments        |
| vacation  | Therapist is on vacation                       |
| training  | Therapist is in training / continuing education|
| blocked   | Therapist is not available (other reasons)     |

**AvailabilitySource**

| Value     | Description                                    |
|-----------|------------------------------------------------|
| manual    | Manually entered by a user                     |
| ruleBased | Generated from recurring rules/patterns        |
| holiday   | Created from public holiday calendar            |
| vacation  | Created from vacation planning                 |
| training  | Created from training schedule                 |

### 1.3 Relationships

```
AvailabilityEntry.therapistId  →  Therapists.id
AvailabilityEntry.startDate    →  dim_calendar.full_date  (date portion)
```

Parent: **Therapists** (one therapist has many availability entries)

### 1.4 Therapists (referenced dimension)

The therapist that owns the availability entry. Documented here because it is
the direct parent. Full definition will follow in its own section.

| Column          | Type    | Nullable | Description                          |
|-----------------|---------|----------|--------------------------------------|
| id              | UUID    | no       | PK — unique therapist identifier     |
| firstname       | String  | no       | First name                           |
| lastname        | String  | no       | Last name                            |
| email           | String  | no       | Email address                        |
| isActive        | Bool    | no       | Whether the therapist is active      |

### 1.5 Known issues in current sync implementation

1. **Wrong model synced**: The sync pipeline (`SyncCoordinator`, `EntityExtractor`)
   uses `AvailabilitySlot` (id, start, end) instead of `AvailabilityEntry`.
   `AvailabilitySlot` has no `therapistId`, no `type`, no `note`, no `source`.
   It is an older, incomplete model.

2. **Entity type too generic**: `AvailabilitySlot` is synced as
   `entity_type = "availability"` with `data_category = "transactional_data"`.
   It lands in `fact_transaction` alongside sessions, assessments, and invoices.

3. **No therapist dimension**: `therapistId` is not tracked in any warehouse
   dimension. There is no `dim_therapist`.

4. **Calendar relationship lost**: The date portion of `startDate`/`endDate`
   should link to `dim_calendar` but the current ETL does not extract it.

### 1.6 DWH mapping (proposed)

> To be finalized after all sources are documented.

**Dimension**: `dim_therapist` — sourced from `Therapists`
**Fact**: `fact_availability` — one row per `AvailabilityEntry`

| Fact column      | Source                              | Type        |
|------------------|-------------------------------------|-------------|
| availability_key | generated                           | BIGSERIAL   |
| date_key         | date(startDate) → dim_calendar      | INTEGER     |
| therapist_key    | therapistId → dim_therapist         | INTEGER     |
| device_key       | sync device → dim_device            | INTEGER     |
| entry_id         | AvailabilityEntry.id                | UUID        |
| start_at         | AvailabilityEntry.startDate         | TIMESTAMPTZ |
| end_at           | AvailabilityEntry.endDate           | TIMESTAMPTZ |
| duration_minutes | computed: (endDate - startDate)     | INTEGER     |
| type             | AvailabilityEntry.type              | TEXT        |
| source           | AvailabilityEntry.source            | TEXT        |
| note             | AvailabilityEntry.note              | TEXT        |

This gives typed, queryable columns:
- `WHERE type = 'vacation'` — no JSONB parsing
- `SUM(duration_minutes) WHERE type = 'available'` — direct aggregation
- `JOIN dim_therapist` — therapist name, active status
- `JOIN dim_calendar` — weekday, holiday, fiscal period

---

## 2. Parameters (Reference Data)

Parameters are server-managed lookup tables that the iPad receives via pull sync
(server wins in conflicts). They are stored on the iPad as versioned JSON files
under `Documents/resources/parameter/`. Each file follows the pattern:

```json
{ "version": 1, "items": [ ... ] }
```

Parameters are referenced by UUID from transactional data (findings, sessions,
invoices, etc.). The UUID is the stable key that connects facts to their
reference values. This makes parameters **dimensions** in the warehouse.

**Sync direction**: Server → iPad (server authoritative)
**Conflict resolution**: Server wins

### 2.1 Parameter storage on iPad

| File                          | Struct                  | Description                        |
|-------------------------------|-------------------------|------------------------------------|
| `assessments.json`            | Assessments             | Assessment template definitions    |
| `diagnoseReferenceData.json`  | DiagnoseReferenceData   | ICD-like diagnosis catalog         |
| `endFeelings.json`            | EndFeelings             | Joint end-feel categories          |
| `insurances.json`             | InsuranceCompany        | Insurance company lookup           |
| `jointMovementPatterns.json`  | JointMovementPattern    | Movement patterns with input rules |
| `joints.json`                 | Joints                  | Anatomical joint definitions       |
| `muscleGroups.json`           | MuscleGroups            | Anatomical muscle group catalog    |
| `painQualities.json`          | PainQualities           | Pain descriptor terms              |
| `painStructures.json`         | PainStructures          | Body structures for pain mapping   |
| `physioReferenceData.json`    | PhysioReferenceData     | Body regions, fasciae, chains      |
| `publicAddresses.json`        | PublicAddress            | Treatment locations/venues         |
| `specialties.json`            | Specialty               | Medical specialty catalog          |
| `therapist.json`              | TherapistReference      | Current therapist selection        |
| `tissueStates.json`           | TissueStates            | Tissue condition categories        |
| `tissues.json`                | Tissues                 | Anatomical tissue catalog          |
| `practiceInfo.json`           | PracticeInfo            | Practice, therapists, services     |

---

### 2.2 Simple bilingual parameters (UUID + de + en)

These all share the same structure: a UUID primary key and bilingual labels.
They are used as foreign keys in clinical status entries (findings, session
documentation) and function as **lookup dimensions** in the warehouse.

#### Assessments

Clinical assessment templates (e.g., "Romberg Test", "Trendelenburg Test").

| Column | Type   | Nullable | Description              |
|--------|--------|----------|--------------------------|
| id     | UUID   | no       | PK                       |
| de     | String | no       | German label             |
| en     | String | no       | English label            |

**Referenced by**: `AssessmentStatusEntry.assessmentId`

#### EndFeelings

Joint end-feel categories (e.g., "hard", "elastic", "empty").

| Column | Type   | Nullable | Description              |
|--------|--------|----------|--------------------------|
| id     | UUID   | no       | PK                       |
| de     | String | no       | German label             |
| en     | String | no       | English label            |

**Referenced by**: `JointStatusEntry.endFeeling`

#### Joints

Anatomical joints (e.g., "Schultergelenk" / "Shoulder joint").

| Column | Type   | Nullable | Description              |
|--------|--------|----------|--------------------------|
| id     | UUID   | no       | PK                       |
| de     | String | no       | German label             |
| en     | String | no       | English label            |

**Referenced by**: `JointStatusEntry.joint`

#### MuscleGroups

Anatomical muscle groups (e.g., "Quadrizeps" / "Quadriceps").

| Column | Type   | Nullable | Description              |
|--------|--------|----------|--------------------------|
| id     | UUID   | no       | PK                       |
| de     | String | no       | German label             |
| en     | String | no       | English label            |

**Referenced by**: `MuscleStatusEntry.muscleGroup`

#### PainQualities

Pain descriptors (e.g., "stechend" / "stabbing", "dumpf" / "dull").

| Column | Type   | Nullable | Description              |
|--------|--------|----------|--------------------------|
| id     | UUID   | no       | PK                       |
| de     | String | no       | German label             |
| en     | String | no       | English label            |

**Referenced by**: `JointStatusEntry.painQuality`, `MuscleStatusEntry.painQuality`,
`TissueStatusEntry.painQuality`

#### PainStructures

Body structures associated with pain (e.g., "Kapsel" / "Capsule").

| Column | Type   | Nullable | Description              |
|--------|--------|----------|--------------------------|
| id     | UUID   | no       | PK                       |
| de     | String | no       | German label             |
| en     | String | no       | English label            |

**Referenced by**: `SymptomsStatusEntry` (via pain mapping)

#### Tissues

Anatomical tissue types (e.g., "Sehne" / "Tendon", "Faszie" / "Fascia").

| Column | Type   | Nullable | Description              |
|--------|--------|----------|--------------------------|
| id     | UUID   | no       | PK                       |
| de     | String | no       | German label             |
| en     | String | no       | English label            |

**Referenced by**: `TissueStatusEntry.tissue`

#### TissueStates

Tissue condition categories (e.g., "verkürzt" / "shortened", "entzündet" / "inflamed").

| Column | Type   | Nullable | Description              |
|--------|--------|----------|--------------------------|
| id     | UUID   | no       | PK                       |
| de     | String | no       | German label             |
| en     | String | no       | English label            |

**Referenced by**: `TissueStatusEntry.tissueStates`

---

### 2.3 JointMovementPattern

More complex than simple bilingual lookups — includes input type rules,
value ranges, and units. Defines how joint measurements are captured in the UI.

| Column    | Type        | Nullable | Description                                    |
|-----------|-------------|----------|------------------------------------------------|
| id        | UUID        | no       | PK                                             |
| de        | String      | no       | German label                                   |
| en        | String      | no       | English label                                  |
| inputType | InputType   | no       | How the value is captured in the UI            |
| unit      | String      | yes      | Measurement unit (e.g., "deg", "cm", "bool")  |
| min       | Double      | yes      | Minimum value (for slider/number)              |
| max       | Double      | yes      | Maximum value (for slider/number)              |
| step      | Double      | yes      | Step increment (for slider/number)             |
| default   | DoubleOrBool| yes      | Default value                                  |

**Enum: InputType**

| Value  | Description                         |
|--------|-------------------------------------|
| slider | Continuous range input              |
| toggle | Boolean on/off                      |
| number | Numeric text input                  |
| picker | Selection from predefined options   |

**Referenced by**: `JointStatusEntry.movement`

---

### 2.4 Specialty

Medical specialties for diagnosis sources (referring doctors). Uses a
dictionary for localization instead of flat de/en fields.

| Column | Type              | Nullable | Description                          |
|--------|-------------------|----------|--------------------------------------|
| id     | String            | no       | PK (not UUID — string identifier)   |
| name   | Dict[String,String]| no      | Localized names: `{"de":"...","en":"..."}` |
| source | String            | no       | "central" (server-managed) or "user" |

**Referenced by**: `DiagnosisSource.specialty`

---

### 2.5 InsuranceCompany

Insurance company lookup. Used for patient insurance assignment.

| Column | Type   | Nullable | Description                          |
|--------|--------|----------|--------------------------------------|
| id     | String | no       | PK (not UUID — string identifier)   |
| name   | String | no       | Company name                         |
| source | String | no       | "central" or "user"                  |

**Referenced by**: `Patient.insurance` (by name, not by id — loose coupling)

---

### 2.6 PublicAddress

Treatment locations and venues (fitness centers, sports fields, clinics).

| Column  | Type    | Nullable | Description                          |
|---------|---------|----------|--------------------------------------|
| id      | UUID    | no       | PK                                   |
| label   | String  | no       | Category (e.g., "Fitness-Center")    |
| name    | String  | no       | Location name (e.g., "McFit Berlin") |
| address | Address | no       | Full address (see below)             |

**Embedded: Address**

| Column           | Type   | Nullable | Description                   |
|------------------|--------|----------|-------------------------------|
| street           | String | no       | Street and number             |
| postalCode       | String | no       | Postal code                   |
| city             | String | no       | City                          |
| country          | String | no       | Country (default: "Germany")  |
| isBillingAddress | Bool   | no       | Billing address flag          |
| latitude         | Double | yes      | GPS latitude                  |
| longitude        | Double | yes      | GPS longitude                 |

**Referenced by**: `TreatmentSessions.address` (by matching, not FK)

---

### 2.7 DiagnoseReferenceData

Hierarchical diagnosis catalog (ICD-like). Structured as categories containing
terms, not as a flat UUID list. Terms are identified by their German text, not
by UUID.

| Level    | Column      | Type   | Description                              |
|----------|-------------|--------|------------------------------------------|
| Root     | diagnoseCategories | [DiagnoseCategory] | All categories            |
| Category | category_de | String | PK — German category name                |
|          | category_en | String | English category name                    |
|          | terms       | [DiagnoseTerm] | Terms within this category        |
| Term     | de          | String | PK — German term (e.g., "M54.5 Rückenschmerzen") |
|          | en          | String | English term (e.g., "M54.5 Low back pain") |

**Referenced by**: `Diagnosis.title` (by text match, not FK)

**Note**: No UUID identifiers — uses text-based identity. This makes it harder
to track as a warehouse dimension. Consider adding UUIDs in a future version.

---

### 2.8 PhysioReferenceData

Comprehensive physiotherapy reference catalog. Hierarchical, text-identified
(no UUIDs). Five sub-catalogs in a single file.

| Sub-catalog        | Structure                            | Description                     |
|--------------------|--------------------------------------|---------------------------------|
| bodyRegions        | BodyRegionGroup → BodyPart[]         | Anatomical regions with parts   |
| fasciaRegions      | FasciaRegion → Fascia[]              | Fascia regions with fasciae     |
| myofascialChains   | MyofascialChain[]                    | Myofascial chain definitions    |
| neurologicalAreas  | NeurologicalArea[]                   | Neurological area definitions   |
| functionalUnits    | FunctionalUnit[]                     | Functional unit definitions     |

All sub-items follow the same pattern:

| Column | Type   | Description                           |
|--------|--------|---------------------------------------|
| de     | String | PK — German label                     |
| en     | String | English label                         |

**Referenced by**: `SymptomsStatusEntry.bodyRegion`, `SymptomsStatusEntry.bodyPart`

**Note**: Like DiagnoseReferenceData, uses text-based identity instead of UUIDs.

---

### 2.9 PracticeInfo, Therapists, TreatmentService

These three entities are stored together in a single file (`practiceInfo.json`)
but represent **three distinct data categories** that must be separated in the
warehouse:

| Entity           | Data category       | DWH role          |
|------------------|---------------------|-------------------|
| PracticeInfo     | Master data         | `dim_practice`    |
| Therapists       | Master data         | `dim_therapist`   |
| TreatmentService | Dimensional / param | `dim_service`     |

**iPad storage**: Single file `Documents/resources/parameter/practiceInfo.json`
```json
{
  "version": 1,
  "items": [{
    "id": 1,
    "name": "...",
    "therapists": [ ... ],
    "services": [ ... ]
  }]
}
```

---

#### 2.9.1 PracticeInfo (master data)

The practice or clinic that operates the system. There is exactly one practice
per installation. This is organizational master data — it identifies the legal
entity that employs the therapists, owns the iPads, and issues invoices.

| Column       | Type    | Nullable | Description                            |
|--------------|---------|----------|----------------------------------------|
| id           | Int     | no       | PK (integer, not UUID)                 |
| name         | String  | no       | Practice / clinic name                 |
| address      | Address | no       | Main practice address                  |
| startAddress | Address | no       | Starting point for home visits         |
| phone        | String  | no       | Contact phone number                   |
| email        | String  | no       | Contact email address                  |
| website      | String  | no       | Website URL                            |
| taxNumber    | String  | no       | Tax identification number              |
| bank         | String  | no       | Bank name                              |
| iban         | String  | no       | IBAN                                   |
| bic          | String  | no       | BIC / SWIFT code                       |

**Embedded: Address** (used for both `address` and `startAddress`)

| Column           | Type   | Nullable | Description                   |
|------------------|--------|----------|-------------------------------|
| street           | String | no       | Street and number             |
| postalCode       | String | no       | Postal code                   |
| city             | String | no       | City                          |
| country          | String | no       | Country (default: "Germany")  |
| isBillingAddress | Bool   | no       | Billing address flag          |
| latitude         | Double | yes      | GPS latitude                  |
| longitude        | Double | yes      | GPS longitude                 |

**Children**: Therapists[], TreatmentService[] (embedded, see below)

**Referenced by**: Invoice (provider fields are denormalized copies of PracticeInfo:
`providerName`, `providerAddress`, `providerPhone`, `providerEmail`, `providerBank`,
`providerIBAN`, `providerBIC`, `providerTaxId`)

**DWH mapping**: `dim_practice` — single row, SCD Type 2 for address/contact changes.
Banking and tax fields are needed for invoice analytics and reconciliation.

---

#### 2.9.2 Therapists (master data)

The therapists who work at the practice. This is the identity record — name,
email, active status. A separate struct `Therapist` extends this with scheduling
data (availability entries, therapy plans) but shares the same `id`.

**Two structs, one identity:**

| Struct       | Purpose                           | Fields beyond id              |
|--------------|-----------------------------------|-------------------------------|
| `Therapists` | Identity (in PracticeInfo)        | firstname, lastname, email, isActive |
| `Therapist`  | Scheduling (in calendar system)   | calendarLayerId, availability[], therapyPlans[] |

Both use the same `id: UUID`. The `Therapist` struct references `Therapists.id`.

**Therapists columns** (identity — the master data):

| Column    | Type   | Nullable | Description                          |
|-----------|--------|----------|--------------------------------------|
| id        | UUID   | no       | PK — therapist identifier            |
| firstname | String | no       | First name                           |
| lastname  | String | no       | Last name                            |
| email     | String | no       | Email address                        |
| isActive  | Bool   | no       | Whether currently active             |

**Therapist columns** (scheduling extension):

| Column          | Type                | Nullable | Description                       |
|-----------------|---------------------|----------|-----------------------------------|
| id              | UUID                | no       | FK → Therapists.id                |
| calendarLayerId | UUID                | no       | Links to calendar UI layer        |
| availability    | [AvailabilityEntry] | no       | Availability entries (see §1)     |
| therapyPlans    | [TherapyPlan]       | no       | Assigned therapy plans            |

**Referenced by** (the therapist UUID appears in almost every transactional record):

| Referencing entity               | Column       | Relationship              |
|----------------------------------|--------------|---------------------------|
| AvailabilityEntry                | therapistId  | This therapist's schedule |
| Therapy                          | therapistId  | Lead therapist for case   |
| TreatmentSessions                | therapistId  | Who conducted the session |
| Finding                          | therapistId  | Who performed examination |
| Exercise                         | therapistId  | Who prescribed exercise   |
| TherapySessionDocumentation      | therapistId  | Who documented session    |
| PreTreatmentDocumentation        | therapistId  | Who did informed consent  |
| DischargeReport                  | therapistId  | Who wrote discharge       |
| Anamnesis                        | therapistId  | Who took medical history  |

**DWH mapping**: `dim_therapist` — SCD Type 2 (tracks name changes, active/inactive
transitions). The therapist UUID is a foreign key in virtually every fact table.

| dim_therapist column | Source             | Type        |
|----------------------|--------------------|-------------|
| therapist_key        | generated          | SERIAL (PK) |
| therapist_id         | Therapists.id      | UUID        |
| firstname            | Therapists.firstname| TEXT       |
| lastname             | Therapists.lastname | TEXT       |
| email                | Therapists.email   | TEXT        |
| is_active            | Therapists.isActive| BOOLEAN     |
| practice_key         | → dim_practice     | INTEGER     |
| valid_from           | ETL-managed        | TIMESTAMPTZ |
| valid_to             | ETL-managed        | TIMESTAMPTZ |

---

#### 2.9.3 TreatmentService (dimensional data)

The catalog of treatments and services that can be applied to patients and
invoiced. This is a **dimension** — it defines what services exist, their billing
codes, prices, and units. It is referenced by both clinical records (what was
done) and financial records (what was billed).

| Column      | Type   | Nullable | Description                              |
|-------------|--------|----------|------------------------------------------|
| internalId  | UUID   | no       | PK — stable internal identifier          |
| id          | String | no       | Catalog code (e.g., "MT", "KG")          |
| de          | String | no       | German service name                      |
| en          | String | no       | English service name                     |
| billingCode | String | yes      | Heilmittelkatalog code (e.g., "30201")   |
| quantity    | Int    | yes      | Default quantity (e.g., 20 for minutes)  |
| unit        | String | yes      | Unit of measure ("session", "min")       |
| price       | Double | yes      | Suggested price per unit                 |
| isBillable  | Bool   | no       | Whether this service can be invoiced     |

**Two identifiers** on TreatmentService:
- `internalId` (UUID) — the primary key, used by all referencing records
- `id` (String, catalog code e.g. "MT") — display/catalog identifier, not used as FK

All references use `internalId` (stored as UUID string):

| Referencing entity          | Column                | References                 |
|-----------------------------|-----------------------|----------------------------|
| TherapyPlan                 | treatmentServiceIds[] | → internalId (UUID)        |
| TreatmentSessions           | treatmentServiceIds[] | → internalId (UUID)        |
| AppliedTreatment            | serviceId             | → internalId (UUID)        |
| DiagnosisTreatments         | treatmentService      | → internalId (UUID)        |
| InvoiceItem                 | serviceId             | → internalId (as String)   |
| InvoiceServiceAggregation   | serviceId             | → internalId (as String)   |
| BillingEntry                | service               | → full TreatmentService object |

**DWH mapping**: `dim_service` — SCD Type 2 (tracks price changes, billing code
updates). Both IDs must be preserved so the dimension can join to both clinical
and financial facts.

| dim_service column | Source                      | Type        |
|--------------------|-----------------------------|-------------|
| service_key        | generated                   | SERIAL (PK) |
| service_id         | TreatmentService.internalId | UUID        |
| catalog_code       | TreatmentService.id         | TEXT        |
| de                 | TreatmentService.de         | TEXT        |
| en                 | TreatmentService.en         | TEXT        |
| billing_code       | TreatmentService.billingCode| TEXT        |
| default_quantity   | TreatmentService.quantity   | INTEGER     |
| unit               | TreatmentService.unit       | TEXT        |
| price              | TreatmentService.price      | NUMERIC(10,2) |
| is_billable        | TreatmentService.isBillable | BOOLEAN     |
| practice_key       | → dim_practice              | INTEGER     |
| valid_from         | ETL-managed                 | TIMESTAMPTZ |
| valid_to           | ETL-managed                 | TIMESTAMPTZ |

---

### 2.10 TherapistReference

Points to the currently selected therapist on this iPad. Not a lookup table
per se, but a parameter-synced configuration value.

| Column | Type | Nullable | Description                          |
|--------|------|----------|--------------------------------------|
| id     | UUID | no       | FK → Therapists.id                   |

---

### 2.11 Enums used across parameters (not file-stored)

These are code-level enums, not separate parameter files. They define fixed
value sets used in clinical status entries.

**BodySides**

| Value     | Description  |
|-----------|--------------|
| left      | Left side    |
| right     | Right side   |
| bilateral | Both sides   |

**PainLevels** — Integer 0–10 (NRS pain scale), not file-stored.

**MuscleTone** — Integer -3 to +3, displayed as "---" to "+++".

---

### 2.12 Known issues with parameter handling in current warehouse

1. **No parameter dimensions exist**: The warehouse has no tables for any of
   these parameters. When clinical data (findings, sessions) references a
   joint UUID or muscle group UUID, the warehouse cannot resolve it to a name.

2. **JSONB black hole**: All parameter references are buried inside the `data`
   JSONB column of `sync_entity` and `fact_transaction`. To query "which joint
   was assessed", you'd need `data->'joint'->>'id'` and then look it up
   manually — the warehouse has no join target.

3. **Mixed ID types**: Most parameters use UUID (joints, muscles, tissues,
   assessments, endFeelings, painQualities, painStructures, publicAddresses),
   but some use String (specialties, insurances). TreatmentService has two
   IDs (`internalId` UUID + `id` catalog code) but all FKs use `internalId`.

4. **Text-based references**: DiagnoseReferenceData and PhysioReferenceData
   have no UUIDs at all — they use German text as identity. This makes
   dimensional tracking fragile (a text correction breaks the link).

5. **Therapists not a separate parameter file**: Therapists are embedded in
   `practiceInfo.json`, making them harder to sync and version independently.

### 2.13 DWH mapping (proposed)

> To be finalized after all sources are documented.

**Simple bilingual parameters** → single shared dimension table or individual
dimension tables per parameter type:

| Option A: Shared `dim_parameter`  | Option B: Dedicated dimensions       |
|-----------------------------------|--------------------------------------|
| One table, `parameter_type` column| `dim_joint`, `dim_muscle_group`, ... |
| Simpler schema, fewer tables      | Stronger typing, clearer joins       |
| Risk: becomes a junk dimension    | More tables but each is focused      |

**Therapists** → `dim_therapist` (SCD Type 2 for name/active changes)

**TreatmentService** → `dim_treatment_service` (includes billing code, price)

**PracticeInfo** → `dim_practice` (organizational data, address, banking)

**DiagnoseReferenceData** → needs UUID assignment before it can be a proper
dimension. Currently text-based identity only.

---

## 3. Invoice

An invoice is a billing document generated from completed treatment sessions.
It consists of three parts that must be handled separately in the warehouse:

| Part                       | Source struct              | DWH role                     |
|----------------------------|---------------------------|------------------------------|
| Invoice header             | `Invoice`                 | `fact_invoice` (one row)     |
| Invoice line items         | `InvoiceItem`             | `fact_invoice_item` (detail) |
| Invoice PDF                | binary file on disk       | `fact_attachment` (file ref) |

**iPad storage**: Per patient directory, both JSON and PDF side by side:
```
Documents/patients/{patientId}/invoices/
├── {invoiceNumber}.json     ← Invoice struct (header + items + aggregation)
└── {invoiceNumber}.pdf      ← Generated PDF document
```

The `pdfPath` field on Invoice stores the relative path to the PDF file.

---

### 3.1 Invoice (header / fact)

The billing document header. Contains recipient, provider, amounts, and
lifecycle status. Provider fields are **denormalized copies** of PracticeInfo
at the time the invoice was created (snapshot, not FK reference).

| Column             | Type        | Nullable | Description                                |
|--------------------|-------------|----------|--------------------------------------------|
| id                 | UUID        | no       | PK — unique invoice identifier             |
| invoiceType        | InvoiceType | no       | Type of document                           |
| invoiceNumber      | String      | no       | Sequential invoice number (filename key)   |
| reversalNumber     | String      | yes      | Linked reversal invoice number             |
| therapyPlanId      | UUID        | no       | FK → TherapyPlan.id — which plan was billed |
| invoiceBasis       | String      | no       | Basis for billing (e.g., diagnosis text)   |
| diagnosisSource    | String      | no       | Name of referring doctor/source            |
| diagnosisDate      | String      | no       | Date of diagnosis (stored as String)       |
| date               | Date        | no       | Invoice date                               |
| dueDate            | Date        | no       | Payment due date                           |
| **Recipient**      |             |          |                                            |
| patientId          | UUID        | no       | FK → Patient.id                            |
| patientName        | String      | no       | Denormalized patient name at creation      |
| patientAddress     | Address     | no       | Denormalized patient address at creation   |
| patientEmail       | String      | no       | Denormalized patient email at creation     |
| **Provider**       |             |          |                                            |
| therapistFullName  | String      | no       | Denormalized therapist name               |
| providerName       | String      | no       | Practice name (from PracticeInfo)          |
| providerAddress    | Address     | no       | Practice address (from PracticeInfo)       |
| providerPhone      | String      | no       | Practice phone (from PracticeInfo)         |
| providerEmail      | String      | no       | Practice email (from PracticeInfo)         |
| providerBank       | String      | no       | Bank name (from PracticeInfo)              |
| providerIBAN       | String      | no       | IBAN (from PracticeInfo)                   |
| providerBIC        | String      | no       | BIC (from PracticeInfo)                    |
| providerTaxId      | String      | no       | Tax number (from PracticeInfo)             |
| **Line items**     |             |          |                                            |
| items              | [InvoiceItem] | no     | Detail line items (see §3.2)               |
| aggregatedItems    | [InvoiceServiceAggregation] | no | Grouped summary for PDF display  |
| **Amounts**        |             |          |                                            |
| subtotal           | Double      | no       | Net total before tax                       |
| taxRate            | Double      | no       | Tax rate (e.g., 0.19 for 19%)             |
| totalAmount        | Double      | no       | Gross total including tax                  |
| **Status & output**|             |          |                                            |
| pdfPath            | String      | no       | Relative path to generated PDF file        |
| isCreated          | Bool        | no       | Invoice has been generated                 |
| isChecked          | Bool        | no       | Invoice has been reviewed                  |
| isSent             | Bool        | no       | Invoice has been sent to patient           |
| isReversed         | Bool        | no       | Invoice has been reversed/cancelled        |
| isPaid             | Bool        | no       | Payment has been received                  |
| paymentDate        | Date        | yes      | When payment was received                  |
| paymentMethod      | String      | yes      | How payment was made                       |
| isOverDue          | Bool        | computed | `dueDate < today` (not stored)             |

**Enum: InvoiceType**

| Value      | Description                                   |
|------------|-----------------------------------------------|
| invoice    | Standard invoice                              |
| reversal   | Reversal / cancellation of a previous invoice |
| creditNote | Credit note                                   |

### 3.2 InvoiceItem (line items / detail fact)

Each line item represents one treatment service applied in one session.
The grain is: **one service × one session = one row**.

| Column             | Type   | Nullable | Description                                 |
|--------------------|--------|----------|---------------------------------------------|
| id                 | UUID   | no       | PK — unique line item identifier            |
| sessionId          | String | no       | FK → TreatmentSessions.id (as UUID string)  |
| serviceId          | String | no       | FK → TreatmentService.internalId (as UUID string) |
| serviceDate        | Date   | no       | Date the service was performed              |
| serviceDescription | String | no       | Service name (denormalized from TreatmentService.de) |
| billingCode        | String | yes      | Billing code (denormalized from TreatmentService) |
| quantity           | Int    | no       | Number of units billed                      |
| unitPrice          | Double | no       | Price per unit at time of invoicing         |
| notes              | String | yes      | Optional line item notes                    |

**Computed**: `lineTotal = quantity × unitPrice` (not stored, derived)

### 3.3 InvoiceServiceAggregation (display summary — not for DWH)

Groups InvoiceItems by `serviceId` for PDF rendering. This is a **derived
view** of InvoiceItem, not an independent entity. The warehouse should NOT
store this separately — it can be computed from `fact_invoice_item` at query
time via `GROUP BY service_key`.

| Column             | Type   | Nullable | Description                         |
|--------------------|--------|----------|-------------------------------------|
| id                 | UUID   | no       | PK                                  |
| serviceId          | String | no       | FK → TreatmentService.internalId    |
| serviceDescription | String | no       | Service name                        |
| billingCode        | String | yes      | Billing code                        |
| quantity           | Int    | no       | Total quantity across sessions      |
| unitPrice          | Double | no       | Price per unit                      |

### 3.4 Invoice PDF (binary attachment)

The rendered PDF document. Stored on iPad at
`Documents/patients/{patientId}/invoices/{invoiceNumber}.pdf`.
Must be uploaded to the server during sync and tracked in the warehouse.

| Attribute    | Value                                                   |
|--------------|---------------------------------------------------------|
| File format  | PDF                                                     |
| Naming       | `{invoiceNumber}.pdf`                                   |
| iPad path    | `patients/{patientId}/invoices/{invoiceNumber}.pdf`     |
| Server path  | `/var/nexus/attachments/{invoiceId}/{invoiceNumber}.pdf` |
| Linked to    | Invoice.id (entity_id in sync attachment)               |
| Content      | Formatted invoice with header, line items, totals       |

### 3.5 Relationships

```
Invoice.patientId       →  Patient.id
Invoice.therapyPlanId   →  TherapyPlan.id
InvoiceItem.sessionId   →  TreatmentSessions.id
InvoiceItem.serviceId   →  TreatmentService.internalId
Invoice.pdfPath         →  binary PDF file on disk
```

Reversal chain:
```
Invoice (type=reversal)  .reversalNumber  →  Invoice (type=invoice) .invoiceNumber
Invoice (type=invoice)   .isReversed=true,  .reversalNumber → reversal invoice number
```

When an invoice is reversed:
1. Original invoice: `isReversed = true`, `reversalNumber` set
2. New reversal invoice created with `invoiceType = .reversal`
3. Reversal items have negative quantities (via `asReversal()`)
4. Sessions linked to the original invoice are reset to `isDone` status

### 3.6 Known issues in current sync implementation

1. **Invoice synced as generic entity**: `EntityExtractor.extractInvoice()` sends
   the entire Invoice as a single `entity_type = "invoice"` with all fields
   (including nested items and aggregatedItems) dumped into `data: JSONB`.
   No separation of header and line items.

2. **No line item grain in warehouse**: `fact_transaction` receives the invoice
   as one row. Individual line items — the most analytically valuable part
   (revenue per service, per session, per therapist) — are buried in JSONB.

3. **PDF not uploaded**: Attachment pipeline is stubbed (`attachments: []` in
   push). Invoice PDFs are never sent to the server.

4. **Provider fields are snapshots**: The invoice captures practice info at
   creation time. If the practice address or bank details change later, old
   invoices retain the original values. This is correct business behavior
   (the invoice must reflect what was valid when issued) but means the warehouse
   should NOT join invoice provider fields to `dim_practice` — they should be
   stored as-is on the invoice fact.

5. **diagnosisDate is String**: Stored as free text, not a proper Date. Cannot
   reliably join to `dim_calendar` without parsing.

### 3.7 DWH mapping (proposed)

> To be finalized after all sources are documented.

#### fact_invoice (header grain — one row per invoice)

| Fact column        | Source                        | Type          |
|--------------------|-------------------------------|---------------|
| invoice_key        | generated                     | BIGSERIAL     |
| date_key           | date(Invoice.date) → dim_calendar | INTEGER   |
| due_date_key       | date(Invoice.dueDate) → dim_calendar | INTEGER |
| patient_key        | patientId → dim_patient       | INTEGER       |
| therapist_key      | therapistFullName → dim_therapist | INTEGER   |
| practice_key       | → dim_practice                | INTEGER       |
| therapy_plan_key   | therapyPlanId → dim_therapy_plan | INTEGER   |
| device_key         | sync device → dim_device      | INTEGER       |
| invoice_id         | Invoice.id                    | UUID          |
| invoice_number     | Invoice.invoiceNumber         | TEXT          |
| invoice_type       | Invoice.invoiceType           | TEXT          |
| reversal_number    | Invoice.reversalNumber        | TEXT          |
| subtotal           | Invoice.subtotal              | NUMERIC(10,2) |
| tax_rate           | Invoice.taxRate               | NUMERIC(5,4)  |
| total_amount       | Invoice.totalAmount           | NUMERIC(10,2) |
| pdf_storage_path   | server path to uploaded PDF   | TEXT          |
| is_created         | Invoice.isCreated             | BOOLEAN       |
| is_checked         | Invoice.isChecked             | BOOLEAN       |
| is_sent            | Invoice.isSent                | BOOLEAN       |
| is_reversed        | Invoice.isReversed            | BOOLEAN       |
| is_paid            | Invoice.isPaid                | BOOLEAN       |
| payment_date       | Invoice.paymentDate           | TIMESTAMPTZ   |
| payment_method     | Invoice.paymentMethod         | TEXT          |
| patient_name       | Invoice.patientName           | TEXT          |
| provider_name      | Invoice.providerName          | TEXT          |
| diagnosis_source   | Invoice.diagnosisSource       | TEXT          |

Note: `patient_name` and `provider_name` are stored as snapshot values on the
fact (not resolved via dimension join) because the invoice must preserve the
values that were valid at the time of creation.

#### fact_invoice_item (line item grain — one row per service × session)

| Fact column        | Source                        | Type          |
|--------------------|-------------------------------|---------------|
| invoice_item_key   | generated                     | BIGSERIAL     |
| invoice_key        | → fact_invoice                | BIGINT        |
| date_key           | date(serviceDate) → dim_calendar | INTEGER    |
| session_key        | sessionId → fact_session      | BIGINT        |
| service_key        | serviceId → dim_service       | INTEGER       |
| item_id            | InvoiceItem.id                | UUID          |
| service_date       | InvoiceItem.serviceDate       | DATE          |
| quantity           | InvoiceItem.quantity          | INTEGER       |
| unit_price         | InvoiceItem.unitPrice         | NUMERIC(10,2) |
| line_total         | computed: quantity × unitPrice| NUMERIC(10,2) |
| billing_code       | InvoiceItem.billingCode       | TEXT          |
| notes              | InvoiceItem.notes             | TEXT          |

This enables:
- `SUM(line_total) GROUP BY service_key` — revenue per treatment service
- `SUM(line_total) GROUP BY therapist_key` — revenue per therapist
- `SUM(line_total) GROUP BY date_key` — revenue over time
- `JOIN dim_service` — billing code, service name
- `JOIN fact_invoice` — payment status, invoice type
- `WHERE invoice_type = 'reversal'` — identify cancelled revenue

---

## 4. Patient

The patient is the most complex source structure. It combines master data,
dimensional enums, and deeply nested transactional data under a single root
object. The containment hierarchy on the iPad is:

```
Patient
├── addresses[]              ← master data (embedded)
├── phoneNumbers[]           ← master data (embedded)
├── emailAddresses[]         ← master data (embedded)
├── emergencyContacts[]      ← master data (embedded)
├── anamnesis                ← master data (embedded)
└── therapies[]              ← transactional container
    ├── diagnoses[]          ← transactional
    │   ├── source           ← dimensional (→ future dim_doctor)
    │   ├── treatments[]     ← transactional
    │   └── mediaFiles[]     ← binary attachments (JPG)
    ├── findings[]           ← transactional (clinical assessment)
    ├── preTreatment         ← transactional (consent documentation)
    ├── exercises[]          ← transactional
    ├── therapyPlans[]       ← transactional
    │   ├── treatmentSessions[]     ← transactional (appointments)
    │   └── sessionDocs[]           ← transactional (clinical docs)
    │       └── appliedTreatments[] ← transactional (services applied)
    ├── dischargeReport      ← transactional (+ PDF)
    └── invoices[]           ← transactional (see §3)
```

**iPad storage**: One JSON file per patient at
`Documents/patients/{patientId}/patient.json`, wrapped in a `PatientFile`
envelope with a `version` field. All nested structures (therapies, diagnoses,
plans, sessions, etc.) are stored inside this single file.

---

### 4.1 Dimensional enums (patient-level)

These are code-level enums with no UUID, no file storage. They define fixed
value sets for patient classification fields.

#### PatientTitle

| Value   | rawValue   | Description          |
|---------|------------|----------------------|
| none    | ""         | No title             |
| dr      | "Dr."      | Doctor               |
| prof    | "Prof."    | Professor            |
| profDr  | "Prof. Dr."| Professor Doctor     |

**Source**: `Models/Patient/PatientTitle.swift`

#### Gender

| Value   | rawValue  | Description         |
|---------|-----------|---------------------|
| male    | "male"    | Male                |
| female  | "female"  | Female              |
| diverse | "diverse" | Diverse/non-binary  |
| unknown | "unknown" | Not specified       |

**Source**: `Models/Patient/Gender.swift`

#### InsuranceStatus

| Value            | rawValue          | Description          |
|------------------|-------------------|----------------------|
| privateInsurance | "privateInsurance" | Private insurance    |
| selfPaying       | "selfPaying"      | Self-paying          |
| publicInsurance  | "publicInsurance"  | Public (statutory)   |
| other            | "other"           | Other/unspecified    |

**Source**: `Models/Patient/InsuranceStatus.swift`

#### PaymentBehavior

| Value           | rawValue          | Description                |
|-----------------|-------------------|----------------------------|
| reliable        | "reliable"        | Always on time             |
| lateSometimes   | "lateSometimes"   | Occasionally late          |
| chronicallyLate | "chronicallyLate" | Frequently late            |
| problematic     | "problematic"     | Very problematic           |

**Source**: `Models/Patient/Patient.swift` (defined at bottom of file)

#### DWH note on patient enums

These enums do NOT need separate dimension tables. They should be stored as
`TEXT` columns on `dim_patient` and decoded at query/report time. The value
sets are small, stable, and have no additional attributes.

---

### 4.2 Patient (master data → dim_patient)

The patient record. This is the central entity of the entire system — every
therapy, invoice, session, and attachment ultimately belongs to a patient.

| Column           | Type                          | Nullable | Description                                    |
|------------------|-------------------------------|----------|------------------------------------------------|
| id               | UUID                          | no       | PK — unique patient identifier                 |
| title            | PatientTitle                  | no       | Academic title (enum)                          |
| firstnameTerms   | Bool                          | no       | Uses first name terms (Du/Sie)                 |
| firstname        | String                        | no       | First name                                     |
| lastname         | String                        | no       | Last name                                      |
| birthdate        | Date                          | no       | Date of birth                                  |
| sex              | Gender                        | no       | Gender (enum)                                  |
| addresses        | [LabeledValue\<Address\>]     | no       | Labeled addresses (home, work, other)          |
| phoneNumbers     | [LabeledValue\<String\>]      | no       | Labeled phone numbers                          |
| emailAddresses   | [LabeledValue\<String\>]      | no       | Labeled email addresses                        |
| emergencyContacts| [LabeledValue\<EmergencyContact\>] | no  | Labeled emergency contacts                     |
| insuranceStatus  | InsuranceStatus               | no       | Insurance type (enum)                          |
| insurance        | String                        | yes      | Insurance provider name                        |
| insuranceNumber  | String                        | yes      | Insurance policy number                        |
| familyDoctor     | String                        | yes      | Family doctor name                             |
| anamnesis        | Anamnesis                     | yes      | Medical history + lifestyle (embedded)         |
| therapies        | [Therapy?]                    | no       | All therapies for this patient (see §4.5)      |
| isActive         | Bool                          | no       | Whether patient is active (default: true)      |
| dunningLevel     | Int                           | no       | Dunning level 0–4 (default: 0)                |
| paymentBehavior  | PaymentBehavior               | no       | Payment behavior rating (default: reliable)    |
| createdDate      | Date                          | no       | Record creation timestamp                      |
| changedDate      | Date                          | no       | Last modification timestamp                    |

**Source**: `Models/Patient/Patient.swift`

#### Embedded types

**LabeledValue\<T\>** — generic wrapper adding a label to any value:

| Column | Type   | Nullable | Description                     |
|--------|--------|----------|---------------------------------|
| id     | UUID   | no       | PK — unique identifier          |
| label  | String | no       | Label ("private", "work", "other") |
| value  | T      | no       | The wrapped value               |

**Source**: `Models/General/LabeledValue.swift`

**Address**:

| Column           | Type   | Nullable | Description                      |
|------------------|--------|----------|----------------------------------|
| street           | String | no       | Street address                   |
| postalCode       | String | no       | Postal/ZIP code                  |
| city             | String | no       | City name                        |
| country          | String | no       | Country (default: "Germany")     |
| isBillingAddress | Bool   | no       | Is this a billing address?       |
| latitude         | Double | yes      | Geocoded latitude                |
| longitude        | Double | yes      | Geocoded longitude               |

**Source**: `Models/General/Address.swift`

**EmergencyContact**:

| Column    | Type   | Nullable | Description           |
|-----------|--------|----------|-----------------------|
| firstname | String | no       | Contact first name    |
| lastname  | String | no       | Contact last name     |
| phone     | String | no       | Contact phone number  |
| email     | String | no       | Contact email         |

**Source**: `Models/Patient/EmergencyContact.swift`

#### Anamnesis (embedded in Patient)

Medical history and lifestyle assessment. Not a standalone entity — always
part of a Patient record.

**Anamnesis**:

| Column         | Type           | Nullable | Description                    |
|----------------|----------------|----------|--------------------------------|
| therapistId    | UUID           | yes      | Therapist who recorded this    |
| medicalHistory | MedicalHistory | no       | Categorized medical conditions |
| lifestyle      | Lifestyle      | no       | Lifestyle assessment           |

**MedicalHistory** — 14 string-array categories:

| Field              | Type     | Description                    |
|--------------------|----------|--------------------------------|
| orthopedic         | [String] | Orthopedic conditions          |
| neurological       | [String] | Neurological conditions        |
| cardiovascular     | [String] | Cardiovascular conditions      |
| pulmonary          | [String] | Pulmonary conditions           |
| metabolic          | [String] | Metabolic conditions           |
| psychiatric        | [String] | Psychiatric conditions         |
| oncological        | [String] | Cancer-related conditions      |
| autoimmune         | [String] | Autoimmune conditions          |
| infectious         | [String] | Infectious diseases            |
| allergies          | [String] | Known allergies                |
| currentMedications | [String] | Current medications            |
| surgeries          | [String] | Past surgeries                 |
| fractures          | [String] | Bone fracture history          |
| other              | [String] | Other medical history          |

**Lifestyle**:

| Field          | Type            | Description                     |
|----------------|-----------------|---------------------------------|
| occupation     | Occupation      | Work type + description         |
| measurements   | Measurements    | Height (cm), weight (kg)        |
| activityLevel  | ActivityLevel   | low / moderate / high           |
| sports         | Sports          | Active?, types[], equipment[]   |
| balanceIssues  | BalanceIssues   | Has problems?, symptoms[]       |
| smoking        | Smoking         | Status (never/former/current), qty/day |
| alcohol        | Alcohol         | Frequency (none/occasional/regular), units/week |
| nutritionNotes | String          | Free text                       |
| sleepQuality   | SleepQuality    | good / moderate / poor          |
| stressLevel    | StressLevel     | low / medium / high             |

**Source**: `Models/Patient/Anamnesis.swift`

#### DWH mapping: dim_patient (SCD Type 2)

| dim_patient column   | Source                    | Type          |
|----------------------|---------------------------|---------------|
| patient_key          | generated                 | SERIAL (PK)   |
| patient_id           | Patient.id                | UUID           |
| title                | Patient.title             | TEXT           |
| firstname            | Patient.firstname         | TEXT           |
| lastname             | Patient.lastname          | TEXT           |
| birthdate            | Patient.birthdate         | DATE           |
| sex                  | Patient.sex               | TEXT           |
| insurance_status     | Patient.insuranceStatus   | TEXT           |
| insurance            | Patient.insurance         | TEXT           |
| insurance_number     | Patient.insuranceNumber   | TEXT           |
| family_doctor        | Patient.familyDoctor      | TEXT           |
| is_active            | Patient.isActive          | BOOLEAN        |
| dunning_level        | Patient.dunningLevel      | INTEGER        |
| payment_behavior     | Patient.paymentBehavior   | TEXT           |
| created_date         | Patient.createdDate       | TIMESTAMPTZ    |
| valid_from           | ETL-managed               | TIMESTAMPTZ    |
| valid_to             | ETL-managed               | TIMESTAMPTZ    |

**Nested arrays** (addresses, phones, emails, emergency contacts, anamnesis)
should be stored in JSONB on the dimension row. They are too deeply nested and
variable-length for relational columns, but they are rarely queried
independently. If analytics later needs "patients by city" or "patients by
insurance provider", views or materialized columns can extract specific values.

---

### 4.3 TreatmentContract (transactional + PDF)

A treatment contract signed by a patient before therapy begins. This is NOT
a Codable struct — it's constructed in-memory from existing data (Patient +
PracticeInfo) and rendered directly to PDF without storing structured data.

| Column          | Type         | Nullable | Description                           |
|-----------------|--------------|----------|---------------------------------------|
| practice        | PracticeInfo | no       | Practice info at time of signing      |
| patient         | Patient      | no       | Patient info at time of signing       |
| date            | Date         | no       | Signing date                          |
| signatureImage  | UIImage      | no       | Patient's handwritten signature       |
| generatedText   | String       | no       | The contract text content             |

**Source**: `Models/Patient/TreatmentContract.swift`

**iPad storage**: Generated PDF stored at
`Documents/patients/{patientId}/therapy_{therapyId}/contract.pdf`
(no separate JSON — the contract is the PDF itself).

**DWH note**: Since there is no structured data persisted (only a PDF), the
warehouse tracks this as a `fact_attachment` with `attachment_type = 'contract'`.
The signing date can be extracted from the Therapy it belongs to.

---

### 4.4 TherapyAgreement (transactional + PDF)

A therapy agreement confirming patient consent for a specific therapy. Similar
to TreatmentContract, this is rendered to PDF. Not a standalone model struct.

**iPad storage**:
```
Documents/patients/{patientId}/therapy_{therapyId}/
├── agreement.pdf                    ← current agreement
├── agreement2025-01-15.pdf          ← archived version (dated)
└── ...
```

When a new agreement is signed, the existing `agreement.pdf` is archived with
a date suffix, and a new `agreement.pdf` is created.

The `Therapy.isAgreed` flag tracks whether an agreement exists.

**Source**: `Views/Patients/TherapyPackage/TherapyAgreement/TherapyAgreementSection.swift`

**DWH note**: Like TreatmentContract, this is a `fact_attachment` with
`attachment_type = 'agreement'`. The `isAgreed` flag on Therapy is the only
structured data point.

---

### 4.5 Therapy (transactional container)

A therapy case is the top-level container for all clinical work on a patient.
It groups diagnoses, findings, plans, sessions, exercises, and billing.

| Column         | Type                        | Nullable | Description                                 |
|----------------|-----------------------------|----------|---------------------------------------------|
| id             | UUID                        | no       | PK — unique therapy identifier              |
| therapistId    | UUID                        | yes      | FK → Therapists.id — lead therapist         |
| patientId      | UUID                        | no       | FK → Patient.id — which patient             |
| title          | String                      | no       | Therapy title/description                   |
| goals          | String                      | no       | Therapy goals (free text)                   |
| risks          | String                      | no       | Known risks (free text)                     |
| startDate      | Date                        | no       | Therapy start date                          |
| endDate        | Date                        | yes      | Therapy end date (default: +30 days)        |
| diagnoses      | [Diagnosis]                 | no       | See §4.6                                    |
| findings       | [Finding]                   | no       | See §4.7                                    |
| preTreatment   | PreTreatmentDocumentation   | no       | See §4.8                                    |
| exercises      | [Exercise]                  | no       | See §4.9                                    |
| therapyPlans   | [TherapyPlan]               | no       | See §4.10                                   |
| dischargeReport| DischargeReport             | yes      | See §4.14                                   |
| invoices       | [Invoice]                   | no       | See §3 (comment: "=> entfernen!!!")         |
| billingPeriod  | BillingPeriod               | no       | When to bill (enum, see below)              |
| tags           | [String]                    | no       | Tags for filtering/categorization           |
| isAgreed       | Bool                        | no       | Therapy agreement signed?                   |

**Source**: `Models/Therapy/Therapy.swift`

**Computed**: `isCompleted = endDate != nil && dischargeReport != nil`

**Note**: The `invoices` array is marked with "=> entfernen!!!" (remove) in the
source code, indicating it should be moved out of the Therapy struct. Invoices
already have their own file-based storage at
`patients/{patientId}/invoices/{invoiceNumber}.json`.

#### BillingPeriod (dimensional enum)

| Value     | id          | Description                   |
|-----------|-------------|-------------------------------|
| session   | "session"   | Bill after each session       |
| monthly   | "monthly"   | Bill monthly                  |
| quarterly | "quarterly" | Bill quarterly                |
| end       | "end"       | Bill at the end of therapy    |
| custom    | "custom"    | Custom billing arrangement    |

**Source**: `Models/Therapy/Billing/BillingPeriod.swift`

#### DWH mapping: fact_therapy

| Fact column       | Source                  | Type          |
|-------------------|-------------------------|---------------|
| therapy_key       | generated               | BIGSERIAL     |
| patient_key       | patientId → dim_patient | INTEGER       |
| therapist_key     | therapistId → dim_therapist | INTEGER   |
| device_key        | sync device → dim_device| INTEGER       |
| start_date_key    | date(startDate) → dim_calendar | INTEGER |
| end_date_key      | date(endDate) → dim_calendar | INTEGER  |
| therapy_id        | Therapy.id              | UUID          |
| title             | Therapy.title           | TEXT          |
| goals             | Therapy.goals           | TEXT          |
| risks             | Therapy.risks           | TEXT          |
| billing_period    | Therapy.billingPeriod   | TEXT          |
| is_agreed         | Therapy.isAgreed        | BOOLEAN       |
| is_completed      | computed                | BOOLEAN       |
| tags              | Therapy.tags            | TEXT[]        |

---

### 4.6 Diagnosis (transactional)

A medical diagnosis associated with a therapy. Links to the referring doctor
(DiagnosisSource), prescribed treatments, and supporting media files.

| Column      | Type                  | Nullable | Description                           |
|-------------|-----------------------|----------|---------------------------------------|
| id          | UUID                  | no       | PK — unique diagnosis identifier      |
| therapyId   | UUID                  | no       | FK → Therapy.id                       |
| title       | String                | no       | Diagnosis title/description           |
| date        | Date                  | no       | Date of diagnosis                     |
| source      | DiagnosisSource       | no       | Referring doctor/source (see §4.6.1)  |
| treatments  | [DiagnosisTreatments] | no       | Prescribed treatments (see §4.6.2)    |
| notes       | String                | yes      | Additional notes                      |
| mediaFiles  | [MediaFile]           | no       | JPG/image files (see §4.6.3)          |

**Source**: `Models/Therapy/Diagnosis/Diagnosis.swift`

#### 4.6.1 DiagnosisSource (dimensional → future dim_doctor)

The doctor or medical facility that issued the diagnosis. Currently embedded
inline, but structurally should become a dimension table to deduplicate
doctors across patients and diagnoses.

| Column      | Type      | Nullable | Description                       |
|-------------|-----------|----------|-----------------------------------|
| id          | String    | no       | PK — UUID as String               |
| originName  | String    | no       | Doctor/facility name              |
| street      | String    | no       | Street address                    |
| postalCode  | String    | no       | Postal code                       |
| city        | String    | no       | City                              |
| phoneNumber | String    | no       | Phone number                      |
| specialty   | Specialty | yes      | FK → Specialties parameter (§2.7) |
| createdAt   | Date      | no       | Record creation date              |

**Source**: `Models/Therapy/Diagnosis/DiagnosisSource.swift`

**DWH note**: The `id` field uses `String` (not UUID type), initialized via
`UUID().uuidString`. The proposed `dim_doctor` should:
- Deduplicate by (`originName`, `street`, `postalCode`, `city`)
- Track specialty changes (SCD Type 2)
- Assign a proper surrogate `doctor_key`

#### 4.6.2 DiagnosisTreatments (transactional detail)

A prescribed treatment within a diagnosis — e.g., "10 sessions of manual therapy".

| Column           | Type | Nullable | Description                                |
|------------------|------|----------|--------------------------------------------|
| id               | UUID | no       | PK — unique identifier                     |
| number           | Int  | no       | Number of prescribed sessions (default: 10)|
| description      | String | no     | Treatment description                      |
| treatmentService | UUID | yes      | FK → TreatmentService.internalId (§2.9.3)  |

**Source**: `Models/Therapy/Diagnosis/DiagnosisTreatments.swift`

#### 4.6.3 MediaFile (binary attachment)

Media files (images, PDFs, videos) attached to diagnoses, findings, exercises,
and discharge reports. Stored as separate files on the iPad filesystem.

| Column            | Type     | Nullable | Description                         |
|-------------------|----------|----------|-------------------------------------|
| id                | UUID     | no       | PK — unique file identifier         |
| filename          | String   | no       | File name (e.g., "scan.jpg")        |
| fileType          | FileType | no       | Derived from extension (see enum)   |
| date              | Date     | no       | File creation/recording date        |
| description       | String   | yes      | Short description                   |
| tags              | [String] | yes      | Categorization tags                 |
| relativePath      | String   | no       | Path relative to Documents/         |
| linkedDiagnosisId | UUID     | yes      | FK → Diagnosis.id (optional link)   |

**Source**: `Models/General/MediaFile.swift`

**FileType enum**:

| Value   | Extensions              |
|---------|-------------------------|
| image   | jpg, jpeg, png, heic    |
| video   | mp4, mov, avi           |
| pdf     | pdf                     |
| audio   | m4a, mp3                |
| csv     | csv                     |
| unknown | everything else         |

**DWH mapping**: Each MediaFile becomes a row in `fact_attachment`:

| Fact column      | Source              | Type     |
|------------------|---------------------|----------|
| attachment_key   | generated           | BIGSERIAL|
| date_key         | date(date) → dim_calendar | INTEGER |
| device_key       | sync device         | INTEGER  |
| entity_key       | parent entity       | INTEGER  |
| filename         | MediaFile.filename  | TEXT     |
| content_type     | derived from fileType | TEXT   |
| storage_path     | server-side path    | TEXT     |
| relative_path    | MediaFile.relativePath | TEXT  |
| linked_diagnosis_id | MediaFile.linkedDiagnosisId | UUID |

---

### 4.7 Finding (transactional — clinical assessment)

A clinical finding/assessment recorded during a therapy. Contains the same
clinical status entries as TherapySessionDocumentation (§4.12), providing a
snapshot of the patient's condition at a point in time.

| Column          | Type                         | Nullable | Description                    |
|-----------------|------------------------------|----------|--------------------------------|
| id              | UUID                         | no       | PK — unique finding identifier |
| therapistId     | UUID                         | yes      | FK → Therapists.id             |
| patientId       | UUID                         | no       | FK → Patient.id                |
| title           | String                       | no       | Finding title                  |
| date            | Date                         | no       | Assessment date                |
| notes           | String                       | yes      | Free text notes                |
| mediaFiles      | [MediaFile]                  | no       | Attached files                 |
| assessments     | [AssessmentStatusEntry]      | no       | Assessment results (see §4.15) |
| joints          | [JointStatusEntry]           | no       | Joint measurements (see §4.15) |
| muscles         | [MuscleStatusEntry]          | no       | Muscle assessments (see §4.15) |
| tissues         | [TissueStatusEntry]          | no       | Tissue assessments (see §4.15) |
| otherAnomalies  | [OtherAnomalieStatusEntry]   | no       | Other findings (see §4.15)     |
| symptoms        | [SymptomsStatusEntry]        | no       | Symptom entries (see §4.15)    |

**Source**: `Models/Therapy/Finding/Finding.swift`

---

### 4.8 PreTreatmentDocumentation (transactional — consent)

Documentation of the pre-treatment consultation and informed consent. One per
therapy, capturing goals discussed, risks explained, and patient understanding.

| Column             | Type      | Nullable | Description                            |
|--------------------|-----------|----------|----------------------------------------|
| id                 | UUID      | no       | PK — unique identifier                 |
| date               | Date      | no       | Date of pre-treatment consultation     |
| therapistId        | UUID      | no       | FK → Therapists.id — who conducted it  |
| therapyGoals       | String    | no       | Goals discussed with patient           |
| expectedOutcomes   | String    | yes      | Expected outcomes                      |
| topicsDiscussed    | [String]  | no       | List of topics covered                 |
| patientQuestions   | String    | yes      | Questions the patient asked            |
| answersProvided    | String    | yes      | Therapist's answers                    |
| risksDiscussed     | Bool      | no       | Were risks discussed?                  |
| patientUnderstood  | Bool      | no       | Did patient confirm understanding?     |
| contractGiven      | Bool      | no       | Was a contract provided?               |
| contractDate       | Date      | yes      | Date of contract signing               |
| contractLocation   | String    | yes      | Location of signing                    |
| signatureFile      | MediaFile | yes      | Patient signature image                |
| additionalNotes    | String    | yes      | Additional notes                       |

**Source**: `Models/Therapy/PreTreatmentDocumentation/PreTreatmentDocumentation.swift`

---

### 4.9 Exercise (transactional)

An exercise prescribed to a patient as part of a therapy. Can have media
attachments (images, videos) demonstrating the exercise.

| Column       | Type            | Nullable | Description                          |
|--------------|-----------------|----------|--------------------------------------|
| id           | UUID            | no       | PK — unique exercise identifier      |
| title        | String          | no       | Exercise name                        |
| description  | String          | no       | Instructions/description             |
| assignedDate | Date            | no       | When the exercise was prescribed     |
| startDate    | Date            | yes      | When to start performing             |
| endDate      | Date            | yes      | When to stop performing              |
| mediaFiles   | [MediaFile]     | no       | Demo images/videos                   |
| repetitions  | Int             | yes      | Number of repetitions                |
| sets         | Int             | yes      | Number of sets                       |
| holdDuration | TimeInterval    | yes      | Hold time in seconds (static)        |
| restDuration | TimeInterval    | yes      | Rest between sets in seconds         |
| tags         | [String]        | yes      | Tags (e.g., "Coordination", "Leg")  |
| therapistId  | UUID            | no       | FK → Therapists.id                   |

**Source**: `Models/Therapy/Exercise/Exercise.swift`

---

### 4.10 TherapyPlan (transactional)

A treatment plan within a therapy, linking a diagnosis to a series of
scheduled sessions. Contains the session schedule (TreatmentSessions) and
their clinical documentation (TherapySessionDocumentation).

| Column              | Type                            | Nullable | Description                        |
|---------------------|---------------------------------|----------|------------------------------------|
| id                  | UUID                            | no       | PK — unique plan identifier        |
| diagnosisId         | UUID                            | yes      | FK → Diagnosis.id                  |
| therapistId         | UUID                            | yes      | FK → Therapists.id                 |
| title               | String                          | yes      | Plan title (propagated to sessions)|
| treatmentServiceIds | [UUID]                          | no       | FK[] → TreatmentService.internalId |
| frequency           | TherapyFrequency                | yes      | Session frequency (enum)           |
| weekdays            | [Weekday]                       | yes      | Preferred weekdays                 |
| preferredTimeOfDay  | TimeOfDay                       | yes      | Preferred time slot (enum)         |
| startDate           | Date                            | yes      | Plan start date                    |
| numberOfSessions    | Int                             | no       | Total planned sessions             |
| treatmentSessions   | [TreatmentSessions]             | no       | Scheduled sessions (see §4.11)     |
| sessionDocs         | [TherapySessionDocumentation]   | no       | Session docs (see §4.12)           |
| addressId           | UUID                            | yes      | FK → LabeledValue\<Address\>.id    |
| isCompleted         | Bool                            | no       | Plan completed?                    |

**Source**: `Models/Therapy/TherapyPlan.swift`

#### TherapyFrequency (dimensional enum)

| Value            | rawValue          | intervalInDays | Description          |
|------------------|-------------------|----------------|----------------------|
| daily            | "daily"           | 1              | Daily sessions       |
| multiplePerWeek  | "multiplePerWeek" | 2              | Multiple per week    |
| weekly           | "weekly"          | 7              | Weekly sessions      |
| biweekly         | "biweekly"        | 14             | Every two weeks      |

#### TimeOfDay (dimensional enum)

| Value     | rawValue    | Time range     | Description |
|-----------|-------------|----------------|-------------|
| morning   | "morning"   | 08:00 – 12:00  | Morning     |
| afternoon | "afternoon" | 12:00 – 16:00  | Afternoon   |
| evening   | "evening"   | 16:00 – 20:00  | Evening     |

#### Weekday (dimensional enum)

| Value     | rawValue (Int) | Description |
|-----------|----------------|-------------|
| monday    | 1              | Monday      |
| tuesday   | 2              | Tuesday     |
| wednesday | 3              | Wednesday   |
| thursday  | 4              | Thursday    |
| friday    | 5              | Friday      |
| saturday  | 6              | Saturday    |
| sunday    | 7              | Sunday      |

---

### 4.11 TreatmentSessions (transactional — appointments)

An individual treatment session/appointment. The core scheduling and workflow
entity. Has a lifecycle: draft → planned → scheduled → done → invoiced → paid.

| Column               | Type                      | Nullable | Description                             |
|----------------------|---------------------------|----------|-----------------------------------------|
| id                   | UUID                      | no       | PK — unique session identifier          |
| patientId            | UUID                      | yes      | FK → Patient.id (may be resolved later) |
| date                 | Date                      | no       | Session date                            |
| startTime            | Date                      | no       | Start time                              |
| endTime              | Date                      | no       | End time                                |
| address              | Address                   | no       | Session location (embedded)             |
| title                | String                    | no       | Session title (from TherapyPlan)        |
| draft                | Bool                      | no       | Status flag                             |
| isPlanned            | Bool                      | no       | Status flag                             |
| isScheduled          | Bool                      | no       | Status flag                             |
| isDone               | Bool                      | no       | Status flag                             |
| isInvoiced           | Bool                      | no       | Status flag                             |
| isPaid               | Bool                      | no       | Status flag                             |
| treatmentServiceIds  | [UUID]                    | no       | FK[] → TreatmentService.internalId      |
| therapistId          | UUID                      | no       | FK → Therapists.id                      |
| reevaluationEntryIds | [ReevaluationReferences]  | no       | References to reevaluation findings     |
| notes                | String                    | yes      | Session notes                           |
| icsUid               | String                    | yes      | ICS calendar event UID                  |
| localCalendarEventId | String                    | yes      | iOS Calendar.app event ID               |
| icsSequence          | Int                       | yes      | ICS sequence number for updates         |
| serialNumber         | Serial                    | yes      | Position in plan (e.g., 3/10)           |

**Source**: `Models/Therapy/TreatmentSessions/TreatmentSessions.swift`

**Computed**: `duration = endTime - startTime`

**Status lifecycle**: Exactly one status flag is true at a time. The
`currentStatus` computed property checks flags in priority order:
isDone > isInvoiced > isScheduled > isPlanned > draft > isPaid.

#### ReevaluationReferences (embedded, no own ID)

Cross-references to clinical findings used for reevaluation comparison.

| Column        | Type   | Nullable | Description                    |
|---------------|--------|----------|--------------------------------|
| assessmentIds | [UUID] | no       | FK[] → AssessmentStatusEntry   |
| jointIds      | [UUID] | no       | FK[] → JointStatusEntry        |
| muscleIds     | [UUID] | no       | FK[] → MuscleStatusEntry       |
| tissueIds     | [UUID] | no       | FK[] → TissueStatusEntry       |
| anomalyIds    | [UUID] | no       | FK[] → OtherAnomalieStatusEntry|
| symptomIds    | [UUID] | no       | FK[] → SymptomsStatusEntry     |

**Source**: `Models/Therapy/TreatmentSessions/ReevaluationReferences.swift`

#### DWH mapping: fact_session

| Fact column       | Source                      | Type          |
|-------------------|-----------------------------|---------------|
| session_key       | generated                   | BIGSERIAL     |
| date_key          | date(date) → dim_calendar   | INTEGER       |
| patient_key       | patientId → dim_patient     | INTEGER       |
| therapist_key     | therapistId → dim_therapist | INTEGER       |
| therapy_plan_key  | → parent TherapyPlan        | INTEGER       |
| device_key        | sync device → dim_device    | INTEGER       |
| session_id        | TreatmentSessions.id        | UUID          |
| start_time        | TreatmentSessions.startTime | TIMESTAMPTZ   |
| end_time          | TreatmentSessions.endTime   | TIMESTAMPTZ   |
| duration_minutes  | computed                    | INTEGER       |
| status            | currentStatus               | TEXT          |
| title             | TreatmentSessions.title     | TEXT          |
| serial_current    | serialNumber.current        | INTEGER       |
| serial_total      | serialNumber.total          | INTEGER       |
| notes             | TreatmentSessions.notes     | TEXT          |
| address           | embedded JSON               | JSONB         |

---

### 4.12 TherapySessionDocumentation (transactional — clinical documentation)

Clinical documentation for a treatment session. Records what was found,
what was treated, and with which services. Links back to the session it
documents.

| Column            | Type                         | Nullable | Description                      |
|-------------------|------------------------------|----------|----------------------------------|
| id                | UUID                         | no       | PK — unique doc identifier       |
| sessionId         | UUID                         | no       | FK → TreatmentSessions.id        |
| notes             | String                       | no       | Session notes                    |
| assessments       | [AssessmentStatusEntry]      | no       | Assessment results (see §4.15)   |
| joints            | [JointStatusEntry]           | no       | Joint measurements (see §4.15)   |
| muscles           | [MuscleStatusEntry]          | no       | Muscle assessments (see §4.15)   |
| tissues           | [TissueStatusEntry]          | no       | Tissue assessments (see §4.15)   |
| otherAnomalies    | [OtherAnomalieStatusEntry]   | no       | Other findings (see §4.15)       |
| symptoms          | [SymptomsStatusEntry]        | no       | Symptom entries (see §4.15)      |
| appliedTreatments | [AppliedTreatment]           | no       | Services applied (see §4.13)     |
| createdAt         | Date                         | no       | Creation timestamp               |
| updatedAt         | Date                         | no       | Last update timestamp            |
| therapistId       | UUID                         | yes      | FK → Therapists.id               |
| status            | DocStatus                    | no       | draft / finalized                |

**Source**: `Models/Therapy/Session/TherapySessionDocumentation.swift`

**DocStatus enum**: `draft` | `finalized`

---

### 4.13 AppliedTreatment (transactional detail)

Records which treatment service was applied and how many units, as part of
a session documentation.

| Column    | Type | Nullable | Description                                |
|-----------|------|----------|--------------------------------------------|
| id        | UUID | no       | PK — unique identifier                     |
| serviceId | UUID | no       | FK → TreatmentService.internalId (§2.9.3)  |
| amount    | Int  | no       | Number of units applied                    |

**Source**: `Models/Therapy/Session/AppliedTreatment.swift`

---

### 4.14 DischargeReport (transactional + PDF)

The final report when a therapy is completed. Summarizes the therapy,
outcomes, and recommendations. Can include media attachments and a signature.

| Column              | Type        | Nullable | Description                          |
|---------------------|-------------|----------|--------------------------------------|
| id                  | UUID        | no       | PK — unique report identifier        |
| date                | Date        | no       | Report creation date                 |
| therapistId         | UUID        | no       | FK → Therapists.id                   |
| diagnosisSummary    | String      | no       | Summary of diagnosis                 |
| treatmentSummary    | String      | no       | Summary of treatment performed       |
| achievedGoals       | String      | no       | What was achieved                    |
| remainingLimitations| String      | yes      | Outstanding limitations              |
| recommendations     | String      | no       | Recommendations for future           |
| additionalNotes     | String      | yes      | Additional notes                     |
| attachedMedia       | [MediaFile] | no       | Supporting media files               |
| signatureImagePath  | String      | yes      | Path to signature image              |
| signatureDate       | Date        | yes      | Date of signing                      |
| signaturePlace      | String      | yes      | Location of signing                  |
| isFinalized         | Bool        | no       | Report finalized? (locks editing)    |
| pdfFilePath         | String      | yes      | Path to generated PDF                |

**Source**: `Models/Therapy/DischargeReport/DischargeReport.swift`

**iPad storage**: PDF stored at path indicated by `pdfFilePath`, typically
under the patient directory.

---

### 4.15 Clinical status entries (shared structure)

Both Finding (§4.7) and TherapySessionDocumentation (§4.12) use the same
set of clinical status entry types. These record detailed physiological
measurements and observations.

#### AssessmentStatusEntry

| Column       | Type      | Nullable | Description                                |
|--------------|-----------|----------|--------------------------------------------|
| id           | UUID      | no       | PK                                         |
| assessmentId | UUID      | no       | FK → Assessments parameter (§2.2)          |
| side         | BodySides | no       | left / right / bilateral                   |
| finding      | Bool      | no       | Positive finding?                          |
| description  | String    | no       | Finding description                        |
| reevaluation | Bool      | no       | Is this a reevaluation entry? (default: false) |
| timestamp    | Date      | no       | When recorded                              |

**Source**: `Models/Analysis/Assessments/AssessmentStatusEntry.swift`

#### JointStatusEntry

| Column      | Type                  | Nullable | Description                        |
|-------------|-----------------------|----------|------------------------------------|
| id          | UUID                  | no       | PK                                 |
| joint       | Joints                | no       | FK → Joints parameter (§2.6)      |
| side        | BodySides             | no       | left / right / bilateral           |
| movement    | JointMovementPattern  | no       | FK → JointMovementPatterns (§2.5)  |
| value       | JointMeasurementValue | no       | number(Double) or boolean(Bool)    |
| painQuality | PainQualities         | yes      | FK → PainQualities parameter (§2.7)|
| painLevel   | PainLevels            | yes      | Integer 0–10 (NRS scale)          |
| endFeeling  | EndFeelings           | yes      | FK → EndFeelings parameter (§2.4)  |
| notes       | String                | yes      | Additional notes                   |
| reevaluation| Bool                  | no       | Is this a reevaluation entry?      |
| timestamp   | Date                  | no       | When recorded                      |

**Source**: `Models/Analysis/Joints/JointStatusEntry.swift`

**JointMeasurementValue**: Tagged union — either `number(Double)` for ROM
degrees or `boolean(Bool)` for pass/fail tests.

#### MuscleStatusEntry

| Column      | Type          | Nullable | Description                         |
|-------------|---------------|----------|-------------------------------------|
| id          | UUID          | no       | PK                                  |
| muscleGroup | MuscleGroups  | no       | FK → MuscleGroups parameter (§2.6)  |
| side        | BodySides     | no       | left / right / bilateral            |
| tone        | MuscleTone    | no       | Tone rating (-3 to +3)             |
| mft         | Int           | no       | Manual function test grade          |
| painQuality | PainQualities | yes      | FK → PainQualities parameter (§2.7) |
| painLevel   | PainLevels    | yes      | Integer 0–10 (NRS scale)           |
| notes       | String        | yes      | Additional notes                    |
| reevaluation| Bool          | no       | Is this a reevaluation entry?       |
| timestamp   | Date          | no       | When recorded                       |

**Source**: `Models/Analysis/Muscles/MuscleStatusEntry.swift`

#### TissueStatusEntry

| Column       | Type          | Nullable | Description                          |
|--------------|---------------|----------|--------------------------------------|
| id           | UUID          | no       | PK                                   |
| tissue       | Tissues       | no       | FK → Tissues parameter (§2.8)        |
| side         | BodySides     | yes      | left / right / bilateral             |
| tissueStates | TissueStates  | yes      | FK → TissueStates parameter (§2.8)   |
| painQuality  | PainQualities | yes      | FK → PainQualities parameter (§2.7)  |
| painLevel    | PainLevels    | yes      | Integer 0–10 (NRS scale)            |
| notes        | String        | yes      | Additional notes                     |
| reevaluation | Bool          | no       | Is this a reevaluation entry?        |
| timestamp    | Date          | no       | When recorded                        |

**Source**: `Models/Analysis/Tissues/TissueStatusEntry.swift`

#### OtherAnomalieStatusEntry

| Column      | Type                       | Nullable | Description              |
|-------------|----------------------------|----------|--------------------------|
| id          | UUID                       | no       | PK                       |
| anomaly     | String                     | no       | Anomaly description      |
| bodyRegion  | BodyRegionSelectionGroup   | yes      | Body region category     |
| bodyPart    | BodyPart                   | yes      | Specific body part       |
| side        | BodySides                  | yes      | left / right / bilateral |
| anomalyPains| AnomalyPains               | yes      | Pain assessment          |
| reevaluation| Bool                       | no       | Is this a reevaluation?  |
| timestamp   | Date                       | no       | When recorded            |

**Source**: `Models/Analysis/OtherAnomalies/OtherAnomalieStatusEntry.swift`

#### SymptomsStatusEntry

| Column           | Type                       | Nullable | Description              |
|------------------|----------------------------|----------|--------------------------|
| id               | UUID                       | no       | PK                       |
| bodyRegion       | BodyRegionSelectionGroup   | yes      | Body region category     |
| bodyPart         | BodyPart                   | yes      | Specific body part       |
| side             | BodySides                  | yes      | left / right / bilateral |
| problematicAction| String                     | yes      | What action triggers it  |
| symptomPains     | SymptomPains               | yes      | Pain details             |
| sinceDate        | Date                       | yes      | When symptoms started    |
| reevaluation     | Bool                       | no       | Is this a reevaluation?  |
| timestamp        | Date                       | no       | When recorded            |

**Source**: `Models/Analysis/Symptoms/SymptomsStatusEntry.swift`

#### DWH note on clinical status entries

These entries are the core clinical measurement data. In the current warehouse,
they would be buried inside JSONB on `fact_transaction`. For proper analytics,
they need dedicated fact tables or at minimum properly structured JSONB with
known schemas.

**Proposed approach**: Store clinical status entries as rows in a
`fact_clinical_observation` table with a discriminated `observation_type`
column:

| Fact column        | Source              | Type          |
|--------------------|---------------------|---------------|
| observation_key    | generated           | BIGSERIAL     |
| date_key           | date(timestamp)     | INTEGER       |
| patient_key        | → dim_patient       | INTEGER       |
| therapist_key      | → dim_therapist     | INTEGER       |
| parent_type        | "finding" or "session_doc" | TEXT   |
| parent_id          | Finding.id or SessionDoc.id | UUID  |
| observation_type   | "assessment", "joint", "muscle", "tissue", "anomaly", "symptom" | TEXT |
| parameter_key      | assessmentId/joint/muscleGroup/tissue → dim_parameter | INTEGER |
| side               | BodySides           | TEXT          |
| value_numeric      | ROM degrees, MFT grade, pain level, muscle tone | NUMERIC |
| value_boolean      | finding (bool), pass/fail | BOOLEAN |
| value_text         | description, notes  | TEXT          |
| is_reevaluation    | reevaluation flag   | BOOLEAN       |

This enables:
- Track ROM changes over time: `WHERE observation_type = 'joint' AND parameter_key = X ORDER BY date_key`
- Compare findings vs session docs: `GROUP BY parent_type`
- Reevaluation delta: `WHERE is_reevaluation = true` joined to original
- Pain trends: `WHERE value_numeric IS NOT NULL AND observation_type IN ('joint', 'muscle', 'tissue')`

---

### 4.16 Relationships (complete patient graph)

```
Patient
├── .id                          PK
├── .therapistId (via therapy)   → Therapists.id (§2.9.2)
├── .addresses[].id              embedded (no FK)
├── .emergencyContacts[].id      embedded (no FK)
├── .anamnesis.therapistId       → Therapists.id
│
├── therapies[]
│   ├── .id                      PK
│   ├── .patientId               → Patient.id
│   ├── .therapistId             → Therapists.id
│   ├── .billingPeriod           BillingPeriod enum
│   │
│   ├── diagnoses[]
│   │   ├── .id                  PK
│   │   ├── .therapyId           → Therapy.id
│   │   ├── .source.specialty    → Specialties (§2.7)
│   │   ├── .treatments[].treatmentService → TreatmentService.internalId (§2.9.3)
│   │   └── .mediaFiles[]        → file system (JPG/images)
│   │
│   ├── findings[]
│   │   ├── .id                  PK
│   │   ├── .therapistId         → Therapists.id
│   │   ├── .patientId           → Patient.id
│   │   ├── .assessments[].assessmentId → Assessments (§2.2)
│   │   ├── .joints[].joint      → Joints (§2.6)
│   │   ├── .joints[].movement   → JointMovementPatterns (§2.5)
│   │   ├── .joints[].painQuality → PainQualities (§2.7)
│   │   ├── .joints[].endFeeling → EndFeelings (§2.4)
│   │   ├── .muscles[].muscleGroup → MuscleGroups (§2.6)
│   │   ├── .muscles[].painQuality → PainQualities (§2.7)
│   │   ├── .tissues[].tissue    → Tissues (§2.8)
│   │   ├── .tissues[].tissueStates → TissueStates (§2.8)
│   │   ├── .tissues[].painQuality → PainQualities (§2.7)
│   │   └── .mediaFiles[]        → file system
│   │
│   ├── preTreatment
│   │   ├── .id                  PK
│   │   ├── .therapistId         → Therapists.id
│   │   └── .signatureFile       → file system (MediaFile)
│   │
│   ├── exercises[]
│   │   ├── .id                  PK
│   │   ├── .therapistId         → Therapists.id
│   │   └── .mediaFiles[]        → file system
│   │
│   ├── therapyPlans[]
│   │   ├── .id                  PK
│   │   ├── .diagnosisId         → Diagnosis.id
│   │   ├── .therapistId         → Therapists.id
│   │   ├── .treatmentServiceIds[] → TreatmentService.internalId (§2.9.3)
│   │   ├── .addressId           → Patient.addresses[].id
│   │   ├── .frequency           TherapyFrequency enum
│   │   ├── .preferredTimeOfDay  TimeOfDay enum
│   │   ├── .weekdays[]          Weekday enum
│   │   │
│   │   ├── treatmentSessions[]
│   │   │   ├── .id              PK
│   │   │   ├── .patientId       → Patient.id
│   │   │   ├── .therapistId     → Therapists.id
│   │   │   ├── .treatmentServiceIds[] → TreatmentService.internalId
│   │   │   └── .reevaluationEntryIds[] → clinical status entries
│   │   │
│   │   └── sessionDocs[]
│   │       ├── .id              PK
│   │       ├── .sessionId       → TreatmentSessions.id
│   │       ├── .therapistId     → Therapists.id
│   │       ├── .appliedTreatments[].serviceId → TreatmentService.internalId
│   │       └── (same clinical status entries as Finding)
│   │
│   ├── dischargeReport
│   │   ├── .id                  PK
│   │   ├── .therapistId         → Therapists.id
│   │   ├── .attachedMedia[]     → file system
│   │   └── .pdfFilePath         → file system (PDF)
│   │
│   └── invoices[]               → see §3
│
└── therapy_{therapyId}/
    ├── agreement.pdf            TherapyAgreement (§4.4)
    └── contract.pdf             TreatmentContract (§4.3)
```

### 4.17 Known issues in current sync implementation

1. **Entire patient as one entity**: `EntityExtractor` sends the complete
   Patient struct (with all nested therapies, diagnoses, plans, sessions,
   findings, etc.) as a single `entity_type = "patient"` with everything
   dumped into `data: JSONB`. This creates a massive JSON blob per patient
   with no ability to query individual sessions, findings, or diagnoses.

2. **No therapy-level entities**: Therapies, diagnoses, plans, sessions, and
   findings are not synced as individual entities. The warehouse has no way to
   create separate fact rows for each session or finding.

3. **Clinical status entries lost**: The most analytically valuable data
   (joint ROM measurements, muscle assessments, pain levels over time) is
   buried 6 levels deep in JSONB. No current warehouse table can surface it.

4. **Attachment pipeline stubbed**: Media files (diagnosis images, exercise
   videos, signatures, discharge PDFs, therapy agreements, treatment contracts)
   are never uploaded. `attachments: []` is hardcoded in the push payload.

5. **Status flags instead of enum**: TreatmentSessions uses 6 boolean flags
   (`draft`, `isPlanned`, `isScheduled`, `isDone`, `isInvoiced`, `isPaid`)
   instead of a single status enum. Only one should be true at a time, but
   the data model doesn't enforce this. The warehouse should store a single
   `status` TEXT column derived from `currentStatus`.

6. **DiagnosisSource.id is String**: Uses `UUID().uuidString` (a String) rather
   than UUID type. Inconsistent with all other entities that use UUID directly.

7. **Therapist reference scattered**: `therapistId` appears on Patient (none),
   Therapy, TherapyPlan, TreatmentSessions, Finding, PreTreatmentDocumentation,
   DischargeReport, Exercise, and TherapySessionDocumentation. The "active"
   therapist can differ per level — the warehouse should preserve each level's
   therapist assignment independently.

---

## 5. ChangeLog (audit trail)

The iPad app tracks field-level changes to patient records. Every time a
patient is saved, the app computes a JSON diff between the old and new state,
producing a list of `FieldChange` entries that are persisted as timestamped
change log files.

**iPad storage**: One file per save operation at
`Documents/patients/{patientId}/changes/{yyyyMMdd-HHmmss}.json`

This is the **only source** of field-level change history. The sync pipeline
currently does not transmit change logs to the server.

---

### 5.1 ChangeLog (file envelope)

| Column  | Type          | Nullable | Description                  |
|---------|---------------|----------|------------------------------|
| changes | [ChangeEntry] | no       | List of field changes        |

**Source**: `Models/Patient/ChangeLog.swift`

### 5.2 ChangeEntry (individual field change)

| Column      | Type   | Nullable | Description                                          |
|-------------|--------|----------|------------------------------------------------------|
| path        | String | no       | JSON Pointer path (e.g., "/firstname", "/therapies/0/diagnoses/2/title") |
| oldValue    | String | no       | Previous value as string representation              |
| newValue    | String | no       | New value as string representation                   |
| therapistId | UUID   | yes      | FK → Therapists.id — who made the change             |

**Source**: `Models/Patient/ChangeLog.swift`

### 5.3 FieldChange (in-memory representation)

Used during diff computation before serialization to ChangeEntry.

| Column      | Type      | Nullable | Description                    |
|-------------|-----------|----------|--------------------------------|
| path        | String    | no       | JSON Pointer path              |
| oldValue    | JSONValue | no       | Old value (typed)              |
| newValue    | JSONValue | no       | New value (typed)              |
| therapistId | UUID      | yes      | FK → Therapists.id             |

**Source**: `Models/Patient/FieldChange.swift`

**JSONValue enum** — type-safe JSON representation:

| Value            | Description          |
|------------------|----------------------|
| null             | JSON null            |
| bool(Bool)       | true / false         |
| number(Double)   | Numeric value        |
| string(String)   | String value         |
| array([JSONValue])| JSON array           |
| object([String: JSONValue]) | JSON object |

### 5.4 Change detection pipeline

The change detection pipeline in PatientStore works as follows:

1. **Save triggers diff**: `updatePatientAsync()` → `diffPatient(old:new:therapistId:)`
2. **Recursive JSON diff**: Both Patient objects are serialized to JSON, then
   compared recursively. Changed leaf values produce a `FieldChange` entry.
3. **JSON Pointer paths**: Follow RFC 6901 — `/therapies/0/diagnoses/2/title`
   means "the title of the 3rd diagnosis in the 1st therapy". Tilde escaping:
   `~0` for `~`, `~1` for `/`.
4. **Persist to disk**: Changes serialized as `ChangeLog` and written to
   `patients/{patientId}/changes/{timestamp}.json`
5. **Trigger sync queue**: `PatientStore.onPatientChanged` callback fires,
   which invokes `ChangeDetector.detectChanges()` to produce `QueuedChange`
   entries for the outbound sync queue.

### 5.5 What change logs capture

The path-based diff system can detect changes to **every field** in the
patient structure:

| Path pattern                                          | What changed                         |
|-------------------------------------------------------|--------------------------------------|
| `/firstname`                                          | Patient name changed                 |
| `/insuranceStatus`                                    | Insurance type changed               |
| `/addresses/0/value/city`                             | City in first address changed        |
| `/anamnesis/medicalHistory/allergies`                 | Allergy list changed                 |
| `/therapies/0/title`                                  | First therapy title changed          |
| `/therapies/0/diagnoses/1/title`                      | Diagnosis title changed              |
| `/therapies/0/therapyPlans/0/treatmentSessions/3/isDone` | Session status changed            |
| `/therapies/0/findings/0/joints/2/value`              | Joint ROM measurement changed        |
| `/paymentBehavior`                                    | Payment behavior rating changed      |
| `/dunningLevel`                                       | Dunning level changed                |

### 5.6 Known issues with change logs

1. **Not synced to server**: Change log files stay on the iPad. The sync
   pipeline only sends the current state of entities, not the history of
   changes. The server has no field-level audit trail.

2. **No change log for parameters**: Only patient data is diffed. Changes to
   practiceInfo, treatment services, or reference data are not tracked.

3. **No change log for availability**: Therapist availability changes are
   queued for sync but not diffed at field level.

4. **Array index instability**: Paths use array indices (`/therapies/0`),
   which shift when items are reordered, inserted, or deleted. A therapy
   moving from position 0 to position 1 would appear as changes to both
   `/therapies/0` and `/therapies/1` — making longitudinal analysis fragile.

5. **String-only values**: `ChangeEntry` stores both oldValue and newValue
   as String, losing type information. The in-memory `FieldChange` has typed
   `JSONValue`, but this is lost during serialization.

6. **Timestamp is filename, not field**: The change timestamp comes from the
   filename (`yyyyMMdd-HHmmss`), not from a field in the JSON payload. Second
   precision only — multiple saves in the same second would overwrite.

### 5.7 DWH mapping: fact_change_log

To make the warehouse the single source of truth, change logs must be synced
and stored. Proposed approach:

#### Option A: Structured fact table (recommended)

| Fact column       | Source                     | Type          |
|-------------------|----------------------------|---------------|
| change_key        | generated                  | BIGSERIAL     |
| date_key          | date(timestamp) → dim_calendar | INTEGER   |
| patient_key       | patientId → dim_patient    | INTEGER       |
| therapist_key     | therapistId → dim_therapist| INTEGER       |
| device_key        | sync device → dim_device   | INTEGER       |
| changed_at        | filename timestamp         | TIMESTAMPTZ   |
| field_path        | ChangeEntry.path           | TEXT          |
| old_value         | ChangeEntry.oldValue       | TEXT          |
| new_value         | ChangeEntry.newValue       | TEXT          |
| entity_type       | derived from path          | TEXT          |
| entity_id         | resolved from path         | UUID          |

**Path parsing** to derive entity context:

| Path prefix                              | entity_type          | entity_id source       |
|------------------------------------------|----------------------|------------------------|
| `/firstname`, `/lastname`, `/sex`, ...   | patient              | patientId              |
| `/therapies/{n}/...`                     | therapy              | therapies[n].id        |
| `/therapies/{n}/diagnoses/{m}/...`       | diagnosis            | diagnoses[m].id        |
| `/therapies/{n}/therapyPlans/{m}/treatmentSessions/{k}/...` | session | treatmentSessions[k].id |
| `/therapies/{n}/findings/{m}/...`        | finding              | findings[m].id         |

This enables:
- "Show all changes to patient X in the last 30 days"
- "Which therapist changed this field?"
- "How many times was this patient's insurance status changed?"
- "Show the history of session status changes for this therapy plan"
- "Track when dunning levels were escalated"

#### Option B: Raw change log storage

Store the complete change log files as JSONB in a simpler table, parse at
query time. Simpler ETL but harder analytics.

---

## 6. Sync state and conflict audit (operational data)

Besides the domain data, several operational structures must flow into the
warehouse for completeness.

### 6.1 Outbound queue (iPad-side)

Tracks queued changes waiting to be pushed to the server.

**QueuedChange**:

| Column       | Type             | Nullable | Description                           |
|--------------|------------------|----------|---------------------------------------|
| id           | UUID             | no       | PK — unique change ID                 |
| entityType   | SyncEntityType   | no       | Entity type (patient, session, etc.)  |
| entityId     | UUID             | no       | Which entity changed                  |
| patientId    | UUID             | yes      | Associated patient (nil for availability) |
| dataCategory | SyncDataCategory | no       | masterData / transactionalData / parameter |
| data         | [String: Any]    | no       | Full entity data as JSON              |
| operation    | String           | no       | "create" or "update"                  |
| queuedAt     | Date             | no       | When change was queued                |

**Source**: `Views/Sync/Queue/OutboundQueue.swift`

**iPad storage**: `Documents/sync/outbound_queue.json`

**DWH note**: The outbound queue is transient — entries are removed after
successful sync. The server already captures the result via `sync_operation`
and `sync_inbound`. No warehouse table needed for queue entries themselves,
but the `operation` field (create vs update) is valuable metadata that should
be preserved in `sync_inbound`.

### 6.2 Conflict log (iPad-side)

Records sync conflicts resolved during push operations.

**ConflictLogEntry**:

| Column      | Type             | Nullable | Description                    |
|-------------|------------------|----------|--------------------------------|
| id          | UUID             | no       | PK                             |
| date        | Date             | no       | When conflict occurred         |
| entityType  | SyncEntityType   | no       | Entity type involved           |
| entityId    | UUID             | no       | Which entity conflicted        |
| resolution  | String           | no       | "client_wins" or "server_wins" |
| serverData  | [String: Any]    | yes      | Server's version of entity     |
| clientData  | [String: Any]    | yes      | Client's version of entity     |

**Source**: `Views/Sync/Models/SyncState.swift`

**iPad storage**: `Documents/sync/conflict_log.json` (last 100 entries)

**DWH note**: The server-side `sync_conflict` table (staging schema) already
records this from the server's perspective. The iPad-side conflict log
provides the client's view. Both should be correlated in the warehouse via
`entity_id` + timestamp.

### 6.3 Entity version tracker (iPad-side)

Tracks the last known server version for each synced entity.

**TrackedEntity**:

| Column        | Type           | Nullable | Description                    |
|---------------|----------------|----------|--------------------------------|
| entityType    | SyncEntityType | no       | Entity type                    |
| serverVersion | Int            | no       | Last known server version      |
| lastSyncedAt  | Date           | no       | When last synced               |

**Source**: `Views/Sync/Serialization/EntityVersionTracker.swift`

**iPad storage**: `Documents/sync/entity_versions.json`

**DWH note**: Version tracking metadata. The server already maintains
`sync_entity.version` and `sync_device_state.last_pull_version`. No separate
warehouse table needed — this is operational state used for sync protocol.

---

## 7. Data completeness analysis

This section analyzes what data exists in the source systems vs what the
warehouse currently captures, identifying every gap that must be closed for
the DWH to be the single source of truth.

### 7.1 Current data flow

```
iPad App                          Server (nexus-core)
─────────                         ───────────────────
patient.json ──┐
               ├── EntityExtractor ──→ SyncPushChange ──→ sync_inbound
changes/*.json │   (flattens)          (per entity)       (raw staging)
               │                                              │
               │                                              ▼
               │                                         sync_entity
               │                                         (current state,
               │                                          version tracked)
               │                                              │
               │                                         ┌────┴────┐
               │                                         ▼         ▼
               │                                    dim_entity   fact_transaction
               │                                    (SCD2,       (catch-all,
               │                                     master      JSONB data)
               │                                     only)
               │
availability/ ─┘                  sync_conflict (conflict audit)
                                  sync_operation (push/pull stats)
                                  sync_attachment (metadata only — no files)
```

### 7.2 Data loss inventory

| Source data                    | Currently synced? | Currently in DWH? | Gap                                        |
|--------------------------------|-------------------|--------------------|---------------------------------------------|
| Patient demographics           | Yes (as JSONB)    | dim_entity (JSONB) | No typed columns, buried in JSON            |
| Patient addresses              | Yes (embedded)    | dim_entity.data    | Not queryable without JSONB extraction      |
| Patient anamnesis              | Yes (embedded)    | dim_entity.data    | Deep nesting, not queryable                 |
| Therapy                        | Partial (flat)    | fact_transaction   | Parent-child links lost                     |
| Diagnosis                      | Partial (flat)    | fact_transaction   | Source doctor info lost in JSONB            |
| DiagnosisSource                | Embedded in diag  | Lost in JSONB      | No dim_doctor table                         |
| DiagnosisTreatments            | Embedded          | Lost in JSONB      | Prescribed treatments not queryable         |
| Finding                        | Partial (flat)    | fact_transaction   | Clinical entries lost in JSONB              |
| PreTreatmentDocumentation      | Partial (flat)    | fact_transaction   | Consent data lost in JSONB                  |
| TherapyPlan                    | Partial (flat)    | fact_transaction   | Plan-session link lost                      |
| TreatmentSessions              | Partial (flat)    | fact_transaction   | Session facts not individual rows           |
| TherapySessionDocumentation    | Partial (flat)    | fact_transaction   | Clinical entries lost in JSONB              |
| AppliedTreatment               | Embedded          | Lost in JSONB      | Service usage not queryable                 |
| Exercise                       | Partial (flat)    | fact_transaction   | Exercise details lost in JSONB              |
| DischargeReport                | Partial (flat)    | fact_transaction   | Report content lost in JSONB                |
| Invoice header                 | Partial (flat)    | fact_transaction   | No fact_invoice table                       |
| Invoice line items             | Embedded          | Lost in JSONB      | No fact_invoice_item table                  |
| Clinical status entries        | Embedded          | Lost in JSONB      | No fact_clinical_observation                |
| **Change logs**                | **NOT synced**    | **Not in DWH**     | **No field-level audit trail on server**    |
| **Media files (JPG/PDF)**      | **NOT uploaded**  | **Not in DWH**     | **Attachment pipeline stubbed**             |
| **Therapy agreements (PDF)**   | **NOT uploaded**  | **Not in DWH**     | **File never sent**                         |
| **Treatment contracts (PDF)**  | **NOT uploaded**  | **Not in DWH**     | **File never sent**                         |
| **Discharge report PDFs**      | **NOT uploaded**  | **Not in DWH**     | **File never sent**                         |
| AvailabilityEntry              | Yes (flat)        | fact_transaction   | No dedicated availability fact              |
| Parameters (16 types)          | Yes (full)        | Not in DWH         | No dimension tables for parameters          |
| PracticeInfo                   | Yes (full)        | Not in DWH         | No dim_practice                             |
| Therapists                     | Embedded in PI    | Not in DWH         | No dim_therapist                            |
| TreatmentService               | Embedded in PI    | Not in DWH         | No dim_service                              |
| Sync conflicts                 | Yes (server-side) | Not in DWH         | sync_conflict exists but no mart            |
| Sync operations                | Yes               | fact_sync_log      | Exists but never populated                  |

### 7.3 Requirements for single source of truth

For the DWH to be THE authoritative data store with no missing data:

#### R1: All source data must arrive at the server

| What must be synced                   | Current status | Required change                    |
|---------------------------------------|----------------|------------------------------------|
| Patient (full, with nested children)  | Partial        | Sync all sub-entities individually |
| Change logs (field-level diffs)       | Not synced     | New sync entity type               |
| Media files (JPG, PNG, PDF, video)    | Not uploaded   | Fix attachment pipeline            |
| Therapy agreement PDFs               | Not uploaded   | Include in attachment sync         |
| Treatment contract PDFs              | Not uploaded   | Include in attachment sync         |
| Discharge report PDFs                | Not uploaded   | Include in attachment sync         |

#### R2: All data must have typed warehouse tables (no JSONB catch-alls)

| Proposed table               | Source                          | Type           |
|------------------------------|---------------------------------|----------------|
| dim_patient                  | Patient demographics            | SCD Type 2     |
| dim_therapist                | Therapists from PracticeInfo    | SCD Type 2     |
| dim_practice                 | PracticeInfo (organization)     | SCD Type 2     |
| dim_service                  | TreatmentService                | SCD Type 2     |
| dim_doctor                   | DiagnosisSource (deduplicated)  | SCD Type 2     |
| dim_parameter                | All 16 parameter files          | SCD Type 1     |
| dim_device                   | Sync devices (exists)           | SCD Type 2     |
| dim_calendar                 | Date dimension (exists)         | Static         |
| dim_source                   | Data sources (exists)           | Static         |
| fact_therapy                 | Therapy case                    | Accumulating   |
| fact_diagnosis               | Diagnosis + prescribed treatments | Insert-only  |
| fact_finding                 | Finding assessments             | Insert-only    |
| fact_therapy_plan            | TherapyPlan                     | Accumulating   |
| fact_session                 | TreatmentSessions               | Accumulating   |
| fact_session_doc             | TherapySessionDocumentation     | Accumulating   |
| fact_clinical_observation    | All 6 clinical status entries   | Insert-only    |
| fact_exercise                | Prescribed exercises            | Insert-only    |
| fact_pre_treatment           | Consent documentation           | Insert-only    |
| fact_discharge               | Discharge reports               | Insert-only    |
| fact_invoice                 | Invoice header                  | Accumulating   |
| fact_invoice_item            | Invoice line items              | Insert-only    |
| fact_attachment              | All binary files (exists)       | Insert-only    |
| fact_availability            | Therapist availability          | Insert-only    |
| fact_change_log              | Field-level change audit        | Insert-only    |
| fact_sync_log                | Sync operations (exists)        | Insert-only    |
| fact_conflict                | Sync conflict resolution        | Insert-only    |

#### R3: Historical snapshots via SCD Type 2

All dimension tables with mutable data must use SCD Type 2 (valid_from /
valid_to) so the warehouse preserves the state of dimensions at any point
in time. When a patient's address changes, the old address remains queryable.
When a therapist's name changes, historical sessions still show the correct
name.

**Snapshot rules**:
- Every change to a dimension row expires the current version (set `valid_to`)
  and inserts a new version (new `valid_from`, null `valid_to`)
- Fact tables reference dimension surrogate keys (`patient_key`, not
  `patient_id`) — this locks each fact to the dimension version that was
  current when the fact occurred
- "Current" queries filter `WHERE valid_to IS NULL`
- "As of date X" queries filter `WHERE valid_from <= X AND (valid_to IS NULL OR valid_to > X)`

#### R4: No redundancy

Each piece of data should exist in exactly one warehouse table:

- Patient demographics → `dim_patient` (not also in `dim_entity`)
- Session data → `fact_session` (not also in `fact_transaction`)
- Invoice data → `fact_invoice` + `fact_invoice_item` (not also in `fact_transaction`)
- Clinical observations → `fact_clinical_observation` (not embedded in other facts)

The current `dim_entity` and `fact_transaction` tables are catch-all tables
that should be **replaced** by the typed tables above, not augmented.

#### R5: Change log as first-class data

The change log must flow through the full pipeline:

```
iPad                          Server                        Warehouse
─────                         ──────                        ─────────
changes/*.json ──→ new sync ──→ staging.sync_change_log ──→ fact_change_log
                   entity       (raw, per file)             (parsed, per field)
                   type
```

Each change log file becomes multiple rows in `fact_change_log` (one per
`ChangeEntry`). The path field is parsed to derive the affected entity type
and entity ID, enabling joins back to the corresponding fact and dimension
tables.

### 7.4 Entity extraction redesign (required)

The current `EntityExtractor` flattens the patient into coarse entity types
(`patient`, `session`, `assessment`, `invoice`) that don't match the warehouse
grain. For the DWH to receive properly structured data, the extractor must
produce **one sync entity per warehouse target table**.

**Current extraction** (6 entity types):

| SyncEntityType | What it contains                          |
|----------------|-------------------------------------------|
| patient        | Patient demographics (without therapies)  |
| session        | Therapy OR TherapyPlan OR TreatmentSession OR SessionDoc |
| assessment     | Diagnosis OR Finding OR Exercise          |
| invoice        | Invoice (header + items + aggregation)    |
| availability   | AvailabilitySlot                          |
| documentMeta   | MediaFile metadata                        |

**Required extraction** (matches warehouse tables):

| Sync entity type          | Source                          | Warehouse target          |
|---------------------------|---------------------------------|---------------------------|
| patient                   | Patient (flat, no therapies)    | dim_patient               |
| therapy                   | Therapy (flat, no children)     | fact_therapy              |
| diagnosis                 | Diagnosis (flat, no media)      | fact_diagnosis            |
| diagnosis_treatment       | DiagnosisTreatments             | fact_diagnosis (detail)   |
| diagnosis_source          | DiagnosisSource                 | dim_doctor                |
| finding                   | Finding (flat, no entries)      | fact_finding              |
| pre_treatment             | PreTreatmentDocumentation       | fact_pre_treatment        |
| exercise                  | Exercise (flat, no media)       | fact_exercise             |
| therapy_plan              | TherapyPlan (flat, no children) | fact_therapy_plan         |
| session                   | TreatmentSessions               | fact_session              |
| session_doc               | TherapySessionDocumentation     | fact_session_doc          |
| applied_treatment         | AppliedTreatment                | fact_session_doc (detail) |
| clinical_observation      | All 6 status entry types        | fact_clinical_observation |
| invoice                   | Invoice (header only)           | fact_invoice              |
| invoice_item              | InvoiceItem                     | fact_invoice_item         |
| discharge_report          | DischargeReport                 | fact_discharge            |
| availability              | AvailabilitySlot                | fact_availability         |
| media_file                | MediaFile (metadata)            | fact_attachment           |
| change_log                | ChangeLog (per file)            | fact_change_log           |

Each entity must carry its **parent references** explicitly:

| Entity               | Required parent FKs                        |
|----------------------|--------------------------------------------|
| therapy              | patientId                                  |
| diagnosis            | patientId, therapyId                       |
| finding              | patientId, therapyId                       |
| therapy_plan         | patientId, therapyId, diagnosisId          |
| session              | patientId, therapyId, therapyPlanId        |
| session_doc          | patientId, therapyId, therapyPlanId, sessionId |
| clinical_observation | patientId, parentType, parentId            |
| invoice              | patientId, therapyPlanId                   |
| invoice_item         | invoiceId, sessionId                       |
| change_log           | patientId                                  |

This preserves the complete containment hierarchy that is currently lost
during extraction.

---

<!-- Next: Section 8 will define the complete proposed star schema (tables, columns, keys, constraints) -->
