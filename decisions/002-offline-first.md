# ADR-002: Offline-First with Three-Tier Conflict Resolution

> Date: 2026-02-14 | Status: ACCEPTED

## Context

iPads will be used in field conditions (patient care) where connectivity
is intermittent or unavailable. Data entered on iPads must not be lost,
and the system must handle the case where multiple devices modify the
same record. iPads are the primary point of data collection — patient
data originates in the field.

## Decision

1. iPads operate fully offline, storing all data as local files
   (JSON, PDF, JPG) organized per patient
2. Sync occurs opportunistically when VPN connectivity is available
3. Conflict resolution uses a **three-tier strategy** based on data category:
   - Master data & transactional data: **iPad wins**
   - Parameters & reference data: **Server wins**
   - Deletions from iPads: **Always rejected**
4. All sync data is staged append-only on the server (nothing lost)

## Reasons

1. **Field reliability** — Users can work without worrying about connectivity
2. **iPad authority for patient data** — The field is where patient data is
   created. Overriding it with server data would lose clinical observations.
   "Last iPad to sync wins" for patient data is acceptable because iPads
   are typically assigned per therapist/patient.
3. **Server authority for parameters** — Treatment types, ICD codes, and
   system configuration are centrally managed. iPads should always receive
   the server's version of these.
4. **Deletion protection** — Accidental deletion on an iPad (swipe gesture,
   user error, software bug) must never propagate to the central system.
   Deletions can only be performed by an administrator on the server.
5. **File-based storage** — JSON files per patient are portable, inspectable,
   and keep all patient data (structured + attachments) in one place.
   No local database (Core Data, SQLite) dependency.
6. **Auditability** — Append-only staging and the sync_conflicts table
   preserve the complete history of what each device sent, including
   data that was overridden by conflicts.

## Consequences

- "Last iPad to sync wins" for master/transactional data — acceptable given
  per-therapist iPad assignment, but must be documented for users
- Server must maintain a global version counter for efficient pull queries
- iPad app needs a robust file-based storage layer with JSON serialization
- iPad app needs a sync queue (outbound_queue.json) that survives app restarts
- Conflict records preserved in staging for potential manual review
- Server-side soft delete (archival) replaces hard deletion
- Binary attachments (PDF, JPG) synced via separate upload/download endpoints

## Alternatives Considered

- **Server wins for everything** — Would lose field-collected patient data
  in conflicts. Unacceptable for the primary use case.
- **Client wins for everything** — Would allow iPads to override centrally
  managed parameters and reference data.
- **Last-write-wins (timestamp)** — Unreliable with clock drift across devices.
- **CRDTs** — Elegant but significantly more complex to implement. Overkill
  for a system where per-patient iPad assignment minimizes true conflicts.
- **Manual merge** — Presenting both versions to the user for every conflict
  is disruptive. Reserved as a future enhancement for critical cases.
- **Core Data / SQLite on iPad** — Adds complexity without benefit. File-based
  storage is simpler, more portable, and keeps attachments alongside data.
