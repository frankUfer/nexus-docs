# Nexus Platform — Architecture Overview

> Last updated: 2026-02-13

## Purpose

Nexus is a self-hosted data platform that connects offline-first iPad
applications with a central Linux-based data warehouse. It collects,
synchronizes, transforms, and reports on data from field devices, external
sources, and manual imports — all without cloud dependencies.

## Design Principles

1. **Offline-first** — iPads work without connectivity; sync when available
2. **Self-hosted** — No cloud services; bare metal Linux with systemd
3. **Security by default** — All traffic over WireGuard VPN; role-based DB access
4. **Data warehouse discipline** — Staging → warehouse → marts; no shortcuts
5. **Scalable simplicity** — Start single-server; scale vertically, then horizontally

## Physical Topology

```
                        INTERNET / WAN
                              │
          ┌───────────────────┼───────────────────┐
          │                   │                   │
     ┌────▼─────┐       ┌────▼─────┐       ┌────▼─────┐
     │ iPad 01  │       │ iPad 02  │       │ iPad NN  │
     │ (nexus-  │       │ (nexus-  │       │ (nexus-  │
     │  field)  │       │  field)  │       │  field)  │
     └────┬─────┘       └────┬─────┘       └────┬─────┘
          │ WireGuard        │                   │
          └──────────┬───────┴───────────────────┘
                     │
              ┌──────▼──────────┐
              │  nexus-gate     │
              │  Raspberry Pi   │
              │  WireGuard +    │
              │  UFW + dnsmasq  │
              │  10.10.0.1      │
              └──────┬──────────┘
                     │ LAN
       ══════════════╪═══════════════════════════
                     │
              ┌──────▼──────────┐       ┌─────────────┐
              │  nexus-server   │       │  NAS         │
              │  Ubuntu Server  │──────►│  Backup      │
              │  PostgreSQL     │       │  target      │
              │  Python workers │       └─────────────┘
              │  10.10.0.10     │
              └──────┬──────────┘
                     │
              ┌──────▼──────────┐
              │  nexus-mac      │
              │  MacBook Pro    │
              │  Development    │
              │  Clarity desktop│
              │  10.10.0.20     │
              └─────────────────┘
```

## VPN Network (WireGuard)

| Subnet          | Range             | Purpose           |
|-----------------|-------------------|--------------------|
| Gateway         | 10.10.0.1         | nexus-gate (RPi)  |
| Servers         | 10.10.0.10–19     | nexus-server + future |
| Dev machines    | 10.10.0.20–29     | nexus-mac + future |
| Field devices   | 10.10.0.100–199   | iPads              |

## Component Overview

### nexus-gate (Raspberry Pi)

Network edge device. Runs WireGuard server, UFW firewall, dnsmasq for
internal DNS resolution (`*.local`), and Guardian authentication service.
Headless Raspberry Pi OS Lite.

**High availability:** Optional second RPi as warm standby using keepalived
(VRRP). Both nodes share a virtual IP (VIP) on the LAN. The FritzBox
port-forwards UDP 51820 to the VIP. Only the MASTER node runs
WireGuard/Guardian/dnsmasq — on failure, the VIP floats to the standby
which starts all services automatically. Config sync (rsync over SSH,
5-min timer) keeps the standby current with peer registrations. Both
nodes share the same WireGuard private key and JWT secret, so iPads
reconnect transparently after failover (~25-50s via WireGuard keepalive).

**Responsibilities:**
- Terminate VPN tunnels from all peers
- Authenticate devices and issue JWT tokens (Guardian)
- Firewall: only allow expected traffic patterns
- Internal DNS: resolve `nexus-server.local`, `nexus-gate.local`
- Health check: verify connectivity to nexus-server
- Automated failover via VRRP (keepalived)

### nexus-core (Ubuntu Server)

Central application server. Runs all Python services under systemd.

**Services:**

| Service              | Type     | Description                          |
|----------------------|----------|--------------------------------------|
| nexus-sync           | API      | FastAPI — receives/sends iPad data   |
| nexus-etl-staging    | Worker   | Staging → warehouse transforms       |
| nexus-etl-marts      | Worker   | Warehouse → data mart transforms     |
| nexus-crawl          | Worker   | External data collection             |
| nexus-backup         | Worker   | PostgreSQL backup + verification     |
| nexus-health         | Worker   | System health monitoring             |

**Database:** PostgreSQL 16+ (single `nexus` database)

| Schema      | Purpose                              | Access pattern     |
|-------------|--------------------------------------|--------------------|
| staging     | Raw ingest, append-only, timestamped | Write: sync, crawl |
| warehouse   | Cleaned dimensional model            | Write: ETL         |
| mart_ops    | Operational reporting                | Read: Clarity, SQL |
| mart_analytics | Analytical reporting              | Read: Clarity, SQL |
| mart_field  | iPad-facing pull data                | Read: sync API     |

