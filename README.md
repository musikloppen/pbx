# Dockerized PBX Gate Access & OpenResty Edge Security System

A containerized Asterisk and MariaDB stack for telephone-operated gate access control with temporary guest permissions, web-based SMS authentication, and an OpenResty (Nginx + Lua) security gateway.

## 🚀 Key Features

### 📞 PBX & Access Control
* **Phone-Triggered Gate Access:** Open physical gates automatically by calling designated phone numbers (`GATE_1_PHONE`, `GATE_2_PHONE`).
* **Caller ID Access Verification:** Restrict gate triggering based on caller ID matching stored phone numbers in MariaDB.
* **SMS 2FA Authentication (`sms_auth`):** Authenticate web interface users via SMS verification codes.
* **Timed Guest Permissions:** Issue temporary access windows with start and expiration timestamps (`access` table).
* **Automated Maintenance Daemon (`pbx-cron`):** Nightly background script to purge stale SMS sessions and maintain database health.

### 🛡️ OpenResty Edge Security (Lua)
* **DNSBL Real-Time Blacklist Filter (`dnsbl_check.lua`):** 
  * Checks client IPs against Spamhaus (SBL/XBL) and SpamCop DNSBL providers.
  * Features 1-hour positive and 30-minute negative `ngx.shared` caching to minimize DNS queries.
  * Lazy-loads dynamic IP whitelists from text files (`/dnsbl_whitelist/whitelist.txt`).
* **Exponential Backoff Rate Limiting (`rate_limit.lua`):**
  * Tracks request velocity per IP and URI path using shared memory.
  * Implements progressively doubling block delays (up to 60s max) upon limit breaches, complete with standard `429 Too Many Requests` status and `Retry-After` HTTP headers.

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
