#!/bin/bash
set -e

# Export environment variables for cron jobs to source
echo "export DB_HOST=${DB_HOST}" > /etc/cron_env
echo "export DB_PORT=${DB_PORT}" >> /etc/cron_env
echo "export DB_NAME=${DB_NAME}" >> /etc/cron_env
echo "export DB_USER=${DB_USER}" >> /etc/cron_env
echo "export DB_PASS=${DB_PASS}" >> /etc/cron_env
echo "export TZ=${TZ}" >> /etc/cron_env
echo "export DEBUG=${DEBUG}" >> /etc/cron_env

chmod 0600 /etc/cron_env

echo "[CRON ENTRYPOINT] Environment exported to /etc/cron_env. Starting cron..."

# Initialize log file
touch /var/log/cron.log

# Start cron daemon in background
cron -f &
cron_pid=$!

# Tail logs to stdout so docker logs captures cron output
tail -f /var/log/cron.log &
tail_pid=$!

# Handle shutdown signals gracefully
trap 'kill -TERM $cron_pid $tail_pid' SIGTERM SIGINT

wait -n
