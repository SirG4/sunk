#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT=evt02-nextcloud
URL=http://127.0.0.1:8102
CANARY_USER=evt-reader
CANARY_PASSWORD=CanaryRead-2026!
failed=0

for command in docker curl jq; do
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

if [[ -f /opt/homelab-event/02-nextcloud/docker-compose.yml ]]; then
  DEPLOY_DIR=/opt/homelab-event/02-nextcloud
elif [[ -n "${SUDO_USER:-}" ]]; then
  user_home="$(getent passwd "$SUDO_USER" | cut -d: -f6)"
  DEPLOY_DIR="$user_home/homelab-event/02-nextcloud"
else
  DEPLOY_DIR="$HOME/homelab-event/02-nextcloud"
fi
COMPOSE_FILE="$DEPLOY_DIR/docker-compose.yml"
if [[ ! -f "$COMPOSE_FILE" ]]; then
  printf '[FAIL] deployed stack is missing\n'
  printf 'RESULT: FAIL\n'
  exit 1
fi
compose=(docker compose -p "$PROJECT" -f "$COMPOSE_FILE")
cid="$("${compose[@]}" ps -q nextcloud 2>/dev/null || true)"

record() {
  if [[ "$1" == pass ]]; then
    printf '[PASS] %s\n' "$2"
  else
    printf '[FAIL] %s\n' "$2"
    failed=1
  fi
}

if [[ -n "$cid" ]] && [[ "$(docker inspect -f '{{.Image}}' "$cid" 2>/dev/null || true)" == "$EXPECTED_IMAGE_ID" ]]; then
  record pass 'Nextcloud uses the original event image ID'
  actual_sig="$(docker exec "$cid" cat "$EXPECTED_SIG_PATH" 2>/dev/null || true)"
  [[ "$actual_sig" == "$EXPECTED_SIG" ]] && record pass 'event image signature matches' \
    || record fail 'event image signature mismatch'
else
  record fail 'Nextcloud is not running the original event image'
  record fail 'event image signature could not be checked'
fi

config_json="$("${compose[@]}" config --format json 2>/dev/null || true)"
if [[ -n "$config_json" ]] && jq -e '
  ([.services.nextcloud.ports[]?] | length == 1)
  and (.services.nextcloud.ports[0].host_ip == "127.0.0.1")
  and ((.services.nextcloud.ports[0].published | tostring) == "8102")
  and (.services.nextcloud.privileged != true)
  and (.services.db.privileged != true)
  and (.services.nextcloud.network_mode != "host")
  and (.services.db.network_mode != "host")
' <<<"$config_json" >/dev/null 2>&1; then
  record pass 'localhost-only port and database environment are intact'
else
  record fail 'port binding, privilege settings, or database environment is invalid'
fi

db_cid="$("${compose[@]}" ps -q db 2>/dev/null || true)"
if [[ -n "$cid" && -n "$db_cid" ]] \
  && docker exec "$cid" sh -c 'test -s /var/www/html/config/config.php && test -s "/var/www/html/data/$1/files/canary.txt"' _ "$CANARY_USER" >/dev/null 2>&1 \
  && docker exec "$db_cid" sh -c 'test -d /var/lib/mysql/mysql' >/dev/null 2>&1 \
  && ! docker exec "$cid" sh -c 'find /var/www/html/config -type f -perm -0002 -print -quit | grep -q .' >/dev/null 2>&1 \
  && ! docker exec "$db_cid" sh -c 'find /var/lib/mysql -type f -perm -0002 -print -quit | grep -q .' >/dev/null 2>&1; then
  record pass 'persistent database, configuration, and canary data remain intact'
else
  record fail 'persistent database, configuration, or canary data is missing or unsafe'
fi

check_service() {
  local status body
  status="$(curl -sS --max-time 10 -o /dev/null -w '%{http_code}' "$URL/status.php" 2>/dev/null || true)"
  [[ "$status" == 200 ]] || return 1
  body="$(curl -fsS --max-time 10 "$URL/remote.php/dav/files/$CANARY_USER/canary.txt" \
    -u "$CANARY_USER:$CANARY_PASSWORD" 2>/dev/null)" || return 1
  [[ "$body" == 'Nextcloud canary file: EVENT-CANARY-02' ]]
}

if check_service; then
  record pass 'Nextcloud responds and WebDAV login reads the canary file'
else
  record fail 'Nextcloud response or WebDAV canary check failed'
fi

if [[ -n "$cid" ]] && check_service && "${compose[@]}" restart nextcloud >/dev/null 2>&1; then
  restart_ready=0
  for _ in $(seq 1 30); do
    if check_service; then
      restart_ready=1
      break
    fi
    sleep 1
  done
  if (( restart_ready == 1 )); then
    record pass 'service and canary remain functional after restart'
    restarted_cid="$("${compose[@]}" ps -q nextcloud 2>/dev/null || true)"
    if [[ -n "$restarted_cid" ]] \
      && [[ "$(docker inspect -f '{{.Image}}' "$restarted_cid" 2>/dev/null || true)" == "$EXPECTED_IMAGE_ID" ]]; then
      record pass 'event image remains in use after restart'
    else
      record fail 'event image changed after restart'
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