# Nexus

Self-hosted data platform connecting offline-first iPads with a
Linux-based data warehouse for therapy/patient management.

## Documentation

| Document | Description |
|----------|-------------|
| [Architecture Overview](ARCHITECTURE_OVERVIEW.md) | System topology, components, technology stack |
| [Sync Protocol](SYNC_PROTOCOL.md) | iPad ↔ server sync specification (three-tier conflict resolution) |
| [Data Dictionary](DATA_DICTIONARY.md) | Database schemas, tables, naming conventions |
| [Security](SECURITY.md) | Security layers, firewall rules, access control |
| [Backup Strategy](BACKUP_STRATEGY.md) | Backup schedule, recovery procedures |
| [Development Workflow](DEVELOPMENT_WORKFLOW.md) | How to develop, deploy, and test |

## Architecture Decision Records

| ADR | Title |
|-----|-------|
| [001](decisions/001-no-docker.md) | No Docker or Cloud Services |
| [002](decisions/002-offline-first.md) | Offline-First with Three-Tier Conflict Resolution |
| [003](decisions/003-warehouse-schema.md) | Star Schema Data Warehouse in PostgreSQL |
| [004](decisions/004-naming-conventions.md) | Nexus Naming Conventions |

## Component Repositories

Each component lives in its own sub-directory with its own git repository:

| Repo | Language | Purpose |
|------|----------|---------|
| `nexus-core/` | Python | Central server: API, ETL, crawlers, backup |
| `nexus-gate/` | Bash/Python | Raspberry Pi VPN gateway |
| `nexus-field/` | Swift | iPad patient data collection (file-based, offline-first) |
| `clarity/` | Python/PySide6 | BI tool (Linux) |
| `clarity-swift/` | Swift | BI tool (macOS/iPadOS) |

## Quick Start

```bash
# Clone and set up
cd ~/Projects/nexus

# Work on a component
cd nexus-core && claude    # Claude Code session for server work
cd nexus-gate && claude    # Claude Code session for gateway work
```
