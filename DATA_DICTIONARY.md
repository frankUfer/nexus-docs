# Nexus Data Dictionary

> Last updated: 2026-02-13
> Status: DRAFT — schemas will be formalized during Phase 1

## Schema Overview

The `nexus` PostgreSQL database uses four schema tiers:

```
staging.*         Raw ingest (source of truth for "what arrived")
warehouse.*       Cleaned dimensional model (source of truth for "what happened")
mart_ops.*        Operational reporting views
mart_analytics.*  Analytical reporting views
mart_field.*      iPad-facing pull data
```

## Schema: staging

All staging tables share these columns:

| Column              | Type         | Description                        |
|---------------------|--------------|------------------------------------|
| id                  | BIGSERIAL    | Staging row ID                     |
| source              | TEXT         | Origin: 'sync', 'crawl', 'import' |
| source_device_id    | UUID         | Device that sent the data (nullable)|
| data_category       | TEXT         | 'master_data', 'transactional_data', 'parameter' |
| received_at         | TIMESTAMPTZ  | Server receive timestamp           |
| raw_payload         | JSONB        | Original data as received          |
| processed           | BOOLEAN      | Has ETL picked this up?            |
| processed_at        | TIMESTAMPTZ  | When ETL processed it              |

### staging.sync_inbound
Incoming push data from iPads. One row per sync push payload.
Delete operations from iPads are rejected before reaching staging.

### staging.sync_outbound
Queued data for iPad pull responses. Populated by ETL from mart_field.

### staging.crawl_raw
Data collected by crawlers. One row per crawl result.

### staging.import_raw
Manually imported or API-ingested data.

### staging.sync_conflicts
Preserved data from conflict resolution (audit trail). Stores the
**overridden** version in each conflict:
- For master/transactional conflicts (iPad wins): stores the server version
  that was replaced by the iPad's data
- For parameter conflicts (server wins): stores the iPad version that was
  rejected in favor of the server's data

| Column              | Type         | Description                        |
|---------------------|--------------|------------------------------------|
| id                  | BIGSERIAL    | PK                                 |
| sync_id             | UUID         | From the sync request              |
| device_id           | UUID         | Which iPad was involved            |
| data_category       | TEXT         | master_data / transactional / parameter |
| entity_type         | TEXT         | e.g. 'patient', 'treatment_type'  |
| entity_id           | UUID         | Which record conflicted            |
| winner              | TEXT         | 'ipad' or 'server'                |
| overridden_data     | JSONB        | The version that was replaced      |
| winning_data        | JSONB        | The version that was kept          |
| resolved_at         | TIMESTAMPTZ  | When the conflict was resolved     |

### staging.sync_attachments
Metadata for binary files (PDF, JPG) received via sync upload.

| Column              | Type         | Description                        |
|---------------------|--------------|------------------------------------|
| id                  | BIGSERIAL    | PK                                 |
| entity_id           | UUID         | Parent entity                      |
| patient_id          | UUID         | Patient this belongs to            |
| filename            | TEXT         | Original filename                  |
| content_type        | TEXT         | MIME type                          |
| size_bytes          | BIGINT       | File size                          |
| checksum            | TEXT         | SHA-256 hash                       |
| storage_path        | TEXT         | Path on server filesystem          |
| received_at         | TIMESTAMPTZ  |                                    |

## Schema: warehouse

Dimensional model using star schema conventions.

### Dimension Tables (warehouse.dim_*)

Slowly changing dimensions (SCD Type 2 where needed).

#### warehouse.dim_calendar
Pre-populated date dimension.

| Column       | Type    | Description            |
|--------------|---------|------------------------|
| date_key     | INTEGER | YYYYMMDD (PK)         |
| full_date    | DATE    | Actual date            |
| year         | INTEGER |                        |
| quarter      | INTEGER | 1–4                    |
| month        | INTEGER | 1–12                   |
| week_of_year | INTEGER | ISO week               |
| day_of_week  | INTEGER | 1=Monday, 7=Sunday     |
| is_weekend   | BOOLEAN |                        |
| fiscal_year  | INTEGER | If different from calendar |
| fiscal_quarter| INTEGER|                        |

#### warehouse.dim_device
Registered devices (iPads, servers, etc.)

| Column         | Type         | Description              |
|----------------|--------------|--------------------------|
| device_key     | SERIAL       | Surrogate key (PK)      |
| device_id      | UUID         | Natural key              |
| device_name    | TEXT         | e.g. "nexus-field-01"   |
| device_type    | TEXT         | 'ipad', 'server', 'mac' |
| wireguard_ip   | INET         | VPN IP address           |
| registered_at  | TIMESTAMPTZ  |                          |
| is_active      | BOOLEAN      |                          |
| valid_from     | TIMESTAMPTZ  | SCD Type 2              |
| valid_to       | TIMESTAMPTZ  | SCD Type 2 (NULL=current)|

#### warehouse.dim_entity
Master data entities — primarily patients.

| Column         | Type         | Description              |
|----------------|--------------|--------------------------|
| entity_key     | SERIAL       | Surrogate key (PK)      |
| entity_id      | UUID         | Natural key              |
| entity_type    | TEXT         | 'patient', 'contact'    |
| patient_id     | UUID         | Self-ref for patients, parent for contacts |
| display_name   | TEXT         | Full name or label       |
| data           | JSONB        | Structured entity attributes |
| created_by_device | UUID      | Which iPad created this  |
| is_archived    | BOOLEAN      | Soft-delete flag         |
| valid_from     | TIMESTAMPTZ  | SCD Type 2              |
| valid_to       | TIMESTAMPTZ  | SCD Type 2 (NULL=current)|

