# Nexus Authentication Protocol

> Last updated: 2026-02-15
> Status: ACTIVE — Guardian implements this; clients build against it

## Overview

All API access to the Nexus platform requires a JWT bearer token issued by
Guardian (nexus-gate). Devices authenticate with `device_id` + `password`
over the WireGuard VPN. Guardian verifies credentials, validates the source
IP against the device's registered VPN IP, and returns a signed JWT.

The same JWT is accepted by both Guardian and nexus-core — they share the
signing secret (`NEXUS_JWT_SECRET`).

```
iPad / Client                    nexus-gate (Guardian)              nexus-core
     │                                  │                               │
     │  POST /auth/token                │                               │
     │  {device_id, password}           │                               │
     │ ─────────────────────────────►   │                               │
     │                                  │  verify credentials           │
     │                                  │  validate source IP           │
     │                                  │  check rate limit             │
     │  {access_token, expires_in}      │                               │
     │ ◄─────────────────────────────   │                               │
     │                                  │                               │
     │  POST /sync/push                 │                               │
     │  Authorization: Bearer <token>   │                               │
     │ ─────────────────────────────────────────────────────────────►   │
     │                                  │                    verify JWT │
     │                                  │                    extract    │
     │                                  │                    device_id  │
     │  {sync response}                 │                               │
     │ ◄─────────────────────────────────────────────────────────────   │
```

## Guardian Base URL

```
http://nexus-gate.local:8080
```

Guardian listens on `0.0.0.0:8080` and is accessible only from within the
WireGuard VPN subnet (`10.10.0.0/24`). No TLS — the VPN provides encryption.

## Device Registration (Prerequisite)

Before a device can authenticate, it must be registered on the gateway:

```bash
./scripts/register-device.sh <name> <type> <vpn_ip> <wg_public_key>
```

Registration creates:
- A `device_id` (UUID v4)
- A random password (24-byte base64url, shown once, never stored)
- A bcrypt hash of the password (stored in `data/devices.json`)
- A WireGuard peer entry with a fixed VPN IP

The operator must securely deliver the `device_id` and `password` to the
device. These are entered in the device's configuration (e.g., iPad sync
settings) and used for all subsequent authentication requests.

### Device Record

```json
{
  "device_id": "550e8400-e29b-41d4-a716-446655440000",
  "device_name": "ipad-01",
  "device_type": "ipad",
  "wg_public_key": "ABC123...=",
  "vpn_ip": "10.10.0.100",
  "credentials_hash": "$2b$12$...",
  "is_active": true,
  "registered_at": "2026-02-15T10:30:00Z"
}
```

| Field              | Type    | Description                                      |
|--------------------|---------|--------------------------------------------------|
| `device_id`        | UUID    | Unique device identifier (in JWT claims)         |
| `device_name`      | string  | Human-readable name (`ipad-01`, `nexus-mac`)     |
| `device_type`      | enum    | `ipad`, `server`, or `dev`                       |
| `wg_public_key`    | string  | WireGuard public key (base64)                    |
| `vpn_ip`           | string  | Fixed VPN IP address (e.g., `10.10.0.100`)       |
| `credentials_hash` | string  | bcrypt hash of device password                   |
| `is_active`        | boolean | `false` = device revoked, auth always rejected   |
| `registered_at`    | string  | ISO 8601 UTC timestamp                           |

### Device Fingerprint Validation

On every `POST /auth/token` request, Guardian validates:

1. **device_id** — Must exist in the registry
2. **is_active** — Must be `true`
3. **source IP** — The request's source IP (from the VPN tunnel) must
   exactly match the device's registered `vpn_ip`
4. **password** — Must match the stored bcrypt hash

All four checks must pass. Failure at any step returns the same generic
`401 Authentication failed` (no information leakage about which check failed).

---

## Endpoints

### `POST /auth/token` — Authenticate Device

Request a JWT access token.

**Request:**

