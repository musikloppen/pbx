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
