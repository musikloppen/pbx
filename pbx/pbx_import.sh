#!/usr/bin/env bash
set -e

SQL_FILE=/tmp/mysql_backup.sql.bz2

if [ ! -f "$SQL_FILE" ]; then
	echo "[ERROR] File $SQL_FILE not found in /tmp/!"
	echo "Please copy it first from your host machine using:"
	echo "  docker cp mysql_backup.sql.bz2 pbx-db:/tmp/"
	exit 1
fi

echo "[IMPORT] Restoring database backup into 'pbx'..."

if command -v bzcat >/dev/null 2>&1; then
	bzcat "$SQL_FILE" | mysql -h 127.0.0.1 -u root -p"$DB_ROOT_PASSWORD" pbx
else
	bzip2 -dc "$SQL_FILE" | mysql -h 127.0.0.1 -u root -p"$DB_ROOT_PASSWORD" pbx
fi

echo "[IMPORT] Database import completed successfully."
