# ADR-001: No Docker or Cloud Services

> Date: 2026-02-13 | Status: ACCEPTED

## Context

The Nexus platform needs a deployment and process management strategy.
Common modern approaches include Docker/containers, Kubernetes, and cloud
platforms (AWS, GCP, Azure).

## Decision

Nexus will run on bare metal Linux using systemd for process management.
No Docker, no containers, no cloud services.

## Reasons

1. **Simplicity** — systemd is native to Ubuntu, well-understood, and has no
   additional abstraction layer. One fewer thing to debug.

2. **Performance** — No container overhead. PostgreSQL in particular benefits
   from direct hardware access (shared buffers, huge pages, disk I/O).

3. **Sovereignty** — All data stays on owned hardware. No cloud provider
   dependencies, no egress costs, no service discontinuation risks.

4. **Debuggability** — `journalctl`, `systemctl`, `htop`, `pg_stat_activity`
   work directly. No need to exec into containers or manage volumes.

5. **Security surface** — Docker daemon runs as root and adds attack surface.
   systemd services can run as unprivileged users natively.

6. **Team size** — This is a solo/small team project. Container orchestration
   adds operational complexity that's only justified at scale.

## Consequences

- Deployment is via rsync + systemd restart (simple but manual)
- Environment isolation via Python virtual environments (uv) and PostgreSQL roles
- Server provisioning documented in setup scripts, not Dockerfiles
- Scaling means bigger hardware or additional servers, not container replicas
- Must be disciplined about dependency management (no container isolation)

## Alternatives Considered

- **Docker Compose** — Would simplify multi-service setup but adds complexity
  for a single-server deployment. Revisit if multiple servers are needed.
- **Cloud hosting** — Violates sovereignty requirement and adds recurring costs.
