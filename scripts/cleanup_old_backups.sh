#!/bin/bash
# scripts/cleanup_old_backups.sh

source "$(dirname "$0")/../config/config"

# Logging-Funktion
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Prüfe und erstelle Backup-Verzeichnis falls nicht vorhanden
if [ ! -d "$BACKUP_BASE_DIR" ]; then
    log "Backup-Verzeichnis existiert nicht: $BACKUP_BASE_DIR"
    exit 1
fi

# Finde alle Backup-Verzeichnisse
find "$BACKUP_BASE_DIR" -maxdepth 1 -type d -name "????-??-??_??-??-??" | while read backup_dir; do
    backup_date=$(basename "$backup_dir" | cut -d'_' -f1)

    # Bestimme Alter des Backups
    days_old=$(( ( $(date +%s) - $(date -d "$backup_date" +%s) ) / 86400 ))

    # Behalte die letzten X täglichen Backups
    if [ $days_old -le $DAILY_BACKUPS ]; then
        continue
    fi

    # Behalte wöchentliche Backups für den letzten Monat
    if [ $((days_old % 7)) -eq 0 ] && [ $days_old -le $((WEEKLY_BACKUPS * 7)) ]; then
        continue
    fi

    # Behalte monatliche Backups
    if [ $((days_old % 30)) -eq 0 ] && [ $days_old -le $((MONTHLY_BACKUPS * 30)) ]; then
        continue
    fi

    # Lösche alte Backups
    log "Lösche altes Backup: $backup_dir"
    rm -rf "$backup_dir"
done

log "Backup-Bereinigung abgeschlossen"
