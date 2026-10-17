docker compose exec -u www-data nextcloud sh -c '
config=/var/www/html/config/config.php
grep -q "PlantedMismatch-2026!" "$config" || {
  echo "Expected broken password was not found in config.php" >&2
  exit 1
}
sed -i "s/PlantedMismatch-2026!/NextcloudDb-2026!/" "$config"
'
docker compose restart nextcloud
curl -fsS http://127.0.0.1:8102/status.php