#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
IMAGE_TAG=evt02-nextcloud:1
PROJECT=evt02-nextcloud
for command in docker curl; do
  command -v "$command" >/dev/null 2>&1 || {
    printf 'Required command not found: %s\n' "$command" >&2
    exit 1
  }
done
docker compose version >/dev/null 2>&1 || {
  printf 'Docker Compose plugin is required (docker compose).\n' >&2
  exit 1
}

EXPECTED_FILE="$ROOT/organizers/expected.env"
TARBALL="$ROOT/dist/02-nextcloud.tar.gz"
[[ -f "$EXPECTED_FILE" && -f "$TARBALL" ]] || {
  printf 'Run build.sh first; its signed image tarball and expected.env are required.\n' >&2
  exit 1
}
# shellcheck disable=SC1090
source "$EXPECTED_FILE"

if (( EUID == 0 )); then
  INSTALL_ROOT=${EVENT_INSTALL_ROOT:-/opt/homelab-event}
else
  INSTALL_ROOT=${EVENT_INSTALL_ROOT:-"$HOME/homelab-event"}
fi
DEPLOY_DIR="$INSTALL_ROOT/02-nextcloud"
docker load -i "$TARBALL"
loaded_id="$(docker image inspect "$IMAGE_TAG" --format '{{.Id}}')"
[[ "$loaded_id" == "$EXPECTED_IMAGE_ID" ]] || {
  printf 'Loaded image ID does not match the signed event image. Aborting.\n' >&2
  exit 1
}

if [[ -f "$DEPLOY_DIR/docker-compose.yml" ]]; then
  docker compose -p "$PROJECT" -f "$DEPLOY_DIR/docker-compose.yml" down --volumes --remove-orphans || true
fi
for data_dir in db nextcloud; do
  if [[ -d "$DEPLOY_DIR/$data_dir" ]]; then
    docker run --rm --user 0:0 --entrypoint /bin/sh \
      -v "$DEPLOY_DIR/$data_dir:/data" "$IMAGE_TAG" \
      -c 'find /data -mindepth 1 -delete'
  fi
done
rm -rf -- "$DEPLOY_DIR"
mkdir -p "$DEPLOY_DIR"/{db,nextcloud}
cp "$ROOT/player-stack/docker-compose.yml" "$DEPLOY_DIR/docker-compose.yml"

compose=(docker compose -p "$PROJECT" -f "$DEPLOY_DIR/docker-compose.yml")
"${compose[@]}" up -d
URL=http://127.0.0.1:8102
ready=0
for _ in $(seq 1 180); do
  if curl -fsS --max-time 3 "$URL/status.php" >/dev/null 2>&1; then
    ready=1
    break
  fi
  sleep 1
done
(( ready == 1 )) || {
  printf 'Nextcloud did not become responsive at %s. Check docker compose logs.\n' "$URL" >&2
  exit 1
}

CANARY_USER=evt-reader
CANARY_PASSWORD=CanaryRead-2026!
"${compose[@]}" exec -T -e OC_PASS="$CANARY_PASSWORD" nextcloud \
  php occ user:add --password-from-env --display-name='Event Reader' "$CANARY_USER"
curl -fsS --max-time 30 -u "$CANARY_USER:$CANARY_PASSWORD" \
  -T "$ROOT/seed/canary.txt" \
  "$URL/remote.php/dav/files/$CANARY_USER/canary.txt" >/dev/null
"${compose[@]}" exec -T nextcloud php occ user:delete evt-bootstrap >/dev/null

printf 'Nextcloud is ready at http://localhost:8102\n'
printf 'Working state: the login screen loads and the seeded account can read its WebDAV file.\n'