```http
POST /auth/token HTTP/1.1
Host: nexus-gate.local:8080
Content-Type: application/json

{
  "device_id": "550e8400-e29b-41d4-a716-446655440000",
  "password": "dGhpcyBpcyBhIHRlc3QgcGFzc3dvcmQ"
}
```

| Field       | Type   | Required | Description                          |
|-------------|--------|----------|--------------------------------------|
| `device_id` | string | Yes      | UUID of the registered device        |
| `password`  | string | Yes      | Device password (base64url, 24 bytes)|

**Success Response (200):**

```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "token_type": "bearer",
  "expires_in": 3600
}
```

| Field          | Type   | Description                                   |
|----------------|--------|-----------------------------------------------|
| `access_token` | string | Signed JWT token                              |
| `token_type`   | string | Always `"bearer"`                             |
| `expires_in`   | int    | Token lifetime in seconds (default: 3600)     |

**Error Responses:**

| Status | Detail                            | Cause                                   |
|--------|-----------------------------------|-----------------------------------------|
| 401    | `"Authentication failed"`        | Unknown device, wrong password, or IP mismatch |
| 401    | `"Device is deactivated"`        | Device exists but `is_active` is false  |
| 422    | `"Unprocessable Entity"`         | Missing or invalid request fields       |
| 429    | `"Too many attempts, try later"` | Rate limit exceeded (see below)         |

---

### `GET /auth/verify` — Verify Token

Verify that a Bearer token is valid. Used for integration testing and
health checks — not part of the normal sync flow.

**Request:**

