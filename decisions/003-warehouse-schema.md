# ADR-003: Star Schema Data Warehouse in PostgreSQL

> Date: 2026-02-13 | Status: ACCEPTED

## Context

Nexus collects data from multiple sources (iPads, crawlers, imports) and
needs to make it available for operational and analytical reporting. The
data must be clean, consistent, and queryable without understanding the
raw source formats.

## Decision

Use a star schema dimensional model inside PostgreSQL, organized as:

```
staging (raw) → warehouse (dimensional) → data marts (domain-specific)
```

All within a single PostgreSQL database using schema separation.

## Reasons

1. **Proven pattern** — Star schemas are the industry standard for analytical
   workloads. Well-understood by tools (Clarity, DuckDB, any SQL client).

2. **Query performance** — Denormalized fact tables with dimension lookups are
   fast for aggregation queries without complex joins.

3. **Single database** — Keeping everything in one PostgreSQL instance avoids
   distributed system complexity. Schema separation provides logical isolation
   with shared transactions.

4. **Incremental ETL** — Staging → warehouse → mart pipeline is easy to
   reason about, test, and debug. Each stage is independently verifiable.

5. **DuckDB compatibility** — Clarity uses DuckDB for analytics. Star schemas
   transfer cleanly into DuckDB's columnar format via PostgreSQL export or
   direct connection.

## Consequences

- ETL workers must maintain the dimensional model (SCD handling, surrogate keys)
- Reporting queries target marts, not staging or warehouse directly
- Schema migrations managed through Alembic — must handle both structural
  changes and data migration
- Initial dimension design requires domain understanding (to be refined iteratively)
- Materialized views for marts need refresh scheduling

## Schema Tier Responsibilities

| Tier       | Writes              | Reads                 | Responsibility          |
|------------|---------------------|-----------------------|-------------------------|
| staging    | sync API, crawlers  | ETL workers           | Preserve raw input      |
| warehouse  | ETL workers         | ETL workers, analysts | Clean dimensional model |
| mart_*     | ETL workers         | Clarity, SQL, sync    | Domain-optimized views  |

## Alternatives Considered

- **Normalized (3NF) warehouse** — More storage-efficient but slower for
  analytical queries and harder for end users to query directly.
- **Data lake (files)** — Adds file management complexity. PostgreSQL handles
  the expected data volumes without needing a lake architecture.
- **Separate analytical database** — DuckDB or ClickHouse alongside PostgreSQL.
  May be considered later if query performance requires it. For now,
  PostgreSQL handles both OLTP (sync) and OLAP (marts) workloads.
