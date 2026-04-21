#!/bin/bash

# ============================================================
#  CONFIGURATION — adjust according to your environment
# ============================================================
PG_USER=""
DATABASES=("db1" "db2")
BACKUP_DIR="/var/backups/postgres"
RETENTION_DAYS=7
WEBHOOK="your-callback-url"
# ============================================================

DATE=$(date +"%Y-%m-%d_%H-%M-%S")
LOG_FILE="$BACKUP_DIR/backup.log"

mkdir -p "$BACKUP_DIR"
echo "=======================================" >> "$LOG_FILE"
echo "Backup started: $DATE" >> "$LOG_FILE"

# ===== FUNCTIONS =====

send_error() {
  DB_NAME="$1"
  MSG="$2"
  echo "  ✘ Error: $MSG" >> "$LOG_FILE"

  curl --retry 5 --retry-delay 5 --max-time 60 -s -X POST "$WEBHOOK?db=$DB_NAME" \
    -H "Content-Type: application/json" \
    -d "{\"status\": \"error\", \"message\": \"$MSG\"}" >/dev/null 2>&1
}

send_file() {
  FILE_PATH="$1"
  DB_NAME="$2"

  curl --retry 5 --retry-delay 5 --max-time 120 -s -X POST "$WEBHOOK?db=$DB_NAME" \
    -F "status=success" \
    -F "message=" \
    -F "binary=@$FILE_PATH" >/dev/null 2>&1
}

# ===== DATABASE BACKUP =====

for DB in "${DATABASES[@]}"; do
  echo "  Backing up database: $DB" >> "$LOG_FILE"

  FILENAME="$BACKUP_DIR/${DB}_${DATE}.sql.gz"

  sudo -u $PG_USER pg_dump "$DB" | gzip > "$FILENAME"
  EXIT_CODE=${PIPESTATUS[0]}

  if [ $EXIT_CODE -ne 0 ]; then
    rm -f "$FILENAME"
    send_error "$DB" "Dump failed for database $DB on $(hostname)"
    continue
  fi

  if [ ! -s "$FILENAME" ]; then
    rm -f "$FILENAME"
    send_error "$DB" "Dump for database $DB produced an empty file on $(hostname)"
    continue
  fi

  SIZE=$(du -sh "$FILENAME" | cut -f1)
  echo "  ✔ $DB — $FILENAME ($SIZE)" >> "$LOG_FILE"

  send_file "$FILENAME" "$DB"
  if [ $? -ne 0 ]; then
    send_error "$DB" "Failed to send backup for $DB to webhook"
    continue
  fi

done

# ===== ROTATION =====
echo "  Removing backups older than $RETENTION_DAYS days..." >> "$LOG_FILE"
find "$BACKUP_DIR" -name "*.sql.gz" -mtime +$RETENTION_DAYS -delete

echo "Backup finished: $(date +"%Y-%m-%d_%H-%M-%S")" >> "$LOG_FILE"
