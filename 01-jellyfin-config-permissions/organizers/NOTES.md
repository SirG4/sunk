# Organizer Notes

- Difficulty: Easy
- Estimated solve time: 10 minutes
- Base image to pre-pull: `jellyfin/jellyfin:10.11.11`
- Event image: `evt01-jellyfin:1`
- Host port: `127.0.0.1:8101` -> container port `8096`
- Runtime needs: Docker Engine with Compose plugin; allow roughly 1 GB RAM and 2 GB disk for the image and data.
- `EVENT_SECRET` must be exported on the organizer build machine before `bash build.sh`. It is never written to this repository or sent to lab PCs.
- Build creates `dist/01-jellyfin.tar.gz` and ignored `organizers/expected.env`. Distribute the image tarball to lab PCs; keep `verify.sh` and expected.env on organizer/volunteer media only.
- Run `bash setup.sh` as root to deploy at `/opt/homelab-event/01-jellyfin`, or as a regular user to deploy at `~/homelab-event/01-jellyfin`. It loads the signed tarball, initializes the account and library, and generates two tiny video files.
- Run `bash break.sh` after setup. It stops the stack, uses a short-lived root process in the event image to change only the deployed config tree to `root:root`, and starts the stack again. It does not alter the canary data or image signature.
- Volunteer command: `bash /media/usb/01-jellyfin/verify.sh` (run with the same account context used for setup, or use `sudo -u <setup-user>` when setup used a home directory).
- Verification restarts Jellyfin, so run it after the player says they are finished. It checks image ID and HMAC, endpoint, login, library, media files, local-only port binding, config write access, and restart persistence.
- Reset command: `bash reset.sh` (use the account that owns the deployment directory).
- Known requirement: the organizer must build with the real `EVENT_SECRET` before producing the tarball used at the event. Do not distribute the temporary test build.