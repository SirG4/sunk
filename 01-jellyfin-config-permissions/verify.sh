#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT=evt01-jellyfin
URL=http://127.0.0.1:8101
failed=0

for command in docker curl jq stat find; do
  command -v "$command" >/dev/null 2>&1 || {
    printf '[FAIL] required command unavailable\n'
    printf 'RESULT: FAIL\n'
    exit 1
  }
done
docker compose version >/dev/null 2>&1 || {
  printf '[FAIL] Docker Compose plugin unavailable\n'
  printf 'RESULT: FAIL\n'
  exit 1
}

EXPECTED_FILE="$ROOT/organizers/expected.env"
if [[ ! -f "$EXPECTED_FILE" ]]; then
  printf '[FAIL] expected event image metadata is unavailable\n'
  printf 'RESULT: FAIL\n'
  exit 1
fi
# shellcheck disable=SC1090
source "$EXPECTED_FILE"

if [[ -f /opt/homelab-event/01-jellyfin/docker-compose.yml ]]; then
  DEPLOY_DIR=/opt/homelab-event/01-jellyfin
elif [[ -n "${SUDO_USER:-}" ]]; then
  user_home="$(getent passwd "$SUDO_USER" | cut -d: -f6)"
  DEPLOY_DIR="$user_home/homelab-event/01-jellyfin"
else
  DEPLOY_DIR="$HOME/homelab-event/01-jellyfin"
fi
COMPOSE_FILE="$DEPLOY_DIR/docker-compose.yml"
if [[ ! -f "$COMPOSE_FILE" ]]; then
  printf '[FAIL] deployed stack is missing\n'
  printf 'RESULT: FAIL\n'
  exit 1
fi
compose=(docker compose -p "$PROJECT" -f "$COMPOSE_FILE")
cid="$("${compose[@]}" ps -q jellyfin 2>/dev/null || true)"

record() {
  if [[ "$1" == pass ]]; then
    printf '[PASS] %s\n' "$2"
  else
    printf '[FAIL] %s\n' "$2"
    failed=1
  fi
}

if [[ -n "$cid" ]] && [[ "$(docker inspect -f '{{.Image}}' "$cid" 2>/dev/null || true)" == "$EXPECTED_IMAGE_ID" ]]; then
  record pass 'service uses the original event image ID'
  actual_sig="$(docker exec "$cid" cat "$EXPECTED_SIG_PATH" 2>/dev/null || true)"
  [[ "$actual_sig" == "$EXPECTED_SIG" ]] && record pass 'event image signature matches' \
    || record fail 'event image signature mismatch'
else
  record fail 'service is not running the original event image'
  record fail 'event image signature could not be checked'
fi

if curl -fsS --max-time 3 "$URL/System/Info/Public" >/dev/null 2>&1; then
  record pass 'Jellyfin responds on 127.0.0.1:8101'
else
  record fail 'Jellyfin is not responding on 127.0.0.1:8101'
fi

config_json="$("${compose[@]}" config --format json 2>/dev/null || true)"
if [[ -n "$config_json" ]] && jq -e '
  ([.services[].ports[]?] | length > 0)
  and all(.services[].ports[]?; .host_ip == "127.0.0.1")
  and ([.services[].ports[]? | select((.published | tostring) == "8101")] | length == 1)
  and all(.services[]; .privileged != true and .network_mode != "host")
' <<<"$config_json" >/dev/null 2>&1; then
  record pass 'published ports remain localhost-only and the service is unprivileged'
else
  record fail 'port binding or container privilege settings are unsafe'
fi

if [[ -n "$cid" ]] && [[ -d "$DEPLOY_DIR/config" ]] \
  && ! find "$DEPLOY_DIR/config" -perm -0002 -print -quit | grep -q . \
  && docker exec "$cid" sh -c 'test -w /config && test -w /config/data' >/dev/null 2>&1; then
  record pass 'Jellyfin can write persistent config without world-writable directories'
else
  record fail 'persistent config is not writable or has world-writable directories'
fi

authenticate() {
  local token
  token="$(curl -fsS --max-time 3 -X POST "$URL/Users/AuthenticateByName" \
    -H 'Content-Type: application/json' \
    -H 'Authorization: MediaBrowser Client="Event Verifier", Device="Volunteer", DeviceId="evt01-check", Version="1"' \
    --data '{"Username":"evt-admin","Pw":"EvtCanary-2026!"}' 2>/dev/null \
    | jq -er '.AccessToken' 2>/dev/null)" || return 1
  printf 'MediaBrowser Client="Event Verifier", Device="Volunteer", DeviceId="evt01-check", Version="1", Token="%s"' "$token"
}

check_canaries() {
  local auth_header libraries
  for _ in $(seq 1 30); do
    auth_header="$(authenticate)" || { sleep 1; continue; }
    libraries="$(curl -fsS --max-time 3 "$URL/Library/VirtualFolders" \
      -H "Authorization: $auth_header" 2>/dev/null)" || { sleep 1; continue; }
    jq -e 'any(.[]; .Name == "EVENT-CANARY")' <<<"$libraries" >/dev/null 2>&1 && return 0
    return 1
  done
  return 1
}

wait_for_api() {
  for _ in $(seq 1 90); do
    if curl -fsS --max-time 2 "$URL/System/Info/Public" >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
  done
  return 1
}

if curl -fsS --max-time 3 "$URL/System/Info/Public" >/dev/null 2>&1 && check_canaries; then
  record pass 'evt-admin login succeeds and EVENT-CANARY is present'
else
  record fail 'admin login or EVENT-CANARY library check failed'
fi

if [[ -n "$cid" ]] && [[ -s "$DEPLOY_DIR/media/EVENT-CANARY-01.mp4" ]] \
  && [[ -s "$DEPLOY_DIR/media/EVENT-CANARY-02.mp4" ]]; then
  record pass 'seed media files remain present'
else
  record fail 'seed media files are missing'
fi

if [[ -n "$cid" ]] && curl -fsS --max-time 3 "$URL/System/Info/Public" >/dev/null 2>&1 \
  && docker exec "$cid" sh -c 'test -w /config && test -w /config/data' >/dev/null 2>&1; then
  if "${compose[@]}" restart jellyfin >/dev/null && wait_for_api; then
    record pass 'service survives a container restart'
    if check_canaries; then
      record pass 'admin login and library still work after restart'
    else
      record fail 'canary data did not survive restart'
    fi
    restarted_cid="$("${compose[@]}" ps -q jellyfin 2>/dev/null || true)"
    if [[ -n "$restarted_cid" ]] \
      && [[ "$(docker inspect -f '{{.Image}}' "$restarted_cid" 2>/dev/null || true)" == "$EXPECTED_IMAGE_ID" ]] \
      && docker exec "$restarted_cid" sh -c 'test -w /config && test -w /config/data' >/dev/null 2>&1; then
      record pass 'event image and writable config remain correct after restart'
    else
      record fail 'image or config permissions changed after restart'
    fi
  else
    record fail 'service did not recover after a container restart'
  fi
else
  record fail 'restart persistence could not be checked'
fi

if (( failed == 0 )); then
  printf 'RESULT: PASS\n'
  exit 0
fi
printf 'RESULT: FAIL\n'
exit 1