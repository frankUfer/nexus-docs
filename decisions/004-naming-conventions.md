# ADR-004: Nexus Naming Conventions

> Date: 2026-02-13 | Status: ACCEPTED

## Context

A multi-component platform needs consistent naming across repositories,
services, database objects, network identities, and code. Inconsistent
naming leads to confusion and operational errors.

## Decision

All platform components use the `nexus-` prefix (or `nexus_` / `nexus.`
depending on the context's conventions). The BI tool Clarity retains its
independent identity.

## Naming Map

| Context         | Pattern               | Examples                          |
|-----------------|-----------------------|-----------------------------------|
| Repositories    | `nexus-{component}`   | nexus-core, nexus-gate, nexus-field |
| Systemd units   | `nexus-{service}`     | nexus-sync.service, nexus-etl-staging.timer |
| PostgreSQL DB   | `nexus`               | Single database                   |
| DB schemas      | domain name           | staging, warehouse, mart_ops      |
| DB roles        | `nexus_{function}`    | nexus_sync, nexus_etl             |
| Python package  | `nexus.{module}`      | nexus.sync, nexus.etl             |
| Env variables   | `NEXUS_{VAR}`         | NEXUS_DB_HOST, NEXUS_SYNC_PORT    |
| Log identifiers | `nexus.{service}`     | nexus.sync, nexus.etl             |
| WireGuard peers | `nexus-{role}-{NN}`   | nexus-field-01, nexus-server      |
| Hostnames       | `nexus-{role}.local`  | nexus-server.local, nexus-gate.local |
| VPN IPs         | `10.10.0.{range}`     | .1=gateway, .10–19=servers, .100+=field |
| Clarity (BI)    | `clarity` / `clarity-swift` | Independent naming          |

## Reasons

1. **Discoverability** — `systemctl list-units nexus-*` shows all services
2. **Disambiguation** — No collision with OS services or other software
3. **Consistency** — Any team member can predict a name without looking it up
4. **Clarity independence** — Clarity is its own product, not just a Nexus component

## Consequences

- All new components must follow this scheme
- Existing Clarity repos keep their names
- CI/CD scripts, monitoring, and log queries can use prefix wildcards
