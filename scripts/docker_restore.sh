#!/bin/bash
# scripts/docker_restore.sh
#
# Erstellt von: DarkWolfCave
# Version: 1.0
# Erstellt am: Januar 2025
# Letzte Änderung: 20.01.2025
#
# Beschreibung:
# Diese Skripte erstellen ein vollständiges Backup/Restore der Docker-Umgebung
# inklusive Container, Images, Volumes, Konfigurationen, HOME-Verzeichnis und Crontabs.
#
# Kontakt: https://darkwolfcave.de
# GitHub: https://github.com/DarkWolfCave
#
# Copyright (c) 2024 DarkWolfCave.de
#
# Hiermit wird jeder Person, die eine Kopie dieses Skripts und der zugehörigen Dokumentation erhält, die Erlaubnis erteilt,
# das Skript kostenlos zu verwenden, zu kopieren und zu modifizieren, unter den folgenden Bedingungen:
#
# 1. **Urheberrechtshinweis:** Der ursprüngliche Urheberrechtshinweis und dieser Lizenztext müssen in allen Kopien oder wesentlichen Teilen des Skripts enthalten bl>
# 2. **Verbot des Weiterverkaufs:** Der Verkauf dieses Skripts, ob in seiner ursprünglichen oder modifizierten Form, ist untersagt.
#      Eine kommerzielle Nutzung ist nur nach ausdrücklicher schriftlicher Genehmigung des Autors gestattet.
# 3. **Integration in andere Projekte:** Die Integration dieses Skripts in andere Projekte ist nur erlaubt, wenn das Skript als eigenständige
#      Komponente erkennbar bleibt und die oben genannten Bedingungen eingehalten werden.
# 4. **Haftungsausschluss:** DIESES SKRIPT WIRD OHNE JEGLICHE GEWÄHRLEISTUNG, AUSDRÜCKLICH ODER IMPLIZIT, BEREITGESTELLT.
#      DER AUTOR HAFTET NICHT FÜR IRGENDWELCHE SCHÄDEN ODER FOLGESCHÄDEN, DIE DURCH DIE NUTZUNG DES SKRIPTS ENTSTEHEN.
#
# Durch die Nutzung dieses Skripts stimmst du diesen Bedingungen zu.

# Lade Konfiguration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../config/config"

# Funktion für Logging
log() {
    local message="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    echo "$message" | tee -a "$RESTORE_LOG_FILE"
}

# Funktion für Fehler-Logging
log_error() {
    local message="[$(date '+%Y-%m-%d %H:%M:%S')] FEHLER: $1"
    echo "$message" | tee -a "$RESTORE_LOG_FILE" >&2
}

# Prüfe ob Docker installiert ist und installiere es bei Bedarf
if ! command -v docker &> /dev/null; then
    log "Docker ist nicht installiert. Starte Installation..."
    # Update Package List
    if apt-get update && \
       # Install required packages
       apt-get install -y ca-certificates curl gnupg lsb-release && \
       # Add Docker's official GPG key
       mkdir -p /etc/apt/keyrings && \
       curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg && \
       # Set up the repository
       echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null && \
       # Update apt package index
       apt-get update && \
       # Install Docker Engine
       apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin; then
        log "Docker wurde erfolgreich installiert"
    else
        log_error "Fehler bei der Docker-Installation"
        exit 1
    fi
fi

# Prüfe ob Docker läuft
if ! systemctl is-active --quiet docker; then
    log "Docker ist nicht aktiv. Starte Docker..."
    if systemctl start docker; then
        log "Docker wurde erfolgreich gestartet"
    else
        log_error "Fehler beim Starten von Docker"
        exit 1
    fi
fi

mkdir -p "$BACKUP_BASE_DIR"

# Prüfe ob Backup-Verzeichnis als Parameter übergeben wurde
if [ -z "$1" ]; then
    echo "Bitte Backup-Verzeichnis angeben"
    echo "Verwendung: ./docker_restore.sh /pfad/zum/backup/YYYY-MM-DD_HH-MM-SS"
    exit 1
fi

