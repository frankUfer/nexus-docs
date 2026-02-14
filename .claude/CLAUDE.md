# Nexus

## What this is
Project root and central documentation for the Nexus Platform — a self-hosted
data platform connecting offline-first iPads with a Linux-based data warehouse
for therapy/patient management.

Architecture docs, specs, and ADRs live here at the project root.
The iPad app (AthleticPerformance) is part of this repo.
Component repositories (nexus-core, nexus-gate, clarity) live in sub-directories
with their own git repos.

## Project structure
```
nexus/                              ← this repo (git)
├── .claude/CLAUDE.md
├── ARCHITECTURE_OVERVIEW.md
├── SYNC_PROTOCOL.md
├── DATA_DICTIONARY.md
├── SECURITY.md
├── BACKUP_STRATEGY.md
├── DEVELOPMENT_WORKFLOW.md
├── decisions/                      ← Architecture Decision Records
├── diagrams/
├── AthleticPerformance/            ← iPad app (Swift, part of this repo)
│   ├── *.xcodeproj
│   ├── *.xcworkspace
│   ├── Packages/
│   └── Sources/
├── nexus-core/                     ← separate git repo (Python, server)
├── nexus-gate/                     ← separate git repo (RPi gateway)
├── clarity/                        ← separate git repo (BI tool, Python)
└── clarity-swift/                  ← separate git repo (BI tool, Swift)
```

## Current priority: iPad app integration

The `AthleticPerformance/` directory contains an existing iPad app for
therapy/patient management, imported from a prior development phase.
It needs to be analyzed and refactored to align with the Nexus platform.

### Integration goals (in order)
1. **Analyze first, change nothing** — understand current data models,
   persistence, networking, and architecture before making any changes
2. Align data models with Nexus entity types and data categories:
   - master_data: patient demographics, contacts, profiles
   - transactional_data: sessions, assessments, events, documents
   - parameter: treatment types, lookup codes, system config
3. Migrate persistence to file-based patient storage
   (JSON/PDF/JPG per patient directory) per SYNC_PROTOCOL.md
4. Build NexusSync module inside the app for offline-first sync
   with nexus-core
5. Ensure data structures map cleanly to the warehouse schema
   in DATA_DICTIONARY.md (dim_entity, fact_transactions, etc.)
6. Respect three-tier conflict resolution:
   - Master & transactional data: iPad wins
   - Parameters: server wins
   - Deletions from iPad: always rejected

### Reference documents (read these before making app changes)
- SYNC_PROTOCOL.md — sync endpoints, payloads, conflict rules, iPad storage model
- DATA_DICTIONARY.md — warehouse schema the app's data must map to
- ARCHITECTURE_OVERVIEW.md — system topology and component roles

### Server-side status (nexus-core, already complete)
- Sync API: push, pull, upload, download endpoints
- Three-tier conflict resolution
- JWT authentication
- Staging → warehouse → mart ETL pipeline
- Dimensional model (dim_calendar, dim_device, dim_entity, dim_source)
- Fact tables (fact_transactions, fact_events, fact_attachments, fact_sync_log)
- All Alembic migrations
- 77 passing tests

The app must produce data that matches the sync API contract in SYNC_PROTOCOL.md.

## Component repositories (separate git repos, ignored by this repo)
- `nexus-core/`    — Central server: FastAPI sync API, ETL, crawlers, backup (Python)
- `nexus-gate/`    — Raspberry Pi VPN gateway: WireGuard, UFW, DNS
- `clarity/`       — BI tool, Python/PySide6 (standalone, reads from Nexus data marts)
- `clarity-swift/` — BI tool, native macOS/iPadOS (standalone)

## Domain context
Therapy/patient management platform. iPads are used in the field for patient
data collection (demographics, sessions, assessments, documents, images).
Patient data is stored as local files per patient directory on the iPad.

## Key architectural decisions
- **Three-tier sync conflict resolution:**
  - Master data & transactional data: iPad wins (field authority)
  - Parameters & reference data: Server wins (central management)
  - Deletions from iPads: Always rejected (data protection)
- iPad app is part of this repo (not a separate repo) — it is tightly
  coupled with the Nexus platform and is the primary user interface
- No Docker, no cloud — bare metal Linux with systemd
- Star schema data warehouse in PostgreSQL
- File-based storage on iPad (no Core Data, no SQLite)
- See decisions/ for full ADRs

## Infrastructure context
- Central server: Ubuntu Server 24.04 LTS (headless, Intel/Lenovo)
- VPN gateway: Raspberry Pi (headless Linux) running WireGuard
- Development: MacBook Pro (Apple Silicon) with Claude Code
- Database: PostgreSQL 16+ with staging/warehouse/mart schema pattern
- All traffic over WireGuard VPN (10.10.0.0/24)
