# Incident Report: INC-0001
**Service:** Jellyfin
**Reported by:** Media Services Monitor
**Severity:** Medium
**Status:** Open

## Summary
Jellyfin stopped responding after a maintenance window. The web page at the local service address does not load, and restarting the stack has not restored access.

## Environment
- Host: lab PC, Docker + Docker Compose
- Stack location: `/opt/homelab-event/01-jellyfin` (or `~/homelab-event/01-jellyfin`)
- Service URL (when healthy): http://localhost:8101

## What was observed
- The service was available earlier, then became unreachable after a host maintenance task.
- The container repeatedly exits and restarts.
- `docker compose ps` does not show Jellyfin staying up.

## Your task
Restore the service to a fully working state using the provided stack. From the stack directory, inspect it with `docker compose logs` and start or restart it with `docker compose up -d`. When you believe it is fixed, call a volunteer to verify.