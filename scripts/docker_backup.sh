#!/bin/bash
# scripts/docker_backup.sh
#
# Erstellt von: DarkWolfCave
# Version: 1.0.1
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
# 1. **Urheberrechtshinweis:** Der ursprüngliche Urheberrechtshinweis und dieser Lizenztext müssen in allen Kopien oder wesentlichen Teilen des Skripts enthalten bleiben.
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

# Initialisiere Backup
BACKUP_DATE=$(date +%Y-%m-%d_%H-%M-%S)
BACKUP_DIR="$BACKUP_BASE_DIR/$BACKUP_DATE"
mkdir -p "$BACKUP_BASE_DIR" "$BACKUP_DIR"

# Funktion für Logging
log() {
    local message="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    echo "$message" | tee -a "$LOG_FILE"
}

# Funktion für Fehler-Logging
log_error() {
    local message="[$(date '+%Y-%m-%d %H:%M:%S')] FEHLER: $1"
    echo "$message" | tee -a "$LOG_FILE" >&2
}

# Prüfe Root-Rechte
if [ "$EUID" -ne 0 ]; then
    log_error "Bitte als Root ausführen"
    exit 1
fi

# Backup-Verzeichnis erstellen und Logging starten
mkdir -p $BACKUP_DIR
log "Starte Backup-Prozess in $BACKUP_DIR"

# Crontabs sichern
log "Sichere Crontabs..."
mkdir -p "$BACKUP_DIR/crontabs"
for user in $(cut -f1 -d: /etc/passwd); do
    if crontab -u $user -l > "$BACKUP_DIR/crontabs/$user.crontab" 2>/dev/null; then
        log "Crontab für Benutzer $user erfolgreich gesichert"
    else
        log "Keine Crontab für Benutzer $user gefunden"
    fi
done
log "Crontab-Sicherung abgeschlossen"

# HOME-Verzeichnis sichern
log "Starte Sicherung des HOME-Verzeichnisses..."
if [ "$BACKUP_HOME" = true ]; then
    if tar --warning=no-file-ignored -czf "$BACKUP_DIR/home.tar.gz" $(printf -- '--exclude=%s ' "${EXCLUDE_DIRS[@]}") -C "$HOME_DIR" .; then
        log "HOME-Verzeichnis erfolgreich gesichert"
    else
        log_error "Sicherung des HOME-Verzeichnisses fehlgeschlagen"
    fi
else
    log "Sicherung des HOME-Verzeichnisses ist deaktiviert"
fi

# Docker Volumes sichern
log "Starte Sicherung der Docker Volumes..."
for VOLUME in $(ls $DOCKER_VOLUMES_DIR); do
    if [ -d "$DOCKER_VOLUMES_DIR/$VOLUME" ]; then
        log "Sichere Volume: $VOLUME"
        if tar -czf "$BACKUP_DIR/$VOLUME.tar.gz" -C "$DOCKER_VOLUMES_DIR/$VOLUME/_data" . 2>> "$LOG_FILE"; then
            log "Volume $VOLUME erfolgreich gesichert"
        else
            log_error "Sicherung des Volumes $VOLUME fehlgeschlagen"
        fi
    fi
done
log "Docker Volume Sicherung abgeschlossen"

# Docker Container-Konfigurationen sichern
log "Sichere Docker Container-Konfigurationen..."
if docker container ls -a --format "{{.Names}}" | xargs -I {} docker container inspect {} > $BACKUP_DIR/container_configs.json 2>> "$LOG_FILE"; then
    log "Container-Konfigurationen erfolgreich gesichert"
else
    log_error "Sicherung der Container-Konfigurationen fehlgeschlagen"
fi

# Container-Status speichern
docker container ls -a --format '{{.Names}},{{.State}}' > $BACKUP_DIR/container_states.txt
log "Container-Status gespeichert"

# Docker Images sichern
log "Starte Sicherung der Docker Images..."
for container in $(docker ps -aq); do
    name=$(docker inspect --format='{{.Name}}' $container | sed 's/\///' | tr '[:upper:]' '[:lower:]')
    original_name=$(docker inspect --format='{{.Name}}' $container | sed 's/\///')
    log "Sichere Container: $original_name"
    if docker commit $container ${name}_backup 2>> "$LOG_FILE" && \
       docker save ${name}_backup > $BACKUP_DIR/${original_name}_backup.tar 2>> "$LOG_FILE"; then
        log "Container $original_name erfolgreich gesichert"
    else
        log_error "Sicherung des Containers $original_name fehlgeschlagen"
    fi
done
log "Docker Image Sicherung abgeschlossen"

# Docker Konfigurationen sichern
log "Sichere Docker Konfigurationen..."
if cp -r $DOCKER_DIR $BACKUP_DIR/docker_configs 2>> "$LOG_FILE"; then
    log "Docker Konfigurationen erfolgreich gesichert"
else
    log_error "Sicherung der Docker Konfigurationen fehlgeschlagen"
fi

# docker-compose Dateien sichern
log "Sichere docker-compose Dateien..."
if find . -name 'docker-compose.yml' -exec cp {} $BACKUP_DIR \; 2>> "$LOG_FILE"; then
    log "docker-compose Dateien erfolgreich gesichert"
else
    log_error "Sicherung der docker-compose Dateien fehlgeschlagen"
fi

# optional verschlüsseln
if [ "$ENABLE_ENCRYPTION" = true ]; then
    log "Starte Backup-Verschlüsselung..."
    ./encrypt_backup.sh encrypt "$BACKUP_DIR"
fi

# Backup-Rotation durchführen
./cleanup_old_backups.sh

# Status-Check durchführen
./check_backup_status.sh

# Backup-Größe berechnen und protokollieren
BACKUP_SIZE=$(du -sh "$BACKUP_DIR" | cut -f1)
log "Backup erfolgreich abgeschlossen. Gesamtgröße des Backups: $BACKUP_SIZE"