# Hints

1. **Nudge:** The web server is up, but Nextcloud cannot get past its database connection.
2. **Stronger:** The error is an authentication rejection from MariaDB, not a network timeout. Compare the database user's configured credentials with Nextcloud's stored configuration.
3. **Near-answer:** The persisted `dbpassword` and the MariaDB account password must match. The compose file shows the intended credential.