```http
GET /auth/verify HTTP/1.1
Host: nexus-gate.local:8080
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

**Success Response (200):**

```json
{
  "valid": true,
  "device_id": "550e8400-e29b-41d4-a716-446655440000"
}
```

**Error Responses:**

| Status | Detail                   | Cause                     |
|--------|--------------------------|---------------------------|
| 401    | `"Missing Bearer token"` | No `Authorization` header |
| 401    | `"Token has expired"`    | JWT `exp` claim is past   |
| 401    | `"Invalid token"`        | Signature invalid or malformed |

---

### `GET /health` — Service Health

No authentication required. Used by keepalived health checks and client
connectivity probes.

**Request:**

```http
GET /health HTTP/1.1
Host: nexus-gate.local:8080
```

**Response (200):**

```json
{
  "status": "ok",
  "service": "nexus-guardian"
}
```

---

## JWT Token Structure

### Header

```json
{
  "alg": "HS256",
  "typ": "JWT"
}
```

### Payload (Claims)

```json
{
  "device_id": "550e8400-e29b-41d4-a716-446655440000",
  "iat": 1739612400,
  "exp": 1739616000
}
```

| Claim       | Type   | Description                                         |
|-------------|--------|-----------------------------------------------------|
| `device_id` | string | UUID of the authenticated device                    |
| `iat`       | int    | Issued-at timestamp (Unix epoch, UTC)               |
| `exp`       | int    | Expiration timestamp (Unix epoch, UTC)               |

### Signing

- **Algorithm:** HS256 (HMAC-SHA256)
- **Secret:** Shared between Guardian and nexus-core via `NEXUS_JWT_SECRET`
  environment variable. Must be identical on both services.
- **Minimum key length:** 32 bytes (per RFC 7518 Section 3.2)

### Token Lifetime

| Setting                    | Default  | Environment Variable       |
|----------------------------|----------|----------------------------|
| Expiry (Guardian)          | 60 min   | `NEXUS_JWT_EXPIRY_MINUTES` |

Clients must request a new token before the current one expires.
There is no refresh token — re-authenticate with `POST /auth/token`.

---

## Using Tokens with nexus-core

All nexus-core sync API requests require a Bearer token in the
`Authorization` header:

```http
POST /sync/push HTTP/1.1
Host: nexus-server.local:8443
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
Content-Type: application/json
```

nexus-core validates the token independently (same shared secret) and
extracts `device_id` to identify the calling device. It additionally
verifies that the device exists and is active in its own device state
table (`staging.sync_device_state`).

**nexus-core auth errors:**

| Status | Detail                                   | Cause                           |
|--------|------------------------------------------|---------------------------------|
| 401    | `"Token has expired"`                    | JWT `exp` claim is past         |
| 401    | `"Invalid token"`                        | Signature invalid or malformed  |
| 401    | `"Token missing device_id"`              | JWT payload lacks `device_id`   |
| 401    | `"Invalid device_id in token"`           | `device_id` is not a valid UUID |
| 401    | `"Device not registered or inactive"`    | Device unknown to nexus-core    |
| 403    | (not used currently)                     | Reserved for future RBAC        |

---

## Rate Limiting

Guardian rate-limits `POST /auth/token` per composite key
`{device_id}:{source_ip}`.

### Parameters

| Parameter   | Default    | Environment Variable                 |
|-------------|------------|--------------------------------------|
| Max attempts| 3          | `NEXUS_RATE_LIMIT_MAX_ATTEMPTS`      |
| Window      | 10 minutes | `NEXUS_RATE_LIMIT_WINDOW_SECONDS`    |
| Block time  | 30 minutes | `NEXUS_RATE_LIMIT_BLOCK_SECONDS`     |

### Behavior

1. Each failed authentication increments the attempt counter for
   `{device_id}:{source_ip}`
2. Attempts outside the 10-minute window are discarded
3. After 3 failures within 10 minutes, the key is **blocked for 30 minutes**
4. During a block, all requests return `429` immediately (credentials are
   not checked)
5. A successful authentication resets the counter to zero
6. After the block expires, the counter resets and the device can try again

### Client Handling

When receiving `429 Too many attempts, try later`:

- **Do not retry immediately** — wait at least 30 minutes
- Check the `Retry-After` header if present (seconds until unblock)
- Log the event and surface it to the user (e.g., "Authentication blocked,
  try again in 30 minutes")
- A blocked device triggers a security alert on the gateway (email
  notification if SMTP is configured)

### Alert Triggers

| Event                        | Alert action                     |
|------------------------------|----------------------------------|
| Unknown device_id            | Logged + email alert             |
| IP mismatch                  | Logged + email alert             |
| 3rd failed attempt (blocked) | Logged + email alert             |
| Rate limit exceeded          | Logged + email alert             |

All incidents are recorded in `data/incidents.json` on the gateway.

---

## Client Implementation Guide

### Authentication Flow

```
1. Load device_id and password from secure storage
2. POST /auth/token with credentials
3. On 200: store access_token securely, note expires_in
4. On 401: surface error to user (wrong credentials or device revoked)
5. On 429: back off for block duration, surface to user
6. Use token for all nexus-core API calls
7. On 401 from nexus-core: token expired → re-authenticate (go to step 2)
8. Proactively re-authenticate before expiry (e.g., at 80% of expires_in)
```

### Token Storage

| Platform | Storage mechanism                              |
|----------|------------------------------------------------|
| iPad     | iOS Keychain (service: `com.athletic-performance.nexus-sync`, account: `jwt`) |
| macOS    | macOS Keychain or environment variable         |
| Server   | Environment variable or secrets file           |

Tokens must never be written to:
- UserDefaults / NSUserDefaults
- Plain text files in the app sandbox
- Logs or analytics payloads

### Token Lifecycle

```
┌─────────────┐     POST /auth/token      ┌──────────────┐
│  No token   │ ────────────────────────►  │  Has token   │
│  (startup)  │     200 + access_token     │  (active)    │
└─────────────┘                            └──────┬───────┘
       ▲                                          │
       │            401 from nexus-core           │
       │  ◄───────────────────────────────────────┘
       │            (token expired/invalid)
       │
       │     Re-authenticate with stored credentials
       └──────────────────────────────────────────
