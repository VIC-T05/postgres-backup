# pg-backup

A simple Bash script to automate PostgreSQL database backups with webhook notifications.

## Features

- Backs up one or more databases via `pg_dump`
- Compresses output with `gzip`
- Sends the backup file to a webhook endpoint
- Notifies the same webhook on errors
- Automatically removes backups older than `RETENTION_DAYS`
- Logs all activity to a local log file

## Configuration

Edit the variables at the top of the script:

| Variable         | Description                                      |
|------------------|--------------------------------------------------|
| `PG_USER`        | PostgreSQL system user (e.g. `postgres`)         |
| `DATABASES`      | Array of database names to back up               |
| `BACKUP_DIR`     | Directory where `.sql.gz` files are stored       |
| `RETENTION_DAYS` | How many days to keep old backups                |
| `WEBHOOK`        | URL to receive the backup file and error alerts  |

## Webhook

The script sends a `POST` request to `$WEBHOOK?db=<database_name>` in two formats:

**Success** — multipart form:
```
status=success
message=
binary=@<file.sql.gz>
```

**Error** — JSON:
```json
{ "status": "error", "message": "..." }
```

## Usage

```bash
chmod +x backup_postgres.sh
bash backup_postgres.sh
```

## Cron (daily at 2:00 AM)

```bash
crontab -e
```

```
0 2 * * * /bin/bash /path/to/backup_postgres.sh >> /var/log/backup_postgres.log 2>&1
```

## Logs

Activity is logged to `$BACKUP_DIR/backup.log`. Each run appends a timestamped block.