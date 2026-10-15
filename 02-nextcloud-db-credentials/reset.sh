#!/usr/bin/env bash
set -euo pipefail

PROJECT=evt02-nextcloud
candidates=(/opt/homelab-event/02-nextcloud "$HOME/homelab-event/02-nextcloud")
if [[ -n "${SUDO_USER:-}" ]]; then
  user_home="$(getent passwd "$SUDO_USER" | cut -d: -f6)"
  candidates+=("$user_home/homelab-event/02-nextcloud")
fi

for deploy_dir in "${candidates[@]}"; do
  [[ -f "$deploy_dir/docker-compose.yml" ]] || continue
  docker compose -p "$PROJECT" -f "$deploy_dir/docker-compose.yml" down --volumes --remove-orphans
  for data_dir in db nextcloud; do
    if [[ -d "$deploy_dir/$data_dir" ]]; then
      docker run --rm --user 0:0 --entrypoint /bin/sh \
        -v "$deploy_dir/$data_dir:/data" evt02-nextcloud:1 \
        -c 'find /data -mindepth 1 -delete'
    fi
  done
  rm -rf -- "$deploy_dir"
done
docker image rm evt02-nextcloud:1 >/dev/null 2>&1 || true
printf 'Nextcloud scenario deployment and event image removed.\n'