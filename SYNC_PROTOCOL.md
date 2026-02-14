# Nexus Sync Protocol Specification

> Last updated: 2026-02-14
> Status: DRAFT — to be finalized before implementation

## Overview

The sync protocol defines how nexus-field (iPad) exchanges data with
nexus-core (central server). It is designed for offline-first operation
where iPads may be disconnected for hours or days.

iPads are the primary point of data collection (patient care). The sync
strategy reflects this: field-collected data is authoritative, while
centrally managed parameters are server-authoritative.

## iPad Local Storage Model

Each iPad stores patient data as local files organized per patient:

```
/NexusField/
├── patients/
│   ├── {patient_uuid}/
│   │   ├── patient.json        ← master data (demographics, info)
│   │   ├── sessions/
│   │   │   ├── 2026-02-14_001.json  ← session/transaction records
│   │   │   └── 2026-02-14_002.json
│   │   ├── documents/
│   │   │   ├── intake_form.pdf
│   │   │   └── referral.pdf
│   │   ├── images/
│   │   │   ├── assessment_01.jpg
│   │   │   └── progress_02.jpg
│   │   └── sync_meta.json     ← sync state for this patient
│   └── {patient_uuid}/
│       └── ...
├── parameters/                 ← server-managed config/lookups
│   ├── treatment_types.json
│   ├── icd_codes.json
│   └── system_config.json
└── sync/
    ├── outbound_queue.json    ← pending changes to push
    ├── last_sync_state.json   ← global sync watermark
    └── conflict_log.json      ← record of resolved conflicts
```

This file-based approach ensures:
- All patient data in one place — portable and inspectable
- No local database dependency (no Core Data, no SQLite)
- Binary files (PDF, JPG) live alongside structured data
- Easy to reason about, easy to back up locally

## Principles

1. **iPad is authoritative for patient data** — Field-collected master data
   and transactional data always wins in conflicts
2. **Server is authoritative for parameters** — Centrally managed configuration,
   lookup tables, and reference data always wins
3. **Deletions never accepted from iPads** — Protects against accidental data
   loss; only the server can delete records
4. **Idempotent operations** — Replaying a sync must not create duplicates
5. **Append-only staging** — All inbound data is preserved before transformation
6. **Timestamped everything** — Client and server timestamps on every record

## Device Identity

Each iPad is registered as a device with:

```
device_id:    UUID (generated on first registration)
device_name:  Human-readable label ("nexus-field-01")
api_token:    Signed JWT, rotated periodically
wireguard_ip: 10.10.0.1XX
```

Registration is a one-time process performed by an administrator.
The device receives its API token and WireGuard configuration.

## Endpoints

Base URL: `https://nexus-server.local:8443/api/v1`

All endpoints require:
- Valid WireGuard tunnel (network layer)
- Bearer token in Authorization header (application layer)

### POST /sync/push

iPad sends local changes to the server. Changes are categorized by
`data_category` which determines conflict resolution strategy.

Delete operations from iPads are **rejected by design**. The server
preserves all data; deletions can only be performed server-side by
an administrator.

**Request:**
```json
{
  "device_id": "uuid",
  "sync_id": "uuid (unique per sync attempt)",
  "client_timestamp": "2026-02-14T10:30:00Z",
  "last_pull_version": 42,
  "changes": [
    {
      "data_category": "master_data | transactional_data | parameter",
      "entity_type": "string (e.g. 'patient', 'session', 'treatment_type')",
      "entity_id": "uuid",
      "patient_id": "uuid (nullable — for patient-scoped data)",
      "operation": "create | update",
      "version": 5,
      "data": { },
      "client_modified_at": "2026-02-14T10:28:00Z"
    }
  ],
  "attachments": [
    {
      "entity_id": "uuid (links to a change above)",
      "filename": "assessment_01.jpg",
      "content_type": "image/jpeg",
      "size_bytes": 245760,
      "checksum": "sha256:abcdef..."
    }
  ]
}
```

Attachments (PDF, JPG, etc.) are uploaded separately via
`POST /sync/upload` after a successful push, referencing the entity_id.

**Response (200):**
```json
{
  "sync_id": "uuid (echoed back)",
  "server_timestamp": "2026-02-14T10:30:01Z",
  "accepted": [
    { "entity_type": "patient", "entity_id": "uuid", "server_version": 6 }
  ],
  "conflicts": [
    {
      "entity_type": "treatment_type",
      "entity_id": "uuid",
      "data_category": "parameter",
      "conflict_type": "parameter_update",
      "server_version": 7,
      "server_data": { },
      "client_data": { },
      "resolution": "server_wins"
    }
  ],
  "rejected_deletions": [
    {
      "entity_type": "patient",
      "entity_id": "uuid",
      "reason": "deletions_not_accepted_from_devices"
    }
  ],
  "errors": [
    {
      "entity_type": "session",
      "entity_id": "uuid",
      "error": "validation_failed",
      "message": "end_time must be after start_time"
    }
  ],
  "pending_uploads": [
    { "entity_id": "uuid", "filename": "assessment_01.jpg", "upload_url": "/sync/upload/{token}" }
  ]
}
```

