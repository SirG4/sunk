#!/usr/bin/env bash
set -euo pipefail

PROJECT=evt01-jellyfin
if [[ -f /opt/homelab-event/01-jellyfin/docker-compose.yml ]]; then
  DEPLOY_DIR=/opt/homelab-event/01-jellyfin
elif [[ -f "$HOME/homelab-event/01-jellyfin/docker-compose.yml" ]]; then
  DEPLOY_DIR="$HOME/homelab-event/01-jellyfin"
elif [[ -n "${SUDO_USER:-}" ]]; then
  user_home="$(getent passwd "$SUDO_USER" | cut -d: -f6)"
  DEPLOY_DIR="$user_home/homelab-event/01-jellyfin"
else
  printf 'Could not locate the deployed Jellyfin stack.\n' >&2
  exit 1
fi
[[ -f "$DEPLOY_DIR/docker-compose.yml" ]] || {
  printf 'Could not locate the deployed Jellyfin stack.\n' >&2
  exit 1
}

compose=(docker compose -p "$PROJECT" -f "$DEPLOY_DIR/docker-compose.yml")
"${compose[@]}" down
docker run --rm --user 0:0 \
  --entrypoint /bin/chown \
  -v "$DEPLOY_DIR/config:/config" evt01-jellyfin:1 \
  -R 0:0 /config
"${compose[@]}" up -d
printf 'Scenario fault planted. Jellyfin will fail to start; inspect docker compose logs.\n'