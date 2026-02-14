# Nexus Development Workflow

> Last updated: 2026-02-13

## Development Environment

- **Primary machine:** MacBook Pro (Apple Silicon) — `nexus-mac`
- **Development assistant:** Claude Code (local)
- **Target deployment:** Ubuntu Server 24.04 (headless, Intel/Lenovo) — `nexus-server`
- **VPN gateway:** Raspberry Pi (headless) — `nexus-gate`

## Repository Layout

```
~/Projects/nexus/                ← git repo (docs + project root)
├── .claude/CLAUDE.md
├── ARCHITECTURE_OVERVIEW.md     ← architecture docs live at root
├── SYNC_PROTOCOL.md
├── DATA_DICTIONARY.md
├── SECURITY.md
├── BACKUP_STRATEGY.md
├── decisions/                   ← ADRs
├── diagrams/
├── nexus-core/                  ← separate git repo (Python)
├── nexus-gate/                  ← separate git repo (Bash/Python)
├── nexus-field/                 ← separate git repo (Swift)
├── clarity/                     ← separate git repo (Python/PySide6)
└── clarity-swift/               ← separate git repo (Swift)
```

The root `nexus/` repo tracks documentation only. Component repos are
git-ignored by the parent and managed independently.

## Working with Claude Code

### One Repo Per Session

Claude Code works best with focused context. Open Claude Code in the
specific repo you're working on:

```bash
cd ~/Projects/nexus/nexus-core && claude    # Server work
cd ~/Projects/nexus/nexus-field && claude   # iPad app work
cd ~/Projects/nexus/nexus-gate && claude    # Gateway work
```

### Cross-Repo Changes

When a change spans repos (e.g., sync protocol update):

1. Update the spec at the nexus root first (e.g., `SYNC_PROTOCOL.md`)
2. Update `nexus-core/` (server side) in its own Claude Code session
3. Update `nexus-field/` (client side) in its own Claude Code session
4. Reference the root spec from each component's CLAUDE.md

### Task Sizing

Claude Code excels with well-defined tasks. Good task examples:

- "Add the /sync/push endpoint per the spec in ../nexus-docs/SYNC_PROTOCOL.md"
- "Create the staging schema migration with Alembic"
- "Write the systemd unit file for nexus-sync"
- "Generate tests for the conflict resolution module"
- "Create the WireGuard peer generation script"

Avoid: "Build the entire sync system" (too broad)

### CLAUDE.md Maintenance

Keep each repo's `.claude/CLAUDE.md` current. When you add a new module,
update the CLAUDE.md so future sessions have context. This is the single
most important habit for Claude Code productivity.

## Development Phases

### Phase 1 — Foundation
**Goal:** Infrastructure in place, basic connectivity proven

| Task                          | Repo          | Priority |
|-------------------------------|---------------|----------|
| Architecture docs (this repo) | nexus-docs    | ✅ Done  |
| WireGuard + UFW setup scripts | nexus-gate    | Next     |
| PostgreSQL install + schemas  | nexus-core    | Next     |
| FastAPI skeleton + health endpoint | nexus-core | Next    |
| systemd unit files            | nexus-core    | Next     |
| Deployment script (Mac → Server) | nexus-core | Next     |

### Phase 2 — Core Data Flow
**Goal:** iPads can push/pull data through the sync API

| Task                              | Repo          |
|-----------------------------------|---------------|
| Sync API: push endpoint           | nexus-core    |
| Sync API: pull endpoint           | nexus-core    |
| Sync API: attachment upload/download | nexus-core |
| Sync API: auth (JWT)              | nexus-core    |
| Sync API: three-tier conflict resolution | nexus-core |
| iPad: file-based patient storage  | nexus-field   |
| iPad: sync engine + outbound queue| nexus-field   |
| iPad: minimal UI for testing      | nexus-field   |
| End-to-end sync test              | Both          |

### Phase 3 — Warehouse & ETL
**Goal:** Data flows from staging to warehouse to marts

| Task                              | Repo          |
|-----------------------------------|---------------|
| Dimensional model (DDL)           | nexus-core    |
| ETL: staging → warehouse          | nexus-core    |
| ETL: warehouse → marts            | nexus-core    |
| systemd timers for ETL            | nexus-core    |
| Mart verification queries         | nexus-core    |

### Phase 4 — Reporting & BI
**Goal:** Data accessible through Clarity and direct SQL

| Task                              | Repo          |
|-----------------------------------|---------------|
| Clarity mart connector            | clarity       |
| Clarity dashboard basics          | clarity       |
| Clarity Swift port (macOS)        | clarity-swift |
| Direct SQL access setup           | nexus-core    |

### Phase 5 — Hardening
**Goal:** Production-ready operations

| Task                              | Repo          |
|-----------------------------------|---------------|
| Backup automation + verification  | nexus-core    |
| Health monitoring                 | nexus-core    |
| Crawler framework                 | nexus-core    |
| Security hardening checklist      | All           |
| Gateway failover                  | nexus-gate    |

## Deployment Workflow

### Development (nexus-mac)

```bash
# Python repos: use uv for dependency management
cd ~/Projects/nexus/nexus-core
uv sync
uv run pytest

# Swift repos: use Xcode
open ~/Projects/nexus/nexus-field/SyncClient.xcodeproj
```

### Deploy to Server

```bash
cd ~/Projects/nexus/nexus-core
./deploy/deploy.sh
```

The deploy script:
1. Runs tests locally
2. Rsync's source code to nexus-server
3. SSH's into server to run uv sync
4. Restarts affected systemd services
5. Verifies health endpoint responds

### Server Provisioning (First Time)

```bash
cd ~/Projects/nexus-core
./deploy/setup-server.sh nexus-server.local
```

The setup script:
1. Installs Python 3.12+, PostgreSQL 16+, uv
2. Creates OS users for each service
3. Creates PostgreSQL database and roles
4. Installs systemd unit files
5. Configures UFW rules
6. Sets up log rotation

## Git Conventions

- Main branch: `main` (always deployable)
- Feature branches: `feature/{description}`
- Commit messages: imperative mood ("Add sync push endpoint", not "Added...")
- Tag releases: `v{major}.{minor}.{patch}`

## Testing Strategy

| Layer          | Tool          | Scope                          |
|----------------|---------------|--------------------------------|
| Unit tests     | pytest        | Individual functions/classes   |
| Integration    | pytest + PostgreSQL | API endpoints with real DB |
| Sync protocol  | pytest        | Push/pull with mock client     |
| ETL            | pytest        | Staging → warehouse transforms |
| iPad           | XCTest        | Sync engine, local storage     |
| End-to-end     | Manual + script | Full iPad → API → DB → mart  |