```

### Error Handling Matrix

| Error from         | Status | Client action                              |
|--------------------|--------|--------------------------------------------|
| Guardian `/auth/token` | 401 | Show "authentication failed" to user       |
| Guardian `/auth/token` | 429 | Back off 30 min, show "temporarily blocked"|
| Guardian `/auth/token` | 422 | Developer bug — fix request payload        |
| nexus-core (any)   | 401    | Delete stored token, re-authenticate       |
| nexus-core (any)   | 429    | Parse `Retry-After`, back off accordingly  |
| Network error      | —      | Queue operation for retry when VPN is back |

### Proactive Re-authentication

Clients should re-authenticate before the token expires to avoid failed
sync operations. Recommended approach:

1. Store the token's `expires_in` value alongside the token
2. Track when the token was obtained
3. Re-authenticate when 80% of the lifetime has elapsed (e.g., at 48 min
   for a 60 min token)
4. If re-authentication fails, continue using the existing token until
   it actually expires

---

## Security Considerations

### Shared Secret

The `NEXUS_JWT_SECRET` must be:
- At least 32 bytes (256 bits) — enforced by RFC 7518 for HS256
- Identical on nexus-gate and nexus-core
- Generated with a cryptographically secure random generator
- Stored in environment files (`/opt/nexus-gate/.env` and
  `/etc/nexus/nexus.env`), not in source control

### IP Binding

Tokens are not bound to a specific IP after issuance. The IP check happens
only at authentication time. This is intentional — it allows tokens to
survive gateway failover (the VPN IP doesn't change, but the physical
gateway may).

### Device Revocation

To revoke a device:

1. Deactivate in Guardian: set `is_active: false` in `data/devices.json`
2. Remove WireGuard peer: `manage-peers.sh remove <name>`
3. Outstanding tokens remain valid until they expire (max 60 min)
4. nexus-core also checks device state — deactivate there for immediate
   rejection of sync API calls

### Password Handling

- Passwords are generated server-side (24-byte `secrets.token_urlsafe`)
- Stored as bcrypt hash (`$2b$12$...`) — never in plaintext
- Shown once during registration — operator must deliver securely
- No password change endpoint — re-register the device to rotate

### Failover

Both gateway nodes (if failover is configured) share:
- The same `NEXUS_JWT_SECRET`
- The same `data/devices.json` (synced via rsync)

Tokens issued by one node are valid on the other. Clients do not need
to re-authenticate after a gateway failover.

---

## Configuration Reference

### Guardian (nexus-gate) Environment Variables

| Variable                          | Default       | Description                     |
|-----------------------------------|---------------|---------------------------------|
| `NEXUS_JWT_SECRET`                | *(required)*  | JWT signing key (≥32 bytes)    |
| `NEXUS_JWT_ALGORITHM`             | `HS256`       | JWT signing algorithm           |
| `NEXUS_JWT_EXPIRY_MINUTES`        | `60`          | Token lifetime in minutes       |
| `NEXUS_GUARDIAN_HOST`             | `0.0.0.0`     | Listen address                  |
| `NEXUS_GUARDIAN_PORT`             | `8080`        | Listen port                     |
| `NEXUS_RATE_LIMIT_MAX_ATTEMPTS`   | `3`           | Failed attempts before block    |
| `NEXUS_RATE_LIMIT_WINDOW_SECONDS` | `600`         | Sliding window (10 min)         |
| `NEXUS_RATE_LIMIT_BLOCK_SECONDS`  | `1800`        | Block duration (30 min)         |

### nexus-core Environment Variables

| Variable               | Default       | Description                     |
|------------------------|---------------|---------------------------------|
| `NEXUS_JWT_SECRET`     | *(required)*  | Must match Guardian's secret    |
| `NEXUS_JWT_ALGORITHM`  | `HS256`       | Must match Guardian's algorithm |
