#!/usr/bin/env bash
set -e

echo "[SETUP] Importing initial schema into 'pbx' database..."
mysql -h 127.0.0.1 -u root -p"$MYSQL_ROOT_PASSWORD" pbx < /pbx.sql

echo "[SETUP] Granting privileges to user 'pbx' on database 'pbx'..."
mysql -h 127.0.0.1 -u root -p"$MYSQL_ROOT_PASSWORD" <<EOF
GRANT ALL PRIVILEGES ON pbx.* TO 'pbx'@'%' IDENTIFIED BY '$DB_PASSWORD';
FLUSH PRIVILEGES;
EOF

echo "[SETUP] Database initialization completed successfully."
echo ""
echo "To import an existing database backup, run:"
echo "  docker cp mysql_backup.sql.bz2 pbx-db:/tmp/"
echo "  docker exec -it pbx-db /pbx_import.sh"
