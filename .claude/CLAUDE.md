# Nexus

## What this is
Project root and central documentation for the Nexus Platform — a self-hosted
data platform connecting offline-first iPads with a Linux-based data warehouse
for therapy/patient management.

Architecture docs, specs, and ADRs live here at the project root.
Component repositories live in sub-directories, each with their own git repo.

## Project structure
```
nexus/                          ← this repo (git)
├── ARCHITECTURE_OVERVIEW.md
├── SYNC_PROTOCOL.md
├── DATA_DICTIONARY.md
├── SECURITY.md
├── BACKUP_STRATEGY.md
├── DEVELOPMENT_WORKFLOW.md
├── decisions/                  ← Architecture Decision Records
├── diagrams/
├── nexus-core/                 ← separate git repo (ignored by this repo)
├── nexus-gate/                 ← separate git repo
├── nexus-field/                ← separate git repo
├── clarity/                    ← separate git repo
└── clarity-swift/              ← separate git repo
```

## Component repositories
- `nexus-core/`   — Central server: FastAPI sync API, ETL, crawlers, backup (Python, Ubuntu Server)
- `nexus-gate/`   — Raspberry Pi VPN gateway: WireGuard, UFW, DNS (Bash/Python)
- `nexus-field/`  — iPad patient data collection app (Swift, offline-first, file-based storage)
- `clarity/`      — BI tool, Python/PySide6 on Linux
- `clarity-swift/` — BI tool, native macOS/iPadOS

## Domain context
This is a therapy/patient management platform. iPads are used in the field
for patient data collection (demographics, sessions, assessments, documents).
Patient data is stored as local files (JSON, PDF, JPG) per patient directory.

## Key architectural decisions
- **Three-tier sync conflict resolution:**
  - Master data & transactional data: iPad wins (field authority)
  - Parameters & reference data: Server wins (central management)
  - Deletions from iPads: Always rejected (data protection)
- No Docker, no cloud — bare metal Linux with systemd
- Star schema data warehouse in PostgreSQL
- See decisions/ for full ADRs

## Conventions
- All documents in Markdown
- Architecture Decision Records (ADRs) in `decisions/` numbered sequentially
- ADR format: context → decision → consequences
- Diagrams as ASCII art or Mermaid
- When updating a protocol spec, note the date and what changed at the top

## Infrastructure context
- Central server: Ubuntu Server 24.04 LTS (headless, Intel/Lenovo)
- VPN gateway: Raspberry Pi (headless Linux) running WireGuard
- Development: MacBook Pro (Apple Silicon) with Claude Code
- Database: PostgreSQL 16+ with staging/warehouse/mart schema pattern
- All traffic over WireGuard VPN (10.10.0.0/24)
