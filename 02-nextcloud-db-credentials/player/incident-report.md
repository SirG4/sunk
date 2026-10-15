# Incident Report: INC-0002
**Service:** Nextcloud
**Reported by:** Collaboration Services Monitor
**Severity:** Medium
**Status:** Open

## Summary
The Nextcloud page now shows an error instead of the login screen. Restarting the stack did not restore service. Users cannot reach their files while the service is unavailable.

## Environment
- Host: lab PC, Docker + Docker Compose
- Stack location: `/opt/homelab-event/02-nextcloud` (or `~/homelab-event/02-nextcloud`)
- Service URL (when healthy): http://localhost:8102

## What was observed
- The service was available earlier today and then began returning an error page.
- The Nextcloud container remains running, but its application log records an SQLSTATE access-denied error for the `nextcloud` database user.
- The stack includes a MariaDB service and a persistent Nextcloud directory.

## Your task
Restore the service to a fully working state using the provided stack. From the stack directory, use `docker compose ps` and `docker compose logs nextcloud` to investigate, and inspect `/var/www/html/data/nextcloud.log` inside the container for the application error (`docker compose exec nextcloud tail -n 50 /var/www/html/data/nextcloud.log`). Stop the stack with `docker compose down` and start it with `docker compose up -d` as needed. When you believe it is fixed, call a volunteer to verify.