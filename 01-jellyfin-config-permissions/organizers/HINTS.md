# Hints

1. **Nudge:** The logs identify the path Jellyfin cannot use. Check the host directory mounted there.
2. **Stronger:** Compare the container's configured UID/GID with the numeric owner of the persistent config directory.
3. **Near-answer:** Make `/config` writable by the Jellyfin process. Correct ownership is sufficient; broad world-write permissions are not.