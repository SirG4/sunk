#!/usr/bin/env bash
set -euo pipefail

PROJECT=evt02-nextcloud
if [[ -f /opt/homelab-event/02-nextcloud/docker-compose.yml ]]; then
  DEPLOY_DIR=/opt/homelab-event/02-nextcloud
elif [[ -f "$HOME/homelab-event/02-nextcloud/docker-compose.yml" ]]; then
  DEPLOY_DIR="$HOME/homelab-event/02-nextcloud"
elif [[ -n "${SUDO_USER:-}" ]]; then
  user_home="$(getent passwd "$SUDO_USER" | cut -d: -f6)"
  DEPLOY_DIR="$user_home/homelab-event/02-nextcloud"
else
  printf 'Could not locate the deployed Nextcloud stack.\n' >&2
  exit 1
fi
[[ -f "$DEPLOY_DIR/docker-compose.yml" ]] || {
  printf 'Could not locate the deployed Nextcloud stack.\n' >&2
  exit 1
}

compose=(docker compose -p "$PROJECT" -f "$DEPLOY_DIR/docker-compose.yml")
"${compose[@]}" exec -T nextcloud php occ config:system:set dbpassword \
  --value='PlantedMismatch-2026!'
"${compose[@]}" restart nextcloud >/dev/null
curl -sS --max-time 8 http://127.0.0.1:8102/ >/dev/null 2>&1 || true
printf 'Scenario fault planted. The Nextcloud web page should show a database connection error.\n'