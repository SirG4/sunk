# Homelab Troubleshooting Event: Agent Briefing

You are helping build challenge scenarios for a university troubleshooting event, in the style of [sadservers.com](https://sadservers.com/). Players are handed a broken homelab service and must diagnose and fix it using only normal tools and public documentation.

Each time I message you, I will give you **two things only**:

1. **TOOL**: the homelab/self-hosted software (e.g. Jellyfin, Vaultwarden, Gitea)
2. **ISSUE**: the kind of fault to plant (e.g. "wrong volume permissions", "bad env var", "port conflict")

You produce the complete scenario package described below. Do not ask me about anything this README already covers. If something is truly ambiguous, pick the most sensible default, state it in one line, and proceed.

---

## 1. Event overview

- 10 scenarios total, one per homelab tool, running on university lab PCs.
- Everything runs in **Docker** (Dockerfile and/or docker-compose), bound to **localhost only**.
- I run `setup.sh` and `break.sh` on each lab PC *before* players arrive. The service starts out broken.
- Players receive an **incident report** plus **log excerpts/error messages**. They investigate, fix, and then call a volunteer.
- A volunteer runs `verify.sh`, which checks whether the issue is truly fixed and prints PASS/FAIL.
- Players have **no access to the solution, break.sh, verify.sh, or the signing secret**. Assume they are smart but unfamiliar with the specific tool.
- Players could try to "fix" a scenario by pulling the stock upstream image instead of repairing the custom one. Section 6 (image signing) exists to make that fail.

## 2. Hard rules for every scenario

1. **Localhost only.** Every published port must be `127.0.0.1:HOST_PORT:CONTAINER_PORT`. Never `0.0.0.0`, never host networking.
2. **Fixable with public documentation.** The fault must be diagnosable and solvable via the tool's official docs, GitHub issues, Docker docs, or common Linux/Docker knowledge. No obscure, undocumented, or luck-based faults. No "guess the hidden file".
3. **Exactly one root cause per scenario** (unless I ask for a multi-stage one). The visible symptom may differ from the root cause, but there must be a clear diagnostic path from symptom to cause.
4. **Realistic.** The break should resemble something that happens in real homelabs: bad permissions, wrong env var, port clash, missing volume, expired or misconfigured certificate, wrong database credentials, full disk, bad config syntax, version mismatch, wrong user/UID, broken healthcheck, dependency started in wrong order, and so on.
5. **Players fix it with normal tools:** `docker`, `docker compose`, `docker logs`, `docker exec`, shell, editors, `ss`, `curl`, `chmod/chown`, config files. Do not require special tooling.
6. **No cheating shortcuts.** `verify.sh` must fail if the player deletes everything, replaces the service with a dummy, swaps in the stock upstream image, or bypasses the fix (see sections 5 and 6).
7. **No destructive or unsafe behavior** outside the scenario's own directory and containers. Never touch other containers, system files, the host network, or anything not namespaced to this scenario.
8. **Idempotent and re-runnable.** Setup and break scripts can be run repeatedly on fresh or previously used PCs without manual cleanup. Provide a `reset.sh` that returns the machine to a clean state.
9. **Pin versions.** Use specific upstream image tags (never `latest`) in the `FROM` line so behavior is reproducible and docs match.
10. **Offline-friendly.** Custom images are built once by me and shipped as tarballs (section 6). Any upstream base images must be listed so I can pull them before the event on lab Wi-Fi.

## 3. Deliverables per scenario

Create one folder per scenario, named `NN-<tool>-<short-issue>/` (e.g. `03-jellyfin-media-permissions/`), containing:

```
NN-<tool>-<issue>/
├── player-stack/
│   └── docker-compose.yml    # the ONLY stack file players see (plus any config/data dirs the stack mounts)
├── image/
│   └── Dockerfile            # custom event image (always custom, so it can carry a signature)
├── seed/                     # canary data seeded into the service (section 6.3)
├── build.sh                  # ORGANIZER ONLY: builds + signs the image, saves tarball, writes expected.env
├── setup.sh                  # ORGANIZER ONLY: loads image, deploys player-stack, seeds data, starts healthy
├── break.sh                  # ORGANIZER ONLY: plants the fault (run after setup.sh)
├── verify.sh                 # ORGANIZER/VOLUNTEER ONLY: prints PASS/FAIL with reasons
├── reset.sh                  # ORGANIZER ONLY: tears everything down and restores a clean slate
├── player/
│   ├── incident-report.md    # what players receive
│   └── logs.txt              # realistic error output captured from the broken state
└── organizers/
    ├── SOLUTION.md           # root cause, diagnostic path, exact fix
    ├── HINTS.md              # 3 tiered hints (nudge, stronger, near-answer)
    ├── NOTES.md              # difficulty, estimated time, images used, ports, gotchas
    └── expected.env          # generated by build.sh: EXPECTED_IMAGE_ID, EXPECTED_SIG, EXPECTED_SIG_PATH (gitignored)
```

**Players only ever see `player-stack/` (deployed to the lab PC by `setup.sh`), `player/incident-report.md`, and `player/logs.txt`.** Everything else stays on my machine/USB and must never be copied into the players' working directory. `setup.sh` deploys the stack to `/opt/homelab-event/NN-<tool>/` (or `~/homelab-event/NN-<tool>/` if no root) and leaves nothing else behind.

### 3.1 setup.sh
- Starts from a clean state. Loads the signed image tarball (`docker load`), checks the loaded image ID equals `EXPECTED_IMAGE_ID`, and aborts loudly if it doesn't.
- Deploys `player-stack/`, seeds canary data (section 6.3), brings the stack up **healthy**, and waits until the service responds (poll with timeout).
- Prints the localhost URL and what "working" looks like.
- `set -euo pipefail`; clear, friendly output.

### 3.2 break.sh
- Plants the fault in a way that survives container restarts (players will restart containers; the fault must not vanish just because they did, unless that's the intended lesson).
- Must not damage the signature or the seeded canary data.
- Leaves the system in a state where logs naturally show the symptom. Capture real logs for `player/logs.txt` by actually running it, not inventing them. If you can't run Docker in your environment, write the most realistic output you can and mark it `# SIMULATED, regenerate on a real machine`.
- Must **not** leave obvious fingerprints that give away the answer (no comments or files named "broken", no helper scripts left lying around in the players' working directory). Keep the planted-fault mechanics hidden inside `break.sh` or the baked-in image, not in the visible compose file.

### 3.3 verify.sh
See sections 5 and 6.

### 3.4 reset.sh
- `docker compose down -v --remove-orphans`, removes scenario-created dirs/images/networks, and nothing else.

## 4. Player-facing material

### player/incident-report.md
Write it like a real ticket from a user or monitoring system. Format:

```
# Incident Report: <ID, e.g. INC-0003>
**Service:** <tool name>
**Reported by:** <fictional user/monitoring>
**Severity:** <Low/Medium/High>
**Status:** Open

## Summary
<2-4 sentences of user-visible symptoms, in plain language>

## Environment
- Host: lab PC, Docker + Docker Compose
- Stack location: <path players will work in>
- Service URL (when healthy): http://localhost:<port>

## What was observed
<bulleted symptoms, timeline of what changed or "nothing changed that I know of">

## Your task
Restore the service to a fully working state using the provided stack. When you believe it is fixed, call a volunteer to verify.
```

Rules for the report:
- Describe **symptoms**, never the cause or the fix.
- Mention a plausible but non-misleading "recent change" only if it fits the root cause. Never plant red herrings that cost players an unfair amount of time. (A single mild distraction is fine on harder scenarios.)
- Include the stack path and the exact commands players would normally use to start/stop it.
- Do not mention image signing or verification mechanics. The task wording ("using the provided stack") is enough.

### player/logs.txt
- Real excerpts: 15-60 lines, with timestamps, containing the decisive error plus realistic surrounding noise.
- The decisive line(s) must be present. A player who reads carefully should be able to Google them and land on the right docs.
- Do not include the fix or hints.

## 5. verify.sh requirements

`verify.sh` is run by a volunteer, so it must be **trustworthy and fast** (under about 20 seconds). It loads its expected values from `organizers/expected.env`.

- Print one line per check: `[PASS] ...` or `[FAIL] ...` with a short reason, and a final `RESULT: PASS` or `RESULT: FAIL`. Exit code 0 on pass, non-zero on fail.
- Check **real functionality**, not just that a container is "Up":
  - the service responds on its localhost port with the expected status/content
  - a real functional action works (e.g. log in, create/read an item, API call returns expected JSON, data persists across a restart)
  - the fault condition is truly gone (e.g. correct ownership/permissions, correct config value) **without** hardcoding the one solution path; accept any valid fix
- **Anti-cheat checks:**
  - **Image integrity and signature** (section 6.1 and 6.2)
  - **Canary data present** (section 6.3)
  - required persistent data/volumes are still intact (the fix must not destroy data)
  - the port is still bound to `127.0.0.1` only (fail if the player exposed it on `0.0.0.0`)
  - security settings weren't weakened to "fix" it (e.g. no `chmod -R 777`, no disabling auth, no `privileged: true`), where relevant to the scenario
- Where practical, restart the service inside verify.sh and re-check, to prove the fix is persistent, not just a one-off manual tweak.
- Must be **read-only/non-destructive** apart from that optional restart test.
- Must never print the solution on failure. Give a generic message like which check failed, not how to fix it.
- Must never print `EXPECTED_SIG` or the secret, even on failure.

## 6. Image signing (anti-"pull the stable version" protection)

Goal: if a player replaces the custom event image with the stock upstream image, or rebuilds/retags something else, `verify.sh` fails. All three layers below are required for every scenario.

### 6.1 Check the image ID, not the tag
Players can `docker pull` upstream and retag it over a custom tag, so tag or name checks prove nothing. The image **ID** is a content hash and can't be faked that way.

- Build the image **once** on my machine (`build.sh`), then distribute it as a tarball. Never rebuild on each lab PC, because that produces a different ID.
- `build.sh` does: build, `docker save | gzip > dist/<scenario>.tar.gz`, and writes the resulting image ID into `organizers/expected.env`.
- The compose file references the image by its custom tag (e.g. `evt03-jellyfin:1`) with `pull_policy: never`, and has no `build:` section. Players should not be rebuilding it.

```bash
# in build.sh
docker build --build-arg SIG="$SIG" -t evt03-jellyfin:1 ./image
docker save evt03-jellyfin:1 | gzip > "dist/evt03.tar.gz"
echo "EXPECTED_IMAGE_ID=$(docker image inspect evt03-jellyfin:1 -f '{{.Id}}')" >> organizers/expected.env
```

```bash
# in verify.sh
source "$(dirname "$0")/organizers/expected.env"
cid=$(docker compose -p evt03 ps -q jellyfin)
[[ "$(docker inspect -f '{{.Image}}' "$cid")" == "$EXPECTED_IMAGE_ID" ]] \
  || { echo "[FAIL] service is not running the original event image"; exit 1; }
```

### 6.2 Bake an HMAC signature into the image
A second layer that also catches a different build retagged under the event tag.

- `EVENT_SECRET` is an environment variable on **my machine only**. Never write it to any file in the repo, never put it in a script, never put it on lab PCs.
- `build.sh` computes `SIG = HMAC-SHA256(secret, "<scenario-id>")`, passes it as a build arg, and writes `EXPECTED_SIG` and `EXPECTED_SIG_PATH` to `expected.env`.
- The Dockerfile bakes the signature **into a file inside the image** (and may add a label too). Do not rely on the label alone, because compose can override labels.

```bash
# in build.sh
SIG=$(printf '%s' "03-jellyfin" | openssl dgst -sha256 -hmac "$EVENT_SECRET" | awk '{print $2}')
```

```dockerfile
# image/Dockerfile
FROM jellyfin/jellyfin:10.9.11
ARG SIG
LABEL event.scenario="03-jellyfin" event.sig="${SIG}"
RUN echo "${SIG}" > /usr/share/.evt-sig && chmod 444 /usr/share/.evt-sig
```

```bash
# in verify.sh
actual=$(docker exec "$cid" cat "$EXPECTED_SIG_PATH" 2>/dev/null || true)
[[ "$actual" == "$EXPECTED_SIG" ]] || { echo "[FAIL] image signature mismatch"; exit 1; }
```

Pick an inconspicuous but plausible file path per scenario, so it isn't trivially guessable. The signature file must not be on a mounted volume, so players can't copy it into another container's volume.

### 6.3 Seed canary data (strongest layer)
Seed something into the service's data that exists only in my setup, and have `verify.sh` confirm it through the real API or database. Examples: a user `evt-admin` with a known password, a library item or repo named `EVENT-CANARY`, a specific DB row, a note with a known title.

- Done by `setup.sh` (using `seed/`), after the service is first healthy and **before** `break.sh`.
- A stock upstream image gives a fresh, empty instance, so the canary is missing and the check fails.
- Deleting the volume and starting over also fails the check, which doubles as the "data must stay intact" check.
- Canary credentials are never shown to players and never printed by `verify.sh`.

### 6.4 Handling of verify.sh and secrets
- `verify.sh` and `expected.env` contain values that are only secret if players can't read them. They live on organizer/volunteer USB sticks only, are run from there, and are not copied onto lab PCs or left in players' directories.
- Note this in `organizers/NOTES.md` for every scenario, with the exact command a volunteer runs (e.g. `bash /media/usb/03-jellyfin/verify.sh`).
- This is a deterrent, not a security boundary. Anyone in the `docker` group is effectively root. The goal is that cheating is harder than the legitimate fix, which is enough for a student event.

## 7. Organizer-facing material

- **SOLUTION.md:** root cause, the diagnostic path a player would follow (which logs, which commands), the exact fix, and the doc links that make it solvable.
- **HINTS.md:** three tiers. Tier 1 points at where to look. Tier 2 narrows to the component. Tier 3 almost gives the fix. Volunteers read these out only on request.
- **NOTES.md:** difficulty (Easy/Medium/Hard), estimated solve time, base image (with pinned tag), custom image tag, ports used, RAM/disk needs, the volunteer's `verify.sh` command, and any gotchas for setting up on lab PCs.

## 8. Difficulty and variety

Target mix across the 10 scenarios: roughly 3 Easy (5-10 min), 5 Medium (10-20 min), 2 Hard (20-30 min). If I don't state difficulty, infer it from the issue and note it in NOTES.md. Prefer variety of fault domains across the event: permissions, config, networking within Docker, storage/volumes, environment variables, database connectivity, certificates, resource limits, dependency/startup order.

## 9. Environment assumptions

- Lab PCs run Linux with Docker Engine and the Compose plugin (`docker compose`, not `docker-compose`). Scripts should check for these and fail with a clear message if missing. `openssl` is only needed on my build machine.
- Players may not have root; assume they are in the `docker` group. Don't rely on `sudo` unless the scenario genuinely needs it, and say so in NOTES.md.
- Each scenario gets a **unique host port** (use 127.0.0.1:8101 to 8110 in order, unless the tool needs something else; list it in NOTES.md) so several scenarios can coexist without clashing.
- Use a per-scenario Compose project name (`name:` in compose, or `-p`) and per-scenario network/volume names to avoid collisions.

## 10. Style and quality bar

- Shell scripts: `#!/usr/bin/env bash`, `set -euo pipefail`, quoted variables, shellcheck-clean, helpful messages.
- Compose files: clear, minimal, commented where it helps *organizers*. Remember players can read the compose file, so keep planted-fault details and signing details out of comments.
- Write all player-facing text so a student who has never touched the tool can follow it.
- Test what you can. After building a scenario, run this cycle and report the results:
  1. `build.sh`, then `setup.sh` (healthy)
  2. `verify.sh` passes on the healthy state (sanity check), then `break.sh`
  3. `verify.sh` fails after `break.sh`
  4. **Cheat test:** swap in the stock upstream image under the same tag and confirm `verify.sh` fails on the image check
  5. Apply the documented fix, `verify.sh` passes
  6. `reset.sh`

## 11. Response format when I give you a TOOL + ISSUE

1. One-line restatement of what you're building and any assumption you made.
2. Create the full folder per section 3.
3. Run the test cycle from section 10 if tooling allows, and summarize pass/fail (including the cheat test).
4. Finish with a short summary: folder path, port, difficulty, base image to pre-pull, tarball path, and anything I must do manually (such as exporting `EVENT_SECRET` before running `build.sh`).

Do not paste whole files back into chat; I'll read them from disk.

---

### Example prompt you'll receive

> TOOL: Jellyfin
> ISSUE: Media library shows empty because of wrong ownership on the mounted media volume.

Expected result: a complete `03-jellyfin-media-permissions/` (numbering follows the next free number) following everything above, including a signed image and an anti-cheat `verify.sh`.