#### warehouse.dim_source
Data source tracking.

| Column       | Type    | Description                    |
|--------------|---------|--------------------------------|
| source_key   | SERIAL  | Surrogate key (PK)            |
| source_name  | TEXT    | 'ipad_sync', 'web_crawl', ... |
| source_url   | TEXT    | For crawled sources            |
| is_active    | BOOLEAN |                                |

### Fact Tables (warehouse.fact_*)

#### warehouse.fact_transactions
Core transactional data — therapy sessions, assessments.

| Column            | Type         | Description             |
|-------------------|--------------|-------------------------|
| transaction_key   | BIGSERIAL    | Surrogate key (PK)     |
| date_key          | INTEGER      | FK → dim_calendar      |
| device_key        | INTEGER      | FK → dim_device        |
| entity_key        | INTEGER      | FK → dim_entity (patient)|
| source_key        | INTEGER      | FK → dim_source        |
| transaction_type  | TEXT         | 'session', 'assessment'|
| data              | JSONB        | Session/assessment details |
| created_at        | TIMESTAMPTZ  |                         |

#### warehouse.fact_events
Calendar/event entries.

| Column         | Type         | Description             |
|----------------|--------------|-------------------------|
| event_key      | BIGSERIAL    | Surrogate key (PK)     |
| date_key       | INTEGER      | FK → dim_calendar      |
| device_key     | INTEGER      | FK → dim_device        |
| entity_key     | INTEGER      | FK → dim_entity (patient)|
| event_type     | TEXT         | Appointment, follow-up  |
| event_start    | TIMESTAMPTZ  |                         |
| event_end      | TIMESTAMPTZ  |                         |
| description    | TEXT         |                         |

#### warehouse.fact_attachments
Tracks binary files (PDF, JPG) associated with patients.

| Column            | Type         | Description              |
|-------------------|--------------|--------------------------|
| attachment_key    | BIGSERIAL    | PK                       |
| date_key          | INTEGER      | FK → dim_calendar        |
| device_key        | INTEGER      | FK → dim_device          |
| entity_key        | INTEGER      | FK → dim_entity (patient)|
| filename          | TEXT         |                          |
| content_type      | TEXT         | MIME type                |
| size_bytes        | BIGINT       |                          |
| storage_path      | TEXT         | Server filesystem path   |
| checksum          | TEXT         | SHA-256                  |
| uploaded_at       | TIMESTAMPTZ  |                          |

#### warehouse.fact_sync_log
Operational: tracks every sync operation.

| Column            | Type         | Description              |
|-------------------|--------------|--------------------------|
| sync_log_key      | BIGSERIAL    | PK                       |
| date_key          | INTEGER      | FK → dim_calendar        |
| device_key        | INTEGER      | FK → dim_device          |
| sync_id           | UUID         | From sync protocol       |
| direction         | TEXT         | 'push' or 'pull'        |
| records_sent      | INTEGER      |                          |
| records_accepted  | INTEGER      |                          |
| conflicts         | INTEGER      |                          |
| errors            | INTEGER      |                          |
| duration_ms       | INTEGER      | Sync duration            |
| completed_at      | TIMESTAMPTZ  |                          |

## Schema: mart_ops

Operational data mart. Materialized views refreshed by nexus-etl-marts.

- `mart_ops.daily_sync_summary` — sync activity per device per day
- `mart_ops.device_health` — last sync, error rates, connectivity
- `mart_ops.data_freshness` — staleness per entity type

## Schema: mart_analytics

Analytical data mart. Domain-specific aggregations.

- TBD based on domain requirements

## Schema: mart_field

Data prepared for iPad pull sync. Read by nexus-sync API.

- `mart_field.parameters` — system configuration, treatment types, ICD codes
- `mart_field.reference_data` — lookup tables, dimensional data
- `mart_field.entity_updates` — changed patient/contact records since version N
- `mart_field.event_updates` — changed calendar entries since version N

## Naming Conventions

| Element          | Convention              | Example               |
|------------------|-------------------------|-----------------------|
| Schema           | lowercase, underscore   | `mart_ops`            |
| Table            | singular noun           | `dim_device`          |
| Column           | lowercase, underscore   | `device_name`         |
| Primary key      | `{table}_key` or `id`  | `device_key`          |
| Foreign key      | match parent PK name    | `device_key`          |
| Surrogate key    | SERIAL/BIGSERIAL       | Auto-increment        |
| Natural key      | Domain-specific         | `device_id` (UUID)    |
| Timestamp        | `*_at` suffix           | `created_at`          |
| Boolean          | `is_*` or `has_*`       | `is_active`           |
| Date dimension FK| `*_key` (INTEGER)       | `date_key` (YYYYMMDD) |

## Index Strategy

- All primary keys (automatic)
- All foreign keys (explicit)
- `staging.*`: index on `processed`, `received_at`
- `warehouse.fact_*`: index on all dimension foreign keys
- `mart_field.*`: index on `version` for efficient pull queries
