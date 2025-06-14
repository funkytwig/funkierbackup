#!/bin/bash
set -euo pipefail

LOGFILE="/var/log/backups.log"

# Redirect all output and errors to logfile with timestamps
exec > >(while IFS= read -r line; do echo "$(date '+%Y-%m-%d %H:%M:%S') $line"; done >> "$LOGFILE") 2>&1

log() {
    echo "$*" 
}

# === CONFIG ===
SRC="/path/to/source"
DEST="/path/to/backup"

log "=== Backup script started ==="

run_backup() {
    YEAR=$(date '+%Y')
    MONTH=$(date '+%m')
    DAY=$(date '+%d')
    HOUR=$(date '+%H')

    CURR_BACK="$DEST/$YEAR/$MONTH/$DAY/${HOUR}_H"
    TMP_BACK="$CURR_BACK.tmp"

    log "Starting backup for hour $HOUR, target: $CURR_BACK"

    if [ -e "$TMP_BACK" ]; then
        log "Removing leftover temp backup $TMP_BACK"
        rm -rf "$TMP_BACK"
    fi

    mkdir -p "$TMP_BACK"
    log "Created temporary backup directory: $TMP_BACK"

    PREV_BACK=$(find "$DEST" -type d \( -name "*_H" -o -name "*_D" -o -name "*_M" -o -name "*_Y" \) \
        -printf "%T@ %p\n" | sort -nr | head -n1 | cut -d' ' -f2)

    if [ -n "$PREV_BACK" ] && [ -d "$PREV_BACK" ]; then
        log "Using previous backup for hard-linking: $PREV_BACK"
        if ! rsync -a --delete --link-dest="$PREV_BACK" "$SRC/" "$TMP_BACK/"; then
            log "ERROR: rsync failed during incremental backup. Cleaning up."
            rm -rf "$TMP_BACK"
            exit 1
        fi
    else
        log "No previous backup found, doing full copy"
        if ! rsync -a --delete "$SRC/" "$TMP_BACK/"; then
            log "ERROR: rsync failed during full backup. Cleaning up."
            rm -rf "$TMP_BACK"
            exit 1
        fi
    fi

    mv "$TMP_BACK" "$CURR_BACK"
    log "Backup completed and moved to final directory: $CURR_BACK"
}

promote_hourly_to_daily() {
    local day_path="$DEST/$(date -d 'yesterday' +%Y/%m/%d)"
    log "Promoting hourly backups to daily in $day_path"
    local latest_h
    latest_h=$(find "$day_path" -maxdepth 1 -type d -name "*_H" | sort -r | head -n1) || latest_h=""

    if [ -n "$latest_h" ]; then
        local daily_name="${latest_h/_H/_D}"
        log "Promoting hourly backup: $latest_h -> $daily_name"
        mv "$latest_h" "$daily_name"
        log "Promotion successful"
    else
        log "No hourly backup found to promote for $day_path"
    fi
}

promote_daily_to_monthly() {
    local month_path="$DEST/$(date -d 'last month' +%Y/%m)"
    log "Promoting daily backups to monthly in $month_path"
    local latest_d
    latest_d=$(find "$month_path" -mindepth 2 -maxdepth 2 -type d -name "*_D" | sort -r | head -n1) || latest_d=""

    if [ -n "$latest_d" ]; then
        local monthly_name="${latest_d/_D/_M}"
        log "Promoting daily backup: $latest_d -> $monthly_name"
        mv "$latest_d" "$monthly_name"
        log "Promotion successful"
    else
        log "No daily backup found to promote for $month_path"
    fi
}

promote_monthly_to_yearly() {
    local year_path="$DEST/$(date -d 'last year' +%Y)"
    log "Promoting monthly backups to yearly in $year_path"
    local latest_m
    latest_m=$(find "$year_path" -mindepth 3 -maxdepth 3 -type d -name "*_M" | sort -r | head -n1) || latest_m=""

    if [ -n "$latest_m" ]; then
        local yearly_name="${latest_m/_M/_Y}"
        log "Promoting monthly backup: $latest_m -> $yearly_name"
        mv "$latest_m" "$yearly_name"
        log "Promotion successful"
    else
        log "No monthly backup found to promote for $year_path"
    fi
}

delete_dirs() {
    while read -r dir; do
        log "Deleting old backup: $dir"
        rm -rf "$dir"
    done
}

cleanup_old_backups() {
    log "Starting cleanup of old backups"

    log "Cleaning hourly backups, keeping latest 24"
    find "$DEST" -type d -name "*_H" -printf "%T@ %p\n" | sort -nr | cut -d' ' -f2 | tail -n +25 | delete_dirs

    log "Cleaning daily backups, keeping latest 32"
    find "$DEST" -type d -name "*_D" -printf "%T@ %p\n" | sort -nr | cut -d' ' -f2 | tail -n +33 | delete_dirs

    log "Cleaning monthly backups, keeping latest 13"
    find "$DEST" -type d -name "*_M" -printf "%T@ %p\n" | sort -nr | cut -d' ' -f2 | tail -n +14 | delete_dirs

    log "Yearly backups (*_Y) are kept indefinitely"

    log "Cleanup finished"
}

# === MAIN ===

case "${1:-}" in
    promote_hourly_to_daily)
        log "Starting promotion: hourly to daily"
        promote_hourly_to_daily
        ;;
    promote_daily_to_monthly)
        log "Starting promotion: daily to monthly"
        promote_daily_to_monthly
        ;;
    promote_monthly_to_yearly)
        log "Starting promotion: monthly to yearly"
        promote_monthly_to_yearly
        ;;
    cleanup)
        log "Starting cleanup only"
        cleanup_old_backups
        ;;
    *)
        log "Starting hourly backup + cleanup"
        run_backup
        cleanup_old_backups
        ;;
esac

log "=== Backup script finished ==="

exit 0
