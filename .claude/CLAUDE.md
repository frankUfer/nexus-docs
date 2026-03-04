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
	├── nexus-admin/                    ← separate git repo (PySide6, macOS admin GUI)
	├── nexus-gate/                     ← separate git repo (RPi gateway)
	├── clarity/                        ← separate git repo (BI tool, Python)
	└── clarity-swift/                  ← separate git repo (BI tool, Swift)

## Current priority: iPad app integration

The `AthleticPerformance/` directory contains an existing iPad app for
therapy/patient management, imported from a prior development phase.
It needs to be analyzed and refactored to align with the Nexus platform.

### Integration goals (in order)
1. **Analyze first, change nothing** — understand current data models,
   persistence, networking, and architecture before making any changes
2. Align data models with Nexus entity types and data categories:
   2. master\_data: patient demographics, contacts, profiles
   3. transactional\_data: sessions, assessments, events, documents
   4. parameter: treatment types, lookup codes, system config
3. Migrate persistence to file-based patient storage
   (JSON/PDF/JPG per patient directory) per SYNC\_PROTOCOL.md
4. Build NexusSync module inside the app for offline-first sync
   with nexus-core
5. Ensure data structures map cleanly to the warehouse schema
   in DATA\_DICTIONARY.md (dim\_entity, fact\_transactions, etc.)
6. Respect three-tier conflict resolution:
   2. Master & transactional data: iPad wins
   3. Parameters: server wins
   4. Deletions from iPad: always rejected

### Reference documents (read these before making app changes)
- SYNC\_PROTOCOL.md — sync endpoints, payloads, conflict rules, iPad storage model
- DATA\_DICTIONARY.md — warehouse schema the app's data must map to
- ARCHITECTURE\_OVERVIEW.md — system topology and component roles

### Server-side status (nexus-core, already complete)
- Sync API: push, pull, upload, download endpoints (HTTPS on port 8443)
- Provisioning API: generate-code, claim, devices, code-status, device sync history
- Three-tier conflict resolution
- JWT authentication (VPN) + X-Device-ID (wired)
- Staging → warehouse → mart ETL pipeline
- Dimensional model (dim\_calendar, dim\_device, dim\_entity, dim\_source)
- Fact tables (fact\_transactions, fact\_events, fact\_attachments, fact\_sync\_log)
- All Alembic migrations
- TLS with self-signed CA (iOS-compliant server cert)

### iPad app sync status (completed 2026-03-03)
- Dual-transport sync: USB-wired (Bonjour + X-Device-ID) and VPN (WireGuard + JWT)
- TLS trust via custom URLSession delegate (NexusTLSSessionDelegate)
- Onboarding: provisioning claim over USB, WireGuard config export via share sheet
- Auth: Guardian token request, auto-refresh, re-auth on 401
- Connection test: VPN OK, Auth OK, Server OK (all three verified)

The app must produce data that matches the sync API contract in SYNC\_PROTOCOL.md.

## Component repositories (separate git repos, ignored by this repo)
- `nexus-core/`    — Central server: FastAPI sync API, ETL, crawlers, backup (Python)
- `nexus-admin/`   — macOS admin GUI: PySide6 desktop app for device management and onboarding
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
- Central server: Ubuntu Server 24.04 LTS (headless, Intel/Lenovo) — 192.168.178.13
- VPN gateway: Raspberry Pi (headless Linux) running WireGuard — 192.168.178.12
- Development: MacBook Pro (Apple Silicon) with Claude Code
- Database: PostgreSQL 16+ with staging/warehouse/mart schema pattern
- All traffic over WireGuard VPN (10.8.0.0/24)

### TLS setup (completed 2026-03-03)
- Self-signed CA: `/etc/nexus/tls/ca.crt` + `ca.key` (root:root, 10-year validity)
- Server cert: `/etc/nexus/tls/server.crt` + `server.key` (root:nexus, 825-day validity)
  - SAN: IP:10.8.0.10, IP:127.0.0.1, IP:192.168.178.13, DNS:nexus-server.local
  - iOS-compliant: basicConstraints=CA:FALSE, extendedKeyUsage=serverAuth
