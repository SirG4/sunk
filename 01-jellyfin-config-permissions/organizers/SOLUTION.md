# Solution

## Root cause
The persistent host directory mounted at `/config` is owned by `root:root`, while the compose service runs Jellyfin as UID/GID `1000:1000`. Jellyfin cannot create or update its logs and database files, so startup fails and Docker's restart policy keeps retrying.

## Diagnostic path
From the deployed stack directory, inspect `docker compose ps` and `docker compose logs jellyfin`. The startup exception names a denied path below `/config`. Compare the configured container user with the bind mount ownership using `docker compose exec jellyfin id` when the container is available and `stat -c '%u:%g %a %n' config` on the host.

## Fix
Either restore ownership with `sudo chown -R 1000:1000 config`, or change the compose `user:` to the numeric owner of the config directory. Do not make the directory world-writable. Restart with `docker compose up -d` and confirm the API responds at `http://localhost:8101`.

## References
- [Jellyfin Docker documentation](https://jellyfin.org/docs/general/installation/container/)
- [Docker bind mounts](https://docs.docker.com/engine/storage/bind-mounts/)