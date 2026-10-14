#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SCENARIO_ID=01-jellyfin
IMAGE_TAG=evt01-jellyfin:1

for command in docker openssl awk gzip; do
  command -v "$command" >/dev/null 2>&1 || {
    printf 'Required command not found: %s\n' "$command" >&2
    exit 1
  }
done

: "${EVENT_SECRET:?Set EVENT_SECRET in the build environment before running build.sh}"
[[ -n "$EVENT_SECRET" ]] || { printf 'EVENT_SECRET must not be empty\n' >&2; exit 1; }

sig="$(printf '%s' "$SCENARIO_ID" | openssl dgst -sha256 -hmac "$EVENT_SECRET" | awk '{print $NF}')"
mkdir -p "$ROOT/dist" "$ROOT/organizers"
docker build --build-arg "SIG=$sig" -t "$IMAGE_TAG" "$ROOT/image"
docker save "$IMAGE_TAG" | gzip -1 -c > "$ROOT/dist/01-jellyfin.tar.gz"
image_id="$(docker image inspect "$IMAGE_TAG" --format '{{.Id}}')"

printf 'EXPECTED_IMAGE_ID=%s\nEXPECTED_SIG=%s\nEXPECTED_SIG_PATH=/usr/share/.evt-jellyfin-state\n' \
  "$image_id" "$sig" > "$ROOT/organizers/expected.env"
printf 'Built and signed %s (%s)\n' "$IMAGE_TAG" "$image_id"
printf 'Tarball: %s\n' "$ROOT/dist/01-jellyfin.tar.gz"