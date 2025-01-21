#!/bin/bash
# scripts/check_backup_status.sh

source "$(dirname "$0")/../config/config"

# Logging-Funktion
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Liste alle Backups auf
list_backups() {
    log "Gefundene Backups:"
    ls -rtla "$BACKUP_BASE_DIR" | grep -E '2025-[0-9]{2}-[0-9]{2}' | while read -r line; do
        log "$line"
    done
}

# Prüfe Backup-Alter
check_backup_age() {
    # Finde alle Backup-Verzeichnisse (nur Verzeichnisse mit korrektem Format)
    mapfile -t backups < <(find "$BACKUP_BASE_DIR" -maxdepth 1 -type d -name "????-??-??_*" | sort)

    if [ ${#backups[@]} -eq 0 ]; then
        log "WARNUNG: Kein Backup gefunden!"
        return 1
    fi

    latest_backup="${backups[-1]}"
    
    # Hole den Änderungszeitstempel des Verzeichnisses
    if ! backup_timestamp=$(stat -c %Y "$latest_backup" 2>/dev/null); then
        log "WARNUNG: Kann Änderungszeitstempel für $latest_backup nicht lesen"
        return 1
    fi
    
    current_timestamp=$(date +%s)
    seconds_old=$((current_timestamp - backup_timestamp))
    days_old=$((seconds_old / 86400))
    hours_old=$(((seconds_old % 86400) / 3600))
    minutes_old=$(((seconds_old % 3600) / 60))

    log "Neuestes Backup: $latest_backup"

    # Detaillierte Altersanzeige
    if [ $days_old -eq 0 ]; then
        if [ $hours_old -eq 0 ]; then
            if [ $minutes_old -eq 0 ]; then
                backup_age="weniger als eine Minute"
            elif [ $minutes_old -eq 1 ]; then
                backup_age="eine Minute"
            else
                backup_age="$minutes_old Minuten"
            fi
        else
            if [ $hours_old -eq 1 ]; then
                hours_text="eine Stunde"
            else
                hours_text="$hours_old Stunden"
            fi
            if [ $minutes_old -gt 0 ]; then
                backup_age="$hours_text und $minutes_old Minuten"
            else
                backup_age="$hours_text"
            fi
        fi
    else
        if [ $days_old -eq 1 ]; then
            days_text="einen Tag"
        else
            days_text="$days_old Tage"
        fi
        if [ $hours_old -eq 0 ]; then
            backup_age="$days_text"
        elif [ $hours_old -eq 1 ]; then
            backup_age="$days_text und eine Stunde"
        else
            backup_age="$days_text und $hours_old Stunden"
        fi
    fi

    if [ $days_old -gt 7 ]; then
        log "WARNUNG: Letztes Backup ist $backup_age alt"
        return 1
    else
        log "OK: Letztes Backup ist $backup_age alt"
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
    return 0
}

# Prüfe Backup-Integrität
check_backup_integrity() {
    # Finde das neueste Backup
    mapfile -t backups < <(find "$BACKUP_BASE_DIR" -maxdepth 1 -type d -name "????-??-??_*" | sort)

    if [ ${#backups[@]} -eq 0 ]; then
        log "WARNUNG: Kein Backup zum Prüfen gefunden"
        return 1
    fi

    latest_backup="${backups[-1]}"
    log "Prüfe Integrität von: $latest_backup"
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

    if [ $errors -eq 0 ]; then
        log "Integrität OK: Keine beschädigten Dateien gefunden"
    fi

    return $errors
}

# Hauptfunktion
main() {
    local exit_code=0

    log "Starte Backup-Status-Check..."

    # Liste alle vorhandenen Backups auf
    list_backups

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