- iPad trusts the CA via `NexusTLSSessionDelegate` reading `nexus-ca-cert.txt` from
  Documents/resources/tls/ (PEM format, .txt extension required for Xcode bundle inclusion)
- uvicorn runs with `--ssl-keyfile` and `--ssl-certfile` on port 8443

### Permissions model
- **nexus-server**: service runs as `nexus:nexus` (uid 999)
  - `/etc/nexus/tls/`: 750 root:nexus — server.key 640, ca.key 600 root:root
  - `/etc/nexus/secrets/`: 750 root:nexus
  - nexus-sync.service: enabled, sandboxed (ProtectSystem=strict)
- **RPi4 (nexus-gate)**: Guardian runs as `nexus` user
  - `/etc/wireguard/`: 755, public.key 644
  - `/opt/nexus-gate/data/`: nexus:nexus (devices.json, incidents.json)
  - sudoers.d entry for manage-peers.sh (passwordless)

### Auth integration
The app authenticates via Guardian (nexus-gate) before syncing with nexus-core.
See AUTH\_PROTOCOL.md for the exact endpoints, token format, and error handling.
The app must:
1. Connect via WireGuard
2. Request token from Guardian (POST /auth/token)
3. Include token in all nexus-core API calls (Authorization: Bearer)
4. Handle token refresh before expiry
5. Handle auth errors (401, 403, 429 rate limit)
	
	**Step 3: The coordination workflow going forward**
When you need to change something that spans both repos:

1. Update the contract FIRST
   cd \~/Projects/nexus
   claude
   → "Update AUTH\_PROTOCOL.md: add device\_os to fingerprint fields"
   → commit

2. Update nexus-gate
   cd \~/Projects/nexus/nexus-gate
   claude
   → "AUTH\_PROTOCOL.md was updated — device\_os was added to fingerprint.
	  Update Guardian to require and validate this field."
   → commit

3. Update AthleticPerformance
   cd \~/Projects/nexus
   claude
   → "AUTH\_PROTOCOL.md was updated — device\_os was added to fingerprint.
	  Update the app's auth client to include this field."
   → commit

## Session log

### 2026-03-03: End-to-end VPN sync with TLS

**Goal**: Get iPad syncing with nexus-core over WireGuard VPN with proper HTTPS.

**Fixes applied across the full stack**:

1. **OnboardingView share sheet** — deferred config save to `onDismiss` so
   the WireGuard share sheet isn't killed by navigation away from OnboardingView

2. **Guardian (nexus-gate) provisioning fixes**:
   - `admin.py`: fail with HTTP 503 if WireGuard public key or endpoint is missing
     (was silently generating broken configs)
   - `devices.py`: case-insensitive device ID lookup (Swift sends uppercase,
     Python stores lowercase)
   - RPi4 permissions: `/etc/wireguard/` 755, `public.key` 644, data/ chown nexus,
     sudoers.d for manage-peers.sh

3. **nexus-core server**:
   - Added `server_url` config (was using bind address `0.0.0.0` in provisioning)
   - TLS: generated CA + server cert, configured uvicorn with `--ssl-keyfile/certfile`
   - Regenerated server cert for iOS compliance (825 days, EKU=serverAuth,
     basicConstraints=CA:FALSE)
   - UFW: added rule for VPN subnet `10.8.0.0/24` port 8443
   - Permissions: server.key 640 root:nexus, tls/ 750, service enabled

