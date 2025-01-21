#!/bin/bash
# scripts/cleanup_old_backups.sh

# Lade Konfiguration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../config/config"

# Logging-Funktion
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Prüfe und erstelle Backup-Verzeichnis, falls nicht vorhanden
if [ ! -d "$BACKUP_BASE_DIR" ]; then
    log "Backup-Verzeichnis existiert nicht: $BACKUP_BASE_DIR"
    exit 1
fi

# Finde alle Backup-Verzeichnisse und sortiere sie nach Änderungsdatum (älteste zuerst)
mapfile -t backups < <(find "$BACKUP_BASE_DIR" -maxdepth 1 -type d -name "????-??-??_*" -printf '%T@ %p\n' | sort -n | cut -d' ' -f2-)

# Wenn keine Backups gefunden wurden, beenden
if [ ${#backups[@]} -eq 0 ]; then
    log "Keine Backups gefunden"
    exit 0
fi

# Behalte immer das neueste Backup
newest_backup="${backups[-1]}"
log "Neuestes Backup wird behalten: $newest_backup"

# Prüfe die anderen Backups
for backup_dir in "${backups[@]}"; do
    # Überspringe das neueste Backup
    if [ "$backup_dir" = "$newest_backup" ]; then
        continue
    fi

    # Berechne das Alter in Tagen basierend auf dem Dateisystem-Zeitstempel
    backup_timestamp=$(stat -c %Y "$backup_dir")
    current_timestamp=$(date +%s)
    days_old=$(( (current_timestamp - backup_timestamp) / 86400 ))

    # Debug-Ausgabe
    log "Prüfe Backup: $backup_dir (Alter: $days_old Tage)"

    # Behalte die letzten X täglichen Backups
    if [ "$days_old" -lt "$DAILY_BACKUPS" ]; then
        log "Behalte tägliches Backup: $backup_dir"
        continue
    fi

    # Behalte wöchentliche Backups für den letzten Monat
    if [ "$((days_old % 7))" -eq 0 ] && [ "$days_old" -lt "$((WEEKLY_BACKUPS * 7))" ]; then
        log "Behalte wöchentliches Backup: $backup_dir"
        continue
    fi

    # Behalte monatliche Backups
    if [ "$((days_old % 30))" -eq 0 ] && [ "$days_old" -lt "$((MONTHLY_BACKUPS * 30))" ]; then
        log "Behalte monatliches Backup: $backup_dir"
        continue
    fi

    # Lösche alte Backups
    log "Lösche altes Backup: $backup_dir"
    rm -rf "$backup_dir"
done

log "Backup-Bereinigung abgeschlossen"
