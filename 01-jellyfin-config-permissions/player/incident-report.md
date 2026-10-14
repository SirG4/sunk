# Incident Report: INC-0001
**Service:** Jellyfin
**Reported by:** Media Services Monitor
**Severity:** Medium
**Status:** Open

## Summary
Jellyfin stopped responding after the service data was restored from a host backup during scheduled maintenance. The web page at the local service address does not load, and restarting the stack has not restored access. The startup error refers to a database file under Jellyfin's persistent configuration storage.

## Environment
- Host: lab PC, Docker + Docker Compose
- Stack location: `/opt/homelab-event/01-jellyfin` (or `~/homelab-event/01-jellyfin`)
- Service URL (when healthy): http://localhost:8101

## What was observed
- The service was available before the backup restore and became unreachable immediately afterward.
- The container repeatedly exits and restarts.
- The startup log reports that SQLite cannot write to its database under `/config`.
- The compose file maps a host directory to `/config`; inspect the mounted directory and the service's ability to use its persistent files.

## Your task
Restore the service to a fully working state using the provided stack. From the stack directory, use `docker compose ps` and `docker compose logs jellyfin` to investigate. You can stop the stack with `docker compose down` and start it with `docker compose up -d`. When you believe it is fixed, call a volunteer to verify.