# ADR-005: Wired iPad Onboarding and Dual-Transport Sync

> Date: 2026-03-03 | Status: ACCEPTED

## Context

The original architecture required iPads to know 6+ sensitive parameters
(WireGuard keys, two server URLs, device_id, password) — all manually
delivered and entered. This was error-prone, insecure, and exposed network
topology to field devices.

USB cables create a standard local network interface between iPad and host
(automatic on macOS, `usbmuxd`/`ipheth` on Ubuntu). HTTP and Bonjour/mDNS
work natively over this interface. This enables zero-configuration onboarding
and sync.

## Decision

Introduce **wired USB as the primary transport**. VPN remains available for
remote use. Automate onboarding via one-time setup codes over wired
connections.

### Two Deployment Tiers

| Tier | Host | Components | Wired | VPN | Onboarding |
|------|------|-----------|:-----:|:---:|:----------:|
| **Full Nexus** | Ubuntu | nexus-core + Guardian + WireGuard | Yes | Yes | Yes |
| **Local Nexus** | Mac | nexus-core + PostgreSQL | Yes | No | Yes (simplified) |

### Auth by Transport

| Transport | Auth | Trust model |
|-----------|------|-------------|
| Wired (USB) | `X-Device-ID` header (device_id only) | Physical cable = trust |
| VPN (WireGuard) | JWT Bearer token (existing flow) | Cryptographic identity |

## Architecture

```
  ┌──────────┐    USB cable    ┌──────────────────┐          ┌─────────────┐
  │  iPad    │────────────────►│  Ubuntu Server   │  VPN     │  nexus-gate │
  │          │  X-Device-ID    │  nexus-core      │◄─────────│  Guardian   │
  │          │                 │  avahi (Bonjour)  │  JWT     │  :8080      │
  └──────────┘                 └──────────────────┘          └─────────────┘

  ┌──────────┐    USB cable    ┌──────────────────┐
  │  iPad    │────────────────►│  Mac             │  (no VPN, no Guardian)
  │          │  X-Device-ID    │  nexus-core      │
  └──────────┘                 └──────────────────┘
```

iPad discovers host via Bonjour (`_nexus._tcp`), prefers wired over VPN
automatically.

## Onboarding Flow

1. Admin runs `nexus-core provision --generate-code --name "ipad-01"` → gets
   6-digit code (5 min TTL)
2. iPad connected via USB → discovers `_nexus._tcp` via NWBrowser
3. iPad shows setup screen → user enters 6-digit code
4. iPad sends `POST /api/v1/provision/claim` with code + WireGuard public key
5. nexus-core validates code, then calls Guardian `POST /admin/provision` to
   register device + add WG peer (full tier only)
6. nexus-core registers device in `sync_device_state`
7. Returns config bundle: device_id, password, server URLs, WireGuard config
8. iPad stores all in Keychain (invisible to user), code is invalidated

**Mac variant**: Same flow but config bundle has no Guardian URL, no password,
no WireGuard config.

## Wired Sync Flow

Same sync protocol (push/pull/upload/download) — no endpoint changes. Only
the auth layer differs:

- **Wired**: `X-Device-ID` header, server verifies source is local/USB
  interface (not VPN subnet)
- **VPN**: JWT Bearer token (existing, unchanged)

Dual-auth middleware in nexus-core selects strategy based on source IP:
- From VPN subnet (10.10.0.0/24) → require JWT
- From local/USB interface → accept `X-Device-ID` header

## Security

| Threat | Mitigation |
|--------|-----------|
| VPN device sends forged X-Device-ID | Server checks source IP — VPN subnet → JWT required |
| Unknown iPad plugged in via USB | device_id must exist in `sync_device_state` |
| Unauthorized onboarding | 6-digit setup code, 5 min TTL, single use, admin-generated |
| Stolen iPad (wired) | `is_active = false` blocks both wired and VPN |
| Provisioning endpoint abuse | Bound to local/USB interface only, not VPN |

## Implementation

Seven phases implemented across nexus-core, nexus-gate, and AthleticPerformance:

1. **Dual-Auth Middleware** (nexus-core) — `transport.py`: `is_local_interface()` +
   `get_current_device_dual()`, routing by source IP
2. **Provisioning Module** (nexus-core) — `provision.py` + `provision_routes.py`:
   code generation, validation, claim endpoint
3. **Guardian Admin API** (nexus-gate) — `admin.py`: `POST /admin/provision`
   for device registration + WireGuard peer creation
4. **Bonjour Service Advertisement** — avahi service file (Ubuntu) + Python
   zeroconf (Mac) for `_nexus._tcp` discovery
5. **iPad TransportManager** — `TransportManager.swift` + `BonjourBrowser.swift`:
   NWPathMonitor for wired detection, NWBrowser for discovery, dual-auth in
   `NexusSyncClient`
6. **iPad Onboarding UI** — `OnboardingView.swift` + `OnboardingClient.swift`:
   connection status, 6-digit code entry, automatic provisioning
7. **Documentation** — This ADR + updates to architecture docs

## Consequences

**Positive:**
- Zero-config iPads — 30-second onboarding replaces manual credential entry
- Mac development support without VPN/Guardian infrastructure
- Reduced attack surface — sensitive credentials never visible to operators
- Backward-compatible — VPN still works for remote use

**Negative:**
- Dual-auth complexity in middleware (two code paths)
- USB interface behavior varies across OS versions
- Bonjour/avahi dependency on Ubuntu servers

**Risk:**
- USB network reliability needs real-hardware testing (iPadOS versions, cable
  types, Linux kernels)
- NWBrowser over USB may have edge cases with device sleep/wake