4. **iPad app (AthleticPerformance)**:
   - `NexusTLSSessionDelegate`: custom URLSession delegate trusting Nexus CA cert
   - CA cert bundled as `nexus-ca-cert.txt` (PEM in .txt — Xcode's synchronized
     root group doesn't include .der/.crt as bundle resources)
   - `SetupAppDirectories`: copies cert to Documents/resources/tls/ via
     `copyBundleResource(named:withExtension:to:)`
   - `DiscoveredServer.baseURL`: uses https:// for port 8443 (was http://)
   - Health check: uses `URLSession.nexus` instead of `.shared`
   - `NexusSyncClient` + `OnboardingClient`: switched to `URLSession.nexus`
   - `SyncClientError`: added `LocalizedError` conformance
   - `SyncSettingsView`: added Reset Provisioning button, WireGuard config validation

**Key learnings**:
- Xcode `PBXFileSystemSynchronizedRootGroup` only auto-includes recognized file
  types (.json, .txt, .rtf, .png, etc.) — not .der, .crt, or .csv
- iOS requires server certs ≤ 825 days, with extendedKeyUsage=serverAuth and
  basicConstraints=CA:FALSE (Apple TLS requirements since iOS 13)
- iCloud Private Relay intercepts HTTP traffic to private IPs — must use HTTPS
- Swift UUID.uuidString returns UPPERCASE, Python str(uuid4()) returns lowercase

### 2026-03-04: Fix dual-transport auth and TLS for all connection scenarios

**Goal**: Get sync working across all three transport scenarios: VPN via mobile
data, VPN via WiFi, and USB cable with flight mode.

**Bugs found and fixed**:

1. **Server cert SAN missing LAN IP** (nexus-core server):
   - Cert had `SAN: IP:10.8.0.10, IP:127.0.0.1, DNS:nexus-server.local`
   - Bonjour-discovered connections use LAN IP `192.168.178.13`, which wasn't
     in the SAN → TLS evaluation failed with "Zertifikatsname stimmt nicht überein"
   - Regenerated cert: added `IP:192.168.178.13` to SAN
   - Connection test masked this because `SyncSettingsView.testConnection()`
     creates a fresh `TransportManager` without Bonjour, falling back to the
     configured VPN URL (`10.8.0.10`) which matched the cert

2. **WireGuard tunnel misclassified as USB** (`TransportManager.swift`):
   - `handlePathUpdate()` treated `NWInterface.type == .other` as wired ethernet
   - WireGuard's `utun` tunnel interface reports as `.other` on iOS
   - This made `currentTransport = .wired` → `isWired = true` → app sent
     X-Device-ID header instead of JWT Bearer on ALL connections
   - WiFi worked by accident: TCP went via LAN (`192.168.178.x`, outside VPN
     subnet) so nexus-core treated it as local and accepted X-Device-ID
   - Mobile data failed: TCP went via VPN tunnel (`10.8.0.x`, in VPN subnet)
     so nexus-core expected JWT Bearer → 403 "not authenticated"
   - Fix: removed `.other` from wired detection, only check `.wiredEthernet`

3. **GuardianAuthClient TLS session** (`GuardianAuthClient.swift`):
   - Used `URLSession.shared` (no Nexus CA trust) instead of `.nexus`
   - Would have caused TLS failures for Guardian HTTPS calls over VPN
   - Changed default session from `.shared` to `.nexus`

**Files changed**:
- `AthleticPerformance/Views/Sync/Transport/TransportManager.swift` — wired detection
- `AthleticPerformance/Views/Sync/Auth/GuardianAuthClient.swift` — URLSession default
- Server: `/etc/nexus/tls/server.crt` — regenerated with LAN IP in SAN

**Verified working**:
- VPN via mobile data: JWT Bearer auth ✓
- VPN via WiFi: JWT Bearer auth ✓
- USB cable + flight mode: X-Device-ID auth ✓

**Key learnings**:
- WireGuard `utun` interfaces show as `NWInterface.InterfaceType.other` on iOS —
  do NOT treat `.other` as wired ethernet
- `NWPathMonitor` reports all active interfaces including VPN tunnels; filtering
  must be precise to avoid auth method misselection
- When connection tests create isolated instances (e.g. fresh `TransportManager`
  without Bonjour), they may succeed while the real code path fails — test with
  the actual runtime components
- nexus-core `is_local_interface()` decides auth method by source IP: IPs inside
  `NEXUS_VPN_SUBNET` (10.8.0.0/24) require JWT, everything else accepts X-Device-ID

### 2026-03-04: nexus-admin desktop app and provisioning API

**Goal**: Build a macOS admin GUI for iPad onboarding and device management,
plus the server-side API endpoints to support it.

**Part 1 — nexus-core API additions** (`provision_routes.py`):
- `GET /api/v1/provision/devices` — list all registered devices from `sync_device_state`
- `GET /api/v1/provision/code-status/{code}` — poll whether a setup code has been claimed
- `GET /api/v1/provision/devices/{device_id}/syncs` — sync history from `sync_operation`
  (direction, records sent/accepted, conflicts, errors, duration, timestamp)
- All endpoints behind `_require_local` guard
- Added `server_url` config field to `Settings` for provisioning config bundles

**Part 2 — nexus-admin PySide6 desktop app** (new repo at `nexus-admin/`):
- `main_window.py`: QMainWindow with sidebar ("Devices", "Onboarding") + QStackedWidget
- `panels/devices.py`: device overview table (Name, Status, Registered) with click-to-expand
  sync history table (Direction, Sent, Accepted, Conflicts, Errors, Duration, Completed)
- `panels/onboarding.py`: state machine (IDLE → CODE\_GENERATED → CLAIMED/EXPIRED),
  auto-generated device names (iPad-001, iPad-002, ...), 6-digit code display with countdown,
  QThread polling worker (2s interval)
- `ssh_tunnel.py`: SSH port-forward (`ssh -N -L`) to nexus-core, auto-selects free local port
- `api_client.py`: synchronous httpx client with SSH tunnel or direct TLS connection
- Built with PyInstaller, installed to `/Applications/Nexus Admin.app`

**Connection strategies** (two paths to nexus-core):
1. **iPads** — HTTPS with TLS over VPN (JWT auth) or wired (X-Device-ID auth)
2. **MacBook admin** — SSH tunnel to server, HTTPS with cert verification skipped

**Server deployment details**:
- Code deployed to `/opt/nexus/nexus-core/` (both `src/nexus/` and `nexus/` paths)
- `nexus-sync.service` ExecStart: uvicorn with `--ssl-keyfile` and `--ssl-certfile`
- `NEXUS_TRUSTED_HOSTS` includes `127.0.0.1` for SSH tunnel connections
- `NEXUS_SERVER_URL=https://10.8.0.10:8443` in `/etc/nexus/nexus.env`

**Bugs found and fixed**:
1. **TLS was disabled on server** — `nexus-sync.service` ExecStart had no `--ssl-keyfile`
   or `--ssl-certfile` flags → uvicorn ran plain HTTP → iPads got "Invalid HTTP request"
   when connecting via HTTPS. Fixed by adding TLS flags to systemd service.
2. **SSH tunnel protocol mismatch** — tunnel `local_url` used `http://` but server now
   speaks HTTPS. Changed to `https://` with `verify=False` (SSH encrypts the channel).
3. **`nexus-server.local` hostname not resolving** — added SSH config entry mapping
   to `192.168.178.13`.
4. **Server dual code paths** — server has code at both `src/nexus/` and `nexus/`;
   must deploy to both paths until consolidated.
5. **Device deduplication** — multiple provisioning attempts created duplicate rows;
   admin app deduplicates by `device_name`, keeping most recent registration.

**Key learnings**:
- Server MUST run with TLS for iPad connections; SSH tunnel for admin wraps HTTPS
- Device naming convention: iPad-NNN (auto-incremented by querying existing devices)
- `device_name` is the physical device identifier; `device_id` changes on re-provisioning
- PyInstaller apps launched from Finder don't receive CLI args — defaults must work
- Dark mode: use `palette(mid)` for borders, avoid hardcoded background/text colors

**Verified working**:
- iPad sync via VPN (WiFi + mobile data): HTTPS + JWT ✓
- iPad sync via USB cable (flight mode): HTTPS + X-Device-ID ✓
- Nexus Admin via SSH tunnel: device list, sync history, onboarding flow ✓