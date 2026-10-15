# Organizer Notes

- Difficulty: Easy-Medium
- Estimated solve time: 10-15 minutes
- Base image to pre-pull: `nextcloud:31.0.9-apache`
- Database image to pre-pull: `mariadb:11.4.5`
- Event image: `evt02-nextcloud:1`
- Host port: `127.0.0.1:8102` -> container port `80`
- Runtime needs: Docker Engine with Compose plugin; allow roughly 2 GB RAM and 4 GB disk for the images and initialized database.
- `EVENT_SECRET` must be exported on the organizer build machine before `bash build.sh`. It is never written to this repository or sent to lab PCs.
- Build creates `dist/02-nextcloud.tar.gz` and ignored `organizers/expected.env`. Distribute the event image tarball to lab PCs; keep `verify.sh` and `expected.env` on organizer/volunteer media only.
- Run `bash setup.sh` as root to deploy at `/opt/homelab-event/02-nextcloud`, or as a regular user to deploy at `~/homelab-event/02-nextcloud`. Setup initializes MariaDB and Nextcloud, creates `evt-reader`, uploads the canary file through WebDAV, and removes the temporary bootstrap administrator.
- Run `bash break.sh` after setup. It changes only Nextcloud's persistent database password setting, then restarts the web service.
- Volunteer command: `bash /media/usb/02-nextcloud/verify.sh` (run with the same account context used for setup, or use `sudo -u <setup-user>` when setup used a home directory).
- Verification checks the event image ID and HMAC, localhost-only binding, matching database environment, persistent data, WebDAV authentication and exact canary content, then restarts Nextcloud and rechecks.
- Reset command: `bash reset.sh` (use the account that owns the deployment directory).
- Keep organizer scripts and `organizers/expected.env` off the player machine. Players receive only `player-stack/`, `player/incident-report.md`, and `player/logs.txt`.
- Known gotchas: first setup downloads several GB unless both upstream images are pre-pulled; the first Nextcloud install may take a few minutes. The planted failure is intentional, so `verify.sh` must fail until a valid credential repair is made.