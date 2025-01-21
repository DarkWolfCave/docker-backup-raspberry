#!/bin/bash
# scripts/check_backup_status.sh

source "$(dirname "$0")/../config/config"

# Logging-Funktion
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Prüfe Backup-Alter
check_backup_age() {
    local latest_backup=$(find "$BACKUP_BASE_DIR" -maxdepth 1 -type d -name "????-??-??_??-??-??" | sort -r | head -n1)

    if [ -z "$latest_backup" ]; then
        log "WARNUNG: Kein Backup gefunden!"
        return 1
    }

    local backup_date=$(basename "$latest_backup" | cut -d'_' -f1)
    local days_old=$(( ( $(date +%s) - $(date -d "$backup_date" +%s) ) / 86400 ))

    if [ $days_old -gt 7 ]; then
        log "WARNUNG: Letztes Backup ist $days_old Tage alt"
        return 1
    else
        log "OK: Letztes Backup ist $days_old Tage alt"
        return 0
    fi
}

# Prüfe Backup-Größe
check_backup_size() {
    local backup_size=$(du -sh "$BACKUP_BASE_DIR" | cut -f1)
    local available_space=$(df -h "$BACKUP_BASE_DIR" | awk 'NR==2 {print $4}')

    log "Backup-Größe: $backup_size"
    log "Verfügbarer Speicherplatz: $available_space"

    # Warnung wenn weniger als 20% Speicherplatz verfügbar
    local available_kb=$(df "$BACKUP_BASE_DIR" | awk 'NR==2 {print $4}')
    local total_kb=$(df "$BACKUP_BASE_DIR" | awk 'NR==2 {print $2}')

    if [ $((available_kb * 100 / total_kb)) -lt 20 ]; then
        log "WARNUNG: Wenig Speicherplatz verfügbar!"
        return 1
    fi
}

# Prüfe Backup-Integrität
check_backup_integrity() {
    local latest_backup=$(find "$BACKUP_BASE_DIR" -maxdepth 1 -type d -name "????-??-??_??-??-??" | sort -r | head -n1)

    if [ -z "$latest_backup" ]; then
        return 1
    fi

    local errors=0

    # Prüfe Docker Image Backups
    for image_file in "$latest_backup"/*_backup.tar; do
        if [ -f "$image_file" ]; then
            if ! tar tf "$image_file" &>/dev/null; then
                log "FEHLER: Beschädigtes Image-Backup: $(basename "$image_file")"
                ((errors++))
            fi
        fi
    done

    # Prüfe Volume Backups
    for volume_file in "$latest_backup"/*.tar.gz; do
        if [ -f "$volume_file" ]; then
            if ! tar tzf "$volume_file" &>/dev/null; then
                log "FEHLER: Beschädigtes Volume-Backup: $(basename "$volume_file")"
                ((errors++))
            fi
        fi
    done

    return $errors
}

# Hauptfunktion
main() {
    local exit_code=0

    log "Starte Backup-Status-Check..."

    check_backup_age
    [ $? -ne 0 ] && exit_code=1

    check_backup_size
    [ $? -ne 0 ] && exit_code=1

    check_backup_integrity
    [ $? -ne 0 ] && exit_code=1

    if [ $exit_code -eq 0 ]; then
        log "Alle Checks erfolgreich"
    else
        log "Es wurden Probleme festgestellt"
    fi

    return $exit_code
}

# Führe Hauptfunktion aus
main
