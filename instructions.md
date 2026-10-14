# Jellyfin Setup

Run these two commands in the Ubuntu VM terminal. Replace the example path with the scenario folder's actual path. The second command prompts for the signing secret, builds the event image, then sets up Jellyfin. The secret is not echoed or saved in shell history.

1. Change to the scenario folder:

```bash
cd ~/sunk/01-jellyfin-config-permissions
```

2. Build and set up the server. This works when your interactive shell is Bash or zsh:

```bash
bash -c 'read -rsp "EVENT_SECRET: " EVENT_SECRET; printf "\n"; export EVENT_SECRET; bash build.sh && bash setup.sh'
```

Open Jellyfin inside the Ubuntu VM at `http://localhost:8101`.

If `build.sh` already completed successfully and created `dist/01-jellyfin.tar.gz` and `organizers/expected.env`, do not build again. From the scenario folder, rerun setup with:

```bash
bash setup.sh
```

Setup reclaims ownership of old scenario data before replacing it, including config files left root-owned by an earlier break.

After setup, plant the broken state and check it with:

```bash
bash break.sh && bash verify.sh
```

Verification should report `RESULT: FAIL` after the fault is planted.

## Remove Organizer Files From a Player-Facing Copy

Do not run this on the organizer media. Set `PLAYER_COPY` to a temporary copy that will be exposed to players:

```bash
PLAYER_COPY=/path/to/player-copy/01-jellyfin-config-permissions
rm -rf "$PLAYER_COPY/build.sh" \
  "$PLAYER_COPY/setup.sh" \
  "$PLAYER_COPY/break.sh" \
  "$PLAYER_COPY/verify.sh" \
  "$PLAYER_COPY/reset.sh" \
  "$PLAYER_COPY/.gitignore" \
  "$PLAYER_COPY/image" \
  "$PLAYER_COPY/organizers" \
  "$PLAYER_COPY/seed" \
  "$PLAYER_COPY/dist" \
  "$PLAYER_COPY/player-stack"
```

Files and directories removed: `build.sh`, `setup.sh`, `break.sh`, `verify.sh`, `reset.sh`, `.gitignore`, `image/`, `organizers/`, `seed/`, `dist/`, and `player-stack/`.

Keep the deployed player stack at `~/homelab-event/01-jellyfin` and provide `player/incident-report.md` and `player/logs.txt`. Keep the organizer media private and eject it while players use the VM.