### nexus-field (iPad App)

Offline-first iPad application built in Swift. Stores all patient data
as local files (JSON, PDF, JPG) organized per patient directory — no
local database dependency.

**Local storage structure:**
```
/NexusField/patients/{patient_uuid}/
  ├── patient.json          Master data
  ├── sessions/*.json       Transactional data
  ├── documents/*.pdf       Attachments
  ├── images/*.jpg          Attachments
  └── sync_meta.json        Sync state
```

**Key behaviors:**
- Full functionality without network
- Background sync when VPN is reachable
- Three-tier conflict resolution:
  - Master & transactional data: iPad wins (field authority)
  - Parameters: server wins (central management)
  - Deletions: never sent to server (data protection)
- Local outbound queue for pending changes
- Pull parameter updates and cross-device patient changes

See [SYNC_PROTOCOL.md](SYNC_PROTOCOL.md) for the complete specification.

### Clarity (BI Tool)

Independent reporting and analytics tool. Two implementations:

- **clarity** — Python/PySide6 with FastAPI backend and DuckDB engine (Linux primary)
- **clarity-swift** — Native macOS/iPadOS version

Reads from PostgreSQL data marts via read-only `clarity_reader` role.
Can also connect to other data sources independently.

## Data Flow

```
  iPad (nexus-field)          Crawlers             Manual / API
        │                        │                      │
        ▼                        ▼                      ▼
  ┌──────────────────────────────────────────────────────────┐
  │                     STAGING                               │
  │  sync_inbound  │  crawl_raw  │  import_raw               │
  │  (append-only, timestamped, source-tagged)                │
  └──────────────────────────┬───────────────────────────────┘
                             │
                    nexus-etl-staging
                     (clean, dedupe,
                      validate, conform)
                             │
                             ▼
  ┌──────────────────────────────────────────────────────────┐
  │                    WAREHOUSE                              │
  │  dim_calendar  │  dim_device  │  dim_entity  │ dim_source│
  │  fact_transactions  │  fact_events  │  fact_sync_log     │
  │  (star schema, slowly changing dimensions)                │
  └──────────────────────────┬───────────────────────────────┘
                             │
                     nexus-etl-marts
                      (aggregate,
                       denormalize,
                       materialize)
                             │
                             ▼
  ┌──────────────────────────────────────────────────────────┐
  │                    DATA MARTS                             │
  │  mart_ops  │  mart_analytics  │  mart_field              │
  │  (domain-specific, read-optimized)                        │
  └──────────────────────────┬───────────────────────────────┘
                             │
              ┌──────────────┼──────────────┐
              ▼              ▼              ▼
          Clarity      Direct SQL     nexus-field
                                      (pull sync)
```

## Security Model

| Layer         | Mechanism                                          |
|---------------|----------------------------------------------------|
| Transport     | WireGuard VPN (all traffic encrypted)              |
| Network       | UFW on gateway + server; allowlist only             |
| Authentication| Device certificates + API tokens over VPN           |
| Authorization | PostgreSQL roles (nexus_sync, nexus_etl, etc.)     |
| API           | TLS on FastAPI (defense in depth, even inside VPN) |
| SSH           | Key-only, no passwords, fail2ban                   |
| Secrets       | Environment variables, not in repos                |

## Backup Strategy

| What              | Method                  | Frequency | Retention | Target          |
|-------------------|-------------------------|-----------|-----------|-----------------|
| Full DB dump      | pg_dump (custom format) | Daily     | 7 days    | NAS + offsite   |
| WAL archives      | pg_archivecommand       | Continuous| 14 days   | NAS             |
| Server config     | git + rsync             | On change | Forever   | git + NAS       |
| Clarity exports   | Application backup      | Daily     | 30 days   | NAS             |
| Restore test      | Automated verification  | Weekly    | N/A       | Temp DB on NAS  |

## Technology Stack

| Component      | Technology                   | Version    |
|----------------|------------------------------|------------|
| Server OS      | Ubuntu Server LTS            | 24.04      |
| Gateway OS     | Raspberry Pi OS Lite         | Bookworm   |
| Database       | PostgreSQL                   | 16+        |
| Python         | CPython                      | 3.12+      |
| Package mgmt   | uv                           | Latest     |
| API framework  | FastAPI + uvicorn            | Latest     |
| DB driver      | psycopg 3                    | Latest     |
| Migrations     | Alembic                      | Latest     |
| VPN            | WireGuard                    | Latest     |
| Firewall       | UFW                          | Latest     |
| Process mgmt   | systemd                      | Native     |
| BI analytics   | DuckDB (inside Clarity)      | Latest     |
| iPad app       | Swift (file-based storage)   | Latest     |
| Dev machine    | macOS (Apple Silicon)        | Latest     |
| Dev assistant  | Claude Code                  | Latest     |
