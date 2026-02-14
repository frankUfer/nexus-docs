# Nexus Backup Strategy

> Last updated: 2026-02-13

## Backup Targets

```
NAS: /mnt/nas/nexus-backup/
├── daily/           pg_dump custom format, 7-day rotation
├── wal/             WAL archives for point-in-time recovery
├── config/          Server and gateway configuration snapshots
├── clarity/         Clarity-specific data exports
└── restore-test/    Weekly restore verification workspace
```

## PostgreSQL Backup

### Daily Logical Backup (pg_dump)

- **What:** Full `nexus` database in custom format
- **When:** Daily at 02:00 via `nexus-backup.timer`
- **Where:** `/mnt/nas/nexus-backup/daily/nexus_YYYYMMDD.dump`
- **Retention:** 7 days (oldest removed by backup script)
- **Role:** `nexus_backup` (pg_read_all_data)

```bash
pg_dump -Fc -f /mnt/nas/nexus-backup/daily/nexus_$(date +%Y%m%d).dump nexus
```

### WAL Archiving (Continuous)

- **What:** Write-Ahead Log segments for point-in-time recovery
- **Configuration:** `archive_mode = on` in postgresql.conf
- **Where:** `/mnt/nas/nexus-backup/wal/`
- **Retention:** 14 days
- **Enables:** Recovery to any point in time within retention window

```
# postgresql.conf
archive_mode = on
archive_command = 'cp %p /mnt/nas/nexus-backup/wal/%f'
```

### Restore Verification (Weekly)

- **What:** Automated restore of latest dump to temporary database
- **When:** Weekly (Sunday 04:00) via `nexus-backup.timer`
- **Where:** Temporary database `nexus_restore_test` (dropped after verification)
- **Verification:** Row counts compared against production, basic integrity checks
- **Alerting:** Failure logged and flagged in nexus-health

## Configuration Backup

### Server Configuration
- `/etc/nexus/` — application config (excluding secrets)
- `/etc/systemd/system/nexus-*` — systemd unit files
- `/etc/postgresql/` — PostgreSQL configuration
- `/etc/ufw/` — firewall rules

Backed up via rsync to NAS on every change (triggered by deployment script).
Also version-controlled in git (secrets excluded via .gitignore).

### Gateway Configuration
- `/etc/wireguard/` — WireGuard config (private keys excluded)
- `/etc/ufw/` — firewall rules
- Custom scripts in nexus-gate repo

## iPad Data Safety

iPad data is protected through multiple layers:

1. **Local file storage:** JSON, PDF, JPG files per patient on device
2. **Sync protocol:** Data pushed to staging as soon as connectivity allows
3. **Staging is append-only:** Once received, data is never deleted from staging
4. **Deletion protection:** iPads cannot delete server-side data — deletions
   from iPads are always rejected by the sync API
5. **Conflict audit trail:** All conflict resolutions (both iPad-wins and
   server-wins) are preserved in `staging.sync_conflicts`
6. **Staging is backed up:** Part of the PostgreSQL backup chain

Data loss scenario: iPad is lost/destroyed before sync → data since last
successful sync is lost. Mitigation: frequent sync attempts when online,
and encouraging users to sync after each patient interaction.

**Server-side attachment storage:**
Binary files (PDF, JPG) uploaded via sync are stored on the server filesystem
at a configurable path (default: `/var/nexus/attachments/`), organized by
patient_id. This path is included in the backup schedule.

```
/var/nexus/attachments/
├── {patient_uuid}/
│   ├── documents/
│   │   └── intake_form.pdf
│   └── images/
│       └── assessment_01.jpg
└── {patient_uuid}/
    └── ...
```

## Recovery Procedures

### Scenario 1: Corrupted Database (Data Loss)

```
1. Stop all nexus services
2. Restore from latest pg_dump:
   pg_restore -d nexus /mnt/nas/nexus-backup/daily/nexus_YYYYMMDD.dump
3. Apply WAL archives for point-in-time recovery if needed
4. Verify data integrity
5. Restart services
6. iPads will re-sync automatically
```

### Scenario 2: Server Hardware Failure

```
1. Provision new Ubuntu Server
2. Run deploy/setup-server.sh (from nexus-core repo)
3. Restore PostgreSQL from NAS backup
4. Restore configuration from NAS/git
5. Update WireGuard peer config on nexus-gate
6. Verify and restart
```

### Scenario 3: Gateway Failure

```
1. Activate standby Raspberry Pi (if available)
   OR provision new RPi from nexus-gate repo
2. Copy WireGuard config (keys from secure storage)
3. Verify connectivity from all peers
```

### Scenario 4: NAS Failure

```
1. Backups temporarily write to local disk on nexus-server
2. Replace/repair NAS
3. Restore backup directory structure
4. Resume normal backup schedule
```

## Monitoring

The `nexus-health` service monitors:
- Last successful backup timestamp
- WAL archiving lag
- NAS disk space
- Restore test results
- Backup file sizes (anomaly detection)

## Offsite Backup (Future Enhancement)

For additional disaster protection, consider:
- Borg backup to a remote location (encrypted, deduplicated)
- Rsync to a secondary NAS at a different physical location
- Encrypted backup to a friend's NAS (borg with encryption key you control)

Not implemented in Phase 1 but planned for production hardening.

## Backup Schedule Summary

| Backup Type       | Frequency  | Time  | Retention | Managed By          |
|-------------------|------------|-------|-----------|---------------------|
| pg_dump (full)    | Daily      | 02:00 | 7 days    | nexus-backup.timer  |
| WAL archiving     | Continuous | —     | 14 days   | PostgreSQL native   |
| Attachments       | Daily      | 02:30 | Mirrored  | rsync to NAS        |
| Config snapshot   | On change  | —     | Forever   | deploy script + git |
| Restore test      | Weekly     | Sun 04:00 | N/A   | nexus-backup.timer  |
| Clarity export    | Daily      | 03:00 | 30 days   | clarity backup task |
