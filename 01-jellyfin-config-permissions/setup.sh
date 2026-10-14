#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
IMAGE_TAG=evt01-jellyfin:1
PROJECT=evt01-jellyfin

for command in docker curl jq; do
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
TARBALL="$ROOT/dist/01-jellyfin.tar.gz"
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
DEPLOY_DIR="$INSTALL_ROOT/01-jellyfin"

docker load -i "$TARBALL"
loaded_id="$(docker image inspect "$IMAGE_TAG" --format '{{.Id}}')"
[[ "$loaded_id" == "$EXPECTED_IMAGE_ID" ]] || {
  printf 'Loaded image ID does not match the signed event image. Aborting.\n' >&2
  exit 1
}

if [[ -f "$DEPLOY_DIR/docker-compose.yml" ]]; then
  docker compose -p "$PROJECT" -f "$DEPLOY_DIR/docker-compose.yml" down --volumes --remove-orphans || true
fi
mkdir -p "$(dirname -- "$DEPLOY_DIR")"
for data_dir in config cache media; do
  if [[ -d "$DEPLOY_DIR/$data_dir" ]]; then
    docker run --rm --user 0:0 \
      --entrypoint /bin/chown \
      -v "$DEPLOY_DIR/$data_dir:/data" "$IMAGE_TAG" \
      -R 1000:1000 /data
  fi
done
rm -rf -- "$DEPLOY_DIR"
mkdir -p "$DEPLOY_DIR"/{config,cache,media}
cp "$ROOT/player-stack/docker-compose.yml" "$DEPLOY_DIR/docker-compose.yml"
chown -R 1000:1000 "$DEPLOY_DIR/config" "$DEPLOY_DIR/cache" "$DEPLOY_DIR/media"
chmod 0755 "$DEPLOY_DIR/config" "$DEPLOY_DIR/cache" "$DEPLOY_DIR/media"

compose=(docker compose -p "$PROJECT" -f "$DEPLOY_DIR/docker-compose.yml")
"${compose[@]}" up -d
URL=http://127.0.0.1:8101
ready=0
for _ in $(seq 1 120); do
  if curl -fsS "$URL/System/Info/Public" >/dev/null 2>&1; then
    ready=1
    break
  fi
  sleep 1
done
(( ready == 1 )) || {
  printf 'Jellyfin did not become responsive at %s. Check docker compose logs.\n' "$URL" >&2
  exit 1
}

ffmpeg=/usr/lib/jellyfin-ffmpeg/ffmpeg
for title in EVENT-CANARY-01 EVENT-CANARY-02; do
  docker run --rm --user 1000:1000 \
    --entrypoint "$ffmpeg" \
    -v "$DEPLOY_DIR/media:/media" "$IMAGE_TAG" \
    -hide_banner -loglevel error -f lavfi -i 'color=c=black:s=64x64:r=1' \
    -t 2 -c:v mpeg4 -q:v 10 "/media/${title}.mp4"
done

post_json() {
  local response_file status
  response_file="$(mktemp)"
  for _ in $(seq 1 180); do
    status="$(curl -sS --max-time 10 -o "$response_file" -w '%{http_code}' \
      -X POST "$1" -H 'Content-Type: application/json' --data "$2" || true)"
    if [[ "$status" =~ ^2[0-9][0-9]$ ]]; then
      rm -f "$response_file"
      return 0
    fi
    if [[ ! "$status" =~ ^(000|502|503|504)$ ]]; then
      printf 'Jellyfin setup API at %s returned HTTP %s.\n' "$1" "$status" >&2
      rm -f "$response_file"
      return 1
    fi
    sleep 1
  done
  rm -f "$response_file"
  printf 'Jellyfin remained busy initializing its server.\n' >&2
  return 1
}

post_json "$URL/Startup/Configuration" \
  '{"UICulture":"en-US","MetadataCountryCode":"US","PreferredMetadataLanguage":"en"}'
curl -fsS "$URL/Startup/User" >/dev/null
post_json "$URL/Startup/User" \
  '{"Name":"evt-admin","Password":"EvtCanary-2026!"}'
post_json "$URL/Startup/Complete" '{}'

auth_header='MediaBrowser Client="Event Setup", Device="Organizer", DeviceId="evt01-setup", Version="1"'
token="$(curl -fsS -X POST "$URL/Users/AuthenticateByName" \
  -H 'Content-Type: application/json' -H "Authorization: $auth_header" \
  --data '{"Username":"evt-admin","Pw":"EvtCanary-2026!"}' | jq -er '.AccessToken')"
auth_header="MediaBrowser Client=\"Event Setup\", Device=\"Organizer\", DeviceId=\"evt01-setup\", Version=\"1\", Token=\"$token\""
curl -fsS -o /dev/null -X POST \
  "$URL/Library/VirtualFolders?name=EVENT-CANARY&collectionType=movies&paths=%2Fmedia&refreshLibrary=false" \
  -H "Authorization: $auth_header" -H 'Content-Type: application/json' \
  --data '{"LibraryOptions":{}}'

library_ready=0
for _ in $(seq 1 30); do
  if curl -fsS "$URL/Library/VirtualFolders" -H "Authorization: $auth_header" \
    | jq -e 'any(.[]; .Name == "EVENT-CANARY")' >/dev/null 2>&1; then
    library_ready=1
    break
  fi
  sleep 1
done
(( library_ready == 1 )) || {
  printf 'The EVENT-CANARY library was not created successfully.\n' >&2
  exit 1
}

printf 'Jellyfin is ready at http://localhost:8101\n'
printf 'Working state: the setup wizard is complete and the EVENT-CANARY library is present.\n'