### GET /sync/pull

iPad requests changes since its last known version.

**Request parameters:**
```
?device_id=uuid
&since_version=42
&data_categories=master_data,transactional_data,parameter  (optional)
&entity_types=patient,session,treatment_type  (optional filter)
&limit=500  (optional, default 500)
```

**Response (200):**
```json
{
  "server_timestamp": "2026-02-14T10:31:00Z",
  "current_version": 58,
  "changes": [
    {
      "data_category": "master_data",
      "entity_type": "patient",
      "entity_id": "uuid",
      "patient_id": "uuid",
      "operation": "create | update",
      "version": 43,
      "data": { },
      "server_modified_at": "2026-02-14T09:15:00Z",
      "attachments": [
        { "filename": "referral.pdf", "download_url": "/sync/download/{token}" }
      ]
    }
  ],
  "has_more": true,
  "next_version": 53
}
```

If `has_more` is true, the client continues pulling with
`since_version=next_version` until `has_more` is false.

Pull responses never contain delete operations for master data or
transactional data. Parameter deletions (removal of a lookup value)
are communicated as updates with an `is_active: false` flag.

### POST /sync/upload

Upload binary attachment (PDF, JPG, etc.) after successful push.

**Request:** Multipart form data with the file and a reference token
from the push response's `pending_uploads`.

**Response (200):**
```json
{
  "entity_id": "uuid",
  "filename": "assessment_01.jpg",
  "stored": true,
  "checksum_verified": true
}
```

### GET /sync/download/{token}

Download an attachment referenced in a pull response.
Token is single-use and time-limited (1 hour).

### GET /sync/status

iPad checks sync health and server availability.

**Response (200):**
```json
{
  "server_timestamp": "2026-02-13T10:32:00Z",
  "current_version": 58,
  "device_last_push": "2026-02-13T10:30:01Z",
  "device_last_pull_version": 42
}
```

## Sync Flow (Client Perspective)

```
1. Check connectivity (GET /sync/status)
2. If reachable:
   a. PUSH local changes (POST /sync/push)
      - New/changed patient data and sessions → sent as master_data/transactional_data
      - Note: delete operations are NOT sent (not accepted by server)
   b. Process push response:
      - Mark accepted changes as synced
      - For parameter conflicts: apply server version locally (server wins)
      - For master/transactional conflicts: server applies iPad version (iPad wins)
      - Handle rejected deletions (log, no action needed)
      - Retry or flag errors
   c. UPLOAD attachments (POST /sync/upload for each pending file)
   d. PULL remote changes (GET /sync/pull, paginated)
      - Parameter updates: overwrite local parameter files
      - Master/transactional updates from other devices: merge into local files
   e. DOWNLOAD new attachments referenced in pull
   f. Update last_pull_version
3. If not reachable:
   - Queue changes locally in outbound_queue.json
   - Retry on next connectivity window
```

## Conflict Resolution

### Three-Tier Strategy

The sync protocol uses differentiated conflict resolution based on
**data category**, reflecting the reality that iPads are the primary
point of patient data collection.

```
┌─────────────────────────────────────────────────────────────────┐
│  Data Category          │  Conflict Winner  │  Rationale        │
├─────────────────────────┼───────────────────┼───────────────────┤
│  Master data            │  iPad wins        │  Field collection │
│  (patient demographics, │                   │  is the source of │
│   contacts, profiles)   │                   │  truth            │
├─────────────────────────┼───────────────────┼───────────────────┤
│  Transactional data     │  iPad wins        │  Sessions, notes, │
│  (sessions, notes,      │                   │  assessments are  │
│   assessments, events)  │                   │  created in the   │
│                         │                   │  field             │
├─────────────────────────┼───────────────────┼───────────────────┤
│  Parameters             │  Server wins      │  Centrally managed│
│  (treatment types, ICD  │                   │  config, lookup   │
│   codes, system config) │                   │  tables, reference│
│                         │                   │  data             │
├─────────────────────────┼───────────────────┼───────────────────┤
│  Deletions from iPad    │  REJECTED         │  Data protection: │
│  (any category)         │                   │  prevents accident│
│                         │                   │  al data loss     │
└─────────────────────────┴───────────────────┴───────────────────┘
```

### Conflict Detection

Based on entity version numbers. If the client sends an update with
version N but the server is already at version N+1, it's a conflict.

### Resolution by Category

