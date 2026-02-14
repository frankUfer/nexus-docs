# Nexus Security Architecture

> Last updated: 2026-02-13

## Security Layers

```
┌─────────────────────────────────────────────────────┐
│ Layer 1: NETWORK — WireGuard VPN                    │
│   All traffic encrypted; no services exposed to     │
│   public internet                                   │
├─────────────────────────────────────────────────────┤
│ Layer 2: FIREWALL — UFW                             │
│   Allowlist-only on gateway AND server              │
│   Only expected ports, only expected source IPs     │
├─────────────────────────────────────────────────────┤
│ Layer 3: TRANSPORT — TLS                            │
│   FastAPI serves over HTTPS even inside VPN         │
│   Defense in depth                                  │
├─────────────────────────────────────────────────────┤
│ Layer 4: AUTHENTICATION                             │
│   Device identity + JWT API tokens                  │
│   SSH key-only access to servers                    │
├─────────────────────────────────────────────────────┤
│ Layer 5: AUTHORIZATION                              │
│   PostgreSQL role-based access                      │
│   Principle of least privilege per service           │
├─────────────────────────────────────────────────────┤
│ Layer 6: DATA — Encryption at rest (optional)       │
│   PostgreSQL data directory on encrypted volume     │
│   Backup encryption (borg)                          │
└─────────────────────────────────────────────────────┘
```

## WireGuard VPN (nexus-gate)

- All devices connect through the Raspberry Pi gateway
- Each device has a unique key pair and fixed IP
- No split tunneling — all Nexus traffic goes through the VPN
- Key rotation: annually or on device compromise
- Gateway runs on dedicated hardware (RPi) — no shared services

### Peer Management

- New peers added by administrator only
- Each peer gets: WireGuard config, API token, device_id
- Revocation: remove peer from WireGuard config + revoke API token
- Peer list version-controlled in nexus-gate repo (keys excluded)

## Firewall Rules (UFW)

### nexus-gate (Raspberry Pi)

```
Default: deny incoming, deny forwarding
Allow: UDP 51820 from any         (WireGuard)
Allow: SSH from 10.10.0.20/32     (admin from nexus-mac only)
Forward: 10.10.0.0/24 → 10.10.0.10 (VPN to server, specific ports)
```

### nexus-server (Ubuntu Server)

```
Default: deny incoming
Allow: TCP 8443  from 10.10.0.0/24   (sync API)
Allow: TCP 5432  from 10.10.0.20/32  (PostgreSQL from dev machine)
Allow: TCP 22    from 10.10.0.20/32  (SSH from dev machine)
Allow: TCP 8080  from 10.10.0.0/24   (Clarity, if served from here)
```

## Authentication

### iPad Devices (nexus-field)
1. WireGuard tunnel must be active (network-level identity)
2. JWT bearer token in API requests (application-level identity)
3. Token contains: device_id, issued_at, expires_at
4. Token signed with server secret (HS256 initially, RS256 later)
5. Token rotation: 30-day expiry, refresh endpoint available

### SSH Access (admin)
- Key-based authentication only (PasswordAuthentication no)
- fail2ban for brute force protection
- Only accessible from nexus-mac (10.10.0.20) via VPN

### PostgreSQL
- Local connections: peer authentication for admin
- Network connections: scram-sha-256 with strong passwords
- Each service gets its own role with minimal privileges

## Authorization (PostgreSQL Roles)

| Role            | staging | warehouse | mart_* | mart_field | System   |
|-----------------|---------|-----------|--------|------------|----------|
| nexus_admin     | ALL     | ALL       | ALL    | ALL        | SUPERUSER|
| nexus_sync      | RW (sync tables) | — | —    | READ       | —        |
| nexus_etl       | READ    | READ/WRITE| WRITE  | WRITE      | —        |
| nexus_crawl     | WRITE (crawl_raw) | — | —   | —          | —        |
| nexus_backup    | READ    | READ      | READ   | READ       | pg_read_all_data |
| clarity_reader  | —       | —         | READ   | —          | —        |

## Secrets Management

- API signing keys: `/etc/nexus/secrets/jwt_secret`
- Database passwords: `/etc/nexus/secrets/db_passwords`
- WireGuard private keys: `/etc/wireguard/` (standard location)
- File permissions: `root:nexus 640` or more restrictive
- **Never in git repositories**
- Environment variables loaded from `/etc/nexus/nexus.env`

## Intrusion Detection

- fail2ban on SSH (nexus-server and nexus-gate)
- nexus-health monitors: failed auth attempts, unusual sync patterns
- journald alerts on repeated 401/403 responses
- Daily log review (automated summary via nexus-health)

## Incident Response

1. **Device compromised:** Remove WireGuard peer, revoke API token, investigate staging data
2. **Server compromised:** Isolate from network, restore from backup, rotate all secrets
3. **Gateway compromised:** Switch to backup RPi, rotate all WireGuard keys

## Hardening Checklist

### nexus-gate (Raspberry Pi)
- [ ] Minimal OS install (Raspberry Pi OS Lite)
- [ ] Automatic security updates (unattended-upgrades)
- [ ] SSH key-only, non-default port
- [ ] UFW enabled with allowlist rules
- [ ] No unnecessary services running
- [ ] Read-only filesystem where possible

### nexus-server (Ubuntu Server)
- [ ] Minimal server install, no desktop packages
- [ ] Automatic security updates
- [ ] SSH key-only, fail2ban
- [ ] UFW enabled
- [ ] PostgreSQL listens only on localhost + VPN interface
- [ ] Separate OS user per service (nexus-sync, nexus-etl, etc.)
- [ ] Encrypted backup volume

### nexus-mac (Development)
- [ ] FileVault enabled
- [ ] SSH key with passphrase
- [ ] WireGuard config protected
- [ ] No production secrets in development environment
