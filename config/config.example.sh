#!/bin/bash
# config/config.sh
# Hauptverzeichnis für alle Backups
BACKUP_DIR="/home/NAME/backup"
# Pfad zur Log-Datei
LOG_FILE="$BACKUP_DIR/backup.log"
# Docker-spezifische Pfade
DOCKER_DIR="/etc/docker"
DOCKER_VOLUMES_DIR="/var/lib/docker/volumes"
HOME_DIR="/home"
# Optional: HOME-Verzeichnis Backup aktivieren/deaktivieren
BACKUP_HOME=false
# Optional: Ausschlüsse vom Backup
EXCLUDE_DIRS=(
    "$BACKUP_DIR"
    "/home/NAME/Folder"
)
