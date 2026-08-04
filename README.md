# Dockerized PBX Gate Access & SMS Authentication System

A containerized Asterisk and MariaDB stack for managing telephone-operated gate access control with temporary guest permissions and web-based SMS authentication.

## 🚀 Key Features

* **Phone-Triggered Access:** Open gates automatically by calling designated phone numbers (`GATE_1_PHONE`, `GATE_2_PHONE`).
* **Caller ID Access Control:** Restrict gate access based on caller ID matching stored phone numbers in MariaDB.
* **SMS 2FA Authentication (`sms_auth`):** Authenticate web interface logins using SMS verification codes.
* **Timed Guest Permissions:** Grant temporary gate access with start and expiration timestamps (`access` table).
* **Automated Maintenance Daemon (`pbx-cron`):** Nightly background cron job to purge stale SMS sessions and maintain database health.
* **Containerized Stack:** Built with `docker compose` for simple setup, volume persistence, and environment-driven configuration.

---

## Build details

Copy the example environment configuration file:

```bash
cp .env.example .env
```

Edit `.env` to set passwords, port bindings, and service credentials.

Build and start the container stack:

```bash
docker compose up -d --build
```

To initialize the database (only required on first setup):

```bash
docker exec -it pbx-db /pbx_setup.sh
```

To restore or import a database backup:

```bash
docker cp mysql_backup.sql.bz2 pbx-db:/tmp/
docker exec -it pbx-db /pbx_import.sh
```