**Master data & transactional data (iPad wins):**
1. Server detects version conflict
2. Server preserves its current version in `staging.sync_conflicts` (audit)
3. Server applies the iPad's version as the new truth
4. Server increments version and acknowledges acceptance
5. Other iPads receive the updated version on their next pull

**Parameters (server wins):**
1. Server detects version conflict
2. Server preserves the iPad's version in `staging.sync_conflicts` (audit)
3. Server keeps its own version
4. Server returns conflict response with server data
5. iPad applies server version to local parameter files

**Deletions (always rejected):**
1. Server receives a delete operation from an iPad
2. Server rejects it immediately — the record is NOT deleted
3. Server returns the rejection in `rejected_deletions`
4. iPad logs the rejection; the record remains locally
5. If deletion is truly needed, an administrator performs it server-side

### Why Deletions Are Blocked

Patient data loss is the worst-case scenario. Accidental deletions on
iPads (swipe gesture, user error, software bug) must never propagate
to the central system. If a record needs to be removed:

1. Administrator reviews the request
2. Administrator performs a soft delete on the server (sets `is_archived = true`)
3. Archived records are excluded from future pulls to iPads
4. Data is preserved in the warehouse for audit/compliance

### Multi-Device Conflict Scenario

When two iPads modify the same patient record:
1. iPad A pushes first → accepted, server version becomes N+1
2. iPad B pushes with base version N → conflict detected
3. Since this is master/transactional data → iPad B wins
4. Server preserves iPad A's version in `staging.sync_conflicts`
5. Server applies iPad B's version, becomes N+2
6. iPad A receives iPad B's version on next pull

This means "last iPad to sync wins" for patient data. This is acceptable
because:
- In practice, one iPad is assigned per patient/therapist
- The sync_conflicts table preserves all versions for audit
- True multi-device editing of the same patient is rare

## Versioning

- Global monotonic version counter (server-side sequence)
- Each entity change increments the global version
- Clients track their `last_pull_version` to know what they've seen
- This is simpler than per-entity versioning and enables efficient pull queries

## Data Categories and Entity Types

### Master Data (iPad wins in conflicts)

| Entity Type    | Description                  | Sync Direction  |
|----------------|------------------------------|-----------------|
| patient        | Patient demographics, profile| Bidirectional   |
| contact        | Related people, referrers    | Bidirectional   |

### Transactional Data (iPad wins in conflicts)

| Entity Type    | Description                  | Sync Direction  |
|----------------|------------------------------|-----------------|
| session        | Therapy sessions, notes      | iPad → Server   |
| assessment     | Assessments, measurements    | iPad → Server   |
| event          | Calendar entries             | Bidirectional   |
| document_meta  | Metadata for PDFs, images    | iPad → Server   |

### Parameters (Server wins in conflicts)

| Entity Type      | Description                  | Sync Direction  |
|------------------|------------------------------|-----------------|
| treatment_type   | Treatment/therapy type lookup| Server → iPad   |
| icd_code         | Diagnosis code reference     | Server → iPad   |
| system_config    | System-wide configuration    | Server → iPad   |
| reference_data   | Other lookup/dimensional data| Server → iPad   |

### Attachments (Binary Files)

| File Type  | Description                    | Sync Direction  |
|------------|--------------------------------|-----------------|
| PDF        | Intake forms, referrals, reports| Bidirectional  |
| JPG/PNG    | Assessment images, photos      | iPad → Server   |

Attachments follow the same conflict rules as their parent entity.

## Error Handling

| HTTP Status | Meaning                        | Client Action          |
|-------------|--------------------------------|------------------------|
| 200         | Success                        | Process response       |
| 400         | Invalid request                | Fix and retry          |
| 401         | Invalid/expired token          | Re-authenticate        |
| 409         | Sync conflict (in push response)| Apply server version  |
| 429         | Rate limited                   | Back off and retry     |
| 500         | Server error                   | Retry with backoff     |
| 503         | Server maintenance             | Retry later            |

## Security

- All sync traffic flows through WireGuard tunnel
- API token (JWT) in Authorization header
- TLS on the API endpoint (defense in depth)
- Device registration is admin-only
- Token rotation: every 30 days (configurable)
- Rate limiting: per-device, configurable

## Open Questions

- [ ] Maximum payload size per push (initial proposal: 10MB for JSON, attachments separate)
- [ ] Maximum attachment file size (initial proposal: 50MB per file)
- [ ] Attachment compression: compress on iPad before upload?
- [ ] Selective sync — can iPads subscribe to subsets of patients?
- [ ] Archival: how long before archived (soft-deleted) records are excluded from pulls?
- [ ] Multi-iPad per patient: define rules for the rare case two iPads manage the same patient
- [ ] Attachment deduplication: checksum-based to avoid re-uploading unchanged files
