# Solution

## Root cause
The `dbpassword` stored in Nextcloud's persistent `config/config.php` no longer matches the password of the `nextcloud` user in MariaDB. MariaDB and the Nextcloud database environment in the compose file agree; the database rejects Nextcloud's connection with SQLSTATE 1045.

## Diagnostic path
From the deployed stack directory, inspect `docker compose ps` and `docker compose logs nextcloud` for the HTTP 500, then read Nextcloud's application log with `docker compose exec nextcloud tail -n 50 /var/www/html/data/nextcloud.log`. The decisive message is `SQLSTATE[HY000] [1045] Access denied for user 'nextcloud'`. Check the database environment in `docker-compose.yml`, then inspect the stored Nextcloud settings with `docker compose exec nextcloud php occ config:system:get dbpassword` and compare them with the MariaDB account.

## Fix
Either edit the persistent `nextcloud/config/config.php` and set its `dbpassword` value to the MariaDB password shown in the compose file, or change the MariaDB `nextcloud` account password to the value currently stored by Nextcloud. For this planted state, the direct edit can be made from the stack directory with `docker compose exec nextcloud sed -i "s/'dbpassword' => 'PlantedMismatch-2026!'/'dbpassword' => 'NextcloudDb-2026!'/" /var/www/html/config/config.php`. OCC commands cannot connect while the database credentials are broken, so use the file edit for that repair path. For the alternative, connect to MariaDB as root using its compose-configured root password and `ALTER USER 'nextcloud'@'%' IDENTIFIED BY '<current dbpassword value>';`. Restart Nextcloud if needed and confirm that the login page loads and authenticated WebDAV file access works at `http://localhost:8102`.

## References
- [Nextcloud Docker documentation](https://github.com/nextcloud/docker)
- [Nextcloud command-line administration](https://docs.nextcloud.com/server/latest/admin_manual/occ_command.html)
- [MariaDB account management](https://mariadb.com/kb/en/alter-user/)