RESTORE_DATE=$(date +%Y-%m-%d_%H-%M-%S)
BACKUP_DIR="$1"

# Prüfe Root-Rechte
if [ "$EUID" -ne 0 ]; then
    log_error "Bitte als Root ausführen"
    exit 1
fi

# Prüfe ob Backup-Verzeichnis existiert
if [ ! -d "$BACKUP_DIR" ]; then
    log_error "Backup-Verzeichnis existiert nicht: $BACKUP_DIR"
    exit 1
fi

log "Starte Wiederherstellung aus $BACKUP_DIR"

# Crontabs wiederherstellen
log "Stelle Crontabs wieder her..."
if [ -d "$BACKUP_DIR/crontabs" ]; then
    for crontab_file in "$BACKUP_DIR/crontabs"/*.crontab; do
        if [ -f "$crontab_file" ]; then
            username=$(basename "$crontab_file" .crontab)
            log "Stelle Crontab für Benutzer wieder her: $username"

            current_crontab=$(crontab -u $username -l 2>/dev/null)

            if [ -n "$current_crontab" ]; then
                if (echo "$current_crontab"; cat "$crontab_file") | crontab -u $username - 2>> "$RESTORE_LOG_FILE"; then
                    log "Crontab für Benutzer $username erfolgreich hinzugefügt"
                else
                    log_error "Fehler beim Hinzufügen der Crontab für Benutzer $username"
                fi
            else
                if crontab -u $username "$crontab_file" 2>> "$RESTORE_LOG_FILE"; then
                    log "Crontab für Benutzer $username erfolgreich wiederhergestellt"
                else
                    log_error "Fehler beim Wiederherstellen der Crontab für Benutzer $username"
                fi
            fi
        fi
    done
fi

# HOME-Verzeichnis wiederherstellen
log "Stelle HOME-Verzeichnis wieder her..."
if [ -f "$BACKUP_DIR/home.tar.gz" ]; then
    # Finde den relativen Pfad ab docker-backup-raspberry
    EXCLUDE_DIR="*/docker-backup-raspberry/*"
    log "Exclude Backup-Tool-Verzeichnis: $EXCLUDE_DIR"

    if tar --warning=no-file-ignored --exclude="$EXCLUDE_DIR" -xzf "$BACKUP_DIR/home.tar.gz" -C "$HOME_DIR" 2>> "$RESTORE_LOG_FILE"; then
        log "HOME-Verzeichnis erfolgreich wiederhergestellt"
    else
        log_error "Fehler beim Wiederherstellen des HOME-Verzeichnisses"
    fi
else
    log_error "Keine HOME-Verzeichnis-Sicherung gefunden"
fi

# Docker Volumes wiederherstellen
log "Stelle Docker Volumes wieder her..."
for volume_tar in $BACKUP_DIR/*.tar.gz; do
    if [ -f "$volume_tar" ] && [ "$(basename $volume_tar)" != "home.tar.gz" ]; then
        volume_name=$(basename $volume_tar .tar.gz)
        log "Stelle Volume wieder her: $volume_name"
        if docker volume create $volume_name 2>> "$RESTORE_LOG_FILE" && \
           docker run --rm -v $volume_name:/volume -v $BACKUP_DIR:/backup ubuntu tar -xzf /backup/$(basename $volume_tar) -C /volume 2>> "$RESTORE_LOG_FILE"; then
            log "Volume $volume_name erfolgreich wiederhergestellt"
        else
            log_error "Fehler beim Wiederherstellen des Volumes $volume_name"
        fi
    fi
done
log "Docker Volumes wiederhergestellt"

# Docker Konfigurationen wiederherstellen
if [ -d "$BACKUP_DIR/docker_configs" ]; then
    log "Stelle Docker Konfigurationen wieder her..."
    if cp -r $BACKUP_DIR/docker_configs/* /etc/docker/ 2>> "$RESTORE_LOG_FILE"; then
        log "Docker Konfigurationen erfolgreich wiederhergestellt"
    else
        log_error "Fehler beim Wiederherstellen der Docker Konfigurationen (kann meistens ignoriert werden)"
    fi
fi

# Docker Images wiederherstellen
log "Stelle Docker Images wieder her..."
for image_tar in $BACKUP_DIR/*_backup.tar; do
    if [ -f "$image_tar" ]; then
        log "Stelle Image wieder her: $(basename $image_tar)"
        if docker load < $image_tar 2>> "$RESTORE_LOG_FILE"; then
            log "Image $(basename $image_tar) erfolgreich wiederhergestellt"
        else
            log_error "Fehler beim Wiederherstellen des Images $(basename $image_tar)"
        fi
    fi
done
log "Docker Images wiederhergestellt"

# Container wiederherstellen
if [ -f "$BACKUP_DIR/docker-compose.yml" ]; then
    log "Stelle Container über docker-compose wieder her..."
    if docker-compose -f $BACKUP_DIR/docker-compose.yml up -d 2>> "$RESTORE_LOG_FILE"; then
        log "Container erfolgreich über docker-compose wiederhergestellt"
    else
        log_error "Fehler beim Wiederherstellen der Container über docker-compose"
    fi
else
    log "Stelle einzelne Container wieder her..."
    if [ -f "$BACKUP_DIR/container_configs.json" ]; then
        while IFS=, read -r container_name container_state; do
            log "Stelle Container wieder her: $container_name"
            if docker create --name "$container_name" "${container_name}_backup" 2>> "$RESTORE_LOG_FILE"; then
                if [[ $container_state == *"running"* ]]; then
                    if docker start "$container_name" 2>> "$RESTORE_LOG_FILE"; then
                        log "Container $container_name erfolgreich gestartet"
                    else
                        log_error "Fehler beim Starten des Containers $container_name"
                    fi
                else
                    log "Container $container_name wurde gestoppt wiederhergestellt"
                fi
            else
                log_error "Fehler beim Erstellen des Containers $container_name"
            fi
        done < "$BACKUP_DIR/container_states.txt"
    fi
fi

# Berechtigungen für HOME-Verzeichnis korrigieren
log "Korrigiere Berechtigungen für HOME-Verzeichnis..."
for user_dir in $HOME_DIR/*; do
    if [ -d "$user_dir" ]; then
        username=$(basename "$user_dir")
        if chown -R $username:$username "$user_dir" 2>> "$RESTORE_LOG_FILE"; then
            log "Berechtigungen für Benutzer $username korrigiert"
        else
            log_error "Fehler beim Korrigieren der Berechtigungen für Benutzer $username"
        fi
    fi
done

log "Wiederherstellung abgeschlossen"

# Zusammenfassung erstellen
log "=== Wiederherstellungs-Zusammenfassung ==="
RESTORE_END_TIME=$(date +%Y-%m-%d_%H-%M-%S)
log "Startzeit: $RESTORE_DATE"
log "Endzeit: $RESTORE_END_TIME"

# Prüfe ob es Fehler gab
ERROR_COUNT=$(grep -c "FEHLER:" "$RESTORE_LOG_FILE")
if [ $ERROR_COUNT -gt 0 ]; then
    log "WARNUNG: Es sind $ERROR_COUNT Fehler aufgetreten. Bitte überprüfen Sie das Log-File für Details: $RESTORE_LOG_FILE"
else
    log "Die Wiederherstellung wurde ohne Fehler abgeschlossen"
fi

# Container-Status überprüfen
RUNNING_CONTAINERS=$(docker ps -q | wc -l)
TOTAL_CONTAINERS=$(docker ps -aq | wc -l)
log "Aktive Container: $RUNNING_CONTAINERS von $TOTAL_CONTAINERS"

# Volume-Status überprüfen
VOLUME_COUNT=$(docker volume ls -q | wc -l)
log "Wiederhergestellte Volumes: $VOLUME_COUNT"

# Abschließende Meldung
if [ $ERROR_COUNT -eq 0 ]; then
    log "Die Wiederherstellung wurde erfolgreich abgeschlossen!"
else
    log "Die Wiederherstellung wurde mit $ERROR_COUNT Fehlern abgeschlossen. Bitte überprüfen!"
fi

log "=== Ende der Wiederherstellung ==="
