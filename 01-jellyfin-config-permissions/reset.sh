#!/usr/bin/env bash
set -euo pipefail

PROJECT=evt01-jellyfin
candidates=(/opt/homelab-event/01-jellyfin "$HOME/homelab-event/01-jellyfin")
if [[ -n "${SUDO_USER:-}" ]]; then
  user_home="$(getent passwd "$SUDO_USER" | cut -d: -f6)"
  candidates+=("$user_home/homelab-event/01-jellyfin")
fi

for deploy_dir in "${candidates[@]}"; do
  [[ -f "$deploy_dir/docker-compose.yml" ]] || continue
  docker compose -p "$PROJECT" -f "$deploy_dir/docker-compose.yml" \
    down --volumes --remove-orphans
  rm -rf -- "$deploy_dir"
done
docker image rm evt01-jellyfin:1 >/dev/null 2>&1 || true
printf 'Jellyfin scenario deployment and event image removed.\n'