if [ -f /opt/homelab-event/02-nextcloud/docker-compose.yml ]; then
	cd /opt/homelab-event/02-nextcloud
else
	cd "$HOME/homelab-event/02-nextcloud"
fi

docker compose ps
docker compose logs --tail=50 nextcloud
docker compose exec nextcloud tail -n 50 /var/www/html/data/nextcloud.log
grep -n 'MARIADB_PASSWORD\|MYSQL_PASSWORD' docker-compose.yml
docker compose exec nextcloud grep -n "'dbpassword'" /var/www/html/config/config.php

docker compose exec nextcloud sed -i "s/'dbpassword' => 'PlantedMismatch-2026!'/'dbpassword' => 'NextcloudDb-2026!'/" /var/www/html/config/config.php
docker compose restart nextcloud

curl -fsS http://127.0.0.1:8102/status.php
curl -fsS -u 'evt-reader:CanaryRead-2026!' http://127.0.0.1:8102/remote.php/dav/files/evt-reader/canary.txt