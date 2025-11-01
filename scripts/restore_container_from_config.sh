#!/bin/bash
# scripts/restore_container_from_config.sh
#
# Erstellt von: DarkWolfCave
# Version: 1.0.0
# Erstellt am: 2025-11-01
#
# Beschreibung:
# Dieses Script erstellt Docker Container aus der container_configs.json
# mit allen Ports, Volumes, Environment-Variablen und Restart-Policies
#
# Verwendung:
# restore_container_from_config.sh <backup_dir> <container_name> <log_file>

BACKUP_DIR="$1"
CONTAINER_NAME="$2"
LOG_FILE="${3:-/dev/null}"

# Prüfe ob jq installiert ist
if ! command -v jq &> /dev/null; then
    echo "FEHLER: jq ist nicht installiert. Installiere mit: apt-get install jq" | tee -a "$LOG_FILE"
    exit 1
fi

# Finde die Container-Config in der JSON (es gibt mehrere JSON Arrays)
CONFIG_FILE="$BACKUP_DIR/container_configs.json"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "FEHLER: container_configs.json nicht gefunden" | tee -a "$LOG_FILE"
    exit 1
fi

# Parse die Config - die JSON hat mehrere Arrays, wir müssen sie alle durchsuchen
CONTAINER_JSON=$(cat "$CONFIG_FILE" | jq -s ".[].[] | select(.Name == \"/$CONTAINER_NAME\" or .Name == \"$CONTAINER_NAME\")")

if [ -z "$CONTAINER_JSON" ]; then
    echo "WARNUNG: Keine Config für Container $CONTAINER_NAME gefunden, verwende Fallback" | tee -a "$LOG_FILE"
    # Fallback: Erstelle Container nur mit Image
    docker create --name "$CONTAINER_NAME" "${CONTAINER_NAME}_backup" 2>> "$LOG_FILE"
    exit $?
fi

# Extrahiere wichtige Werte
IMAGE=$(echo "$CONTAINER_JSON" | jq -r '.Config.Image // empty')
RESTART_POLICY=$(echo "$CONTAINER_JSON" | jq -r '.HostConfig.RestartPolicy.Name // "no"')

# Baue den docker run Befehl auf
DOCKER_CMD="docker run -d --name $CONTAINER_NAME"

# Restart Policy
if [ "$RESTART_POLICY" != "no" ] && [ -n "$RESTART_POLICY" ]; then
    DOCKER_CMD="$DOCKER_CMD --restart $RESTART_POLICY"
fi

# Port Bindings
PORTS=$(echo "$CONTAINER_JSON" | jq -r '.HostConfig.PortBindings // {} | to_entries[] | "-p " + (.value[0].HostPort // "") + ":" + (.key | split("/")[0])')
if [ -n "$PORTS" ]; then
    DOCKER_CMD="$DOCKER_CMD $PORTS"
fi

# Volume Binds
BINDS=$(echo "$CONTAINER_JSON" | jq -r '.HostConfig.Binds[]? // empty | "-v " + .')
if [ -n "$BINDS" ]; then
    DOCKER_CMD="$DOCKER_CMD $BINDS"
fi

# Environment Variables (nur die wichtigen, nicht alle System-Vars)
ENV_VARS=$(echo "$CONTAINER_JSON" | jq -r '.Config.Env[]? // empty | select(startswith("TZ=") or startswith("PUID=") or startswith("PGID=") or startswith("TIMEZONE=") or startswith("USER_ID=") or startswith("GROUP_ID=") or startswith("WATCHTOWER_")) | "-e " + .')
if [ -n "$ENV_VARS" ]; then
    DOCKER_CMD="$DOCKER_CMD $ENV_VARS"
fi

# User (falls gesetzt)
USER=$(echo "$CONTAINER_JSON" | jq -r '.Config.User // empty')
if [ -n "$USER" ]; then
    DOCKER_CMD="$DOCKER_CMD -u $USER"
fi

# Image - verwende das Backup-Image
DOCKER_CMD="$DOCKER_CMD ${CONTAINER_NAME}_backup:latest"

# Logge den Befehl
echo "Erstelle Container mit: $DOCKER_CMD" >> "$LOG_FILE"

# Führe aus
eval $DOCKER_CMD 2>> "$LOG_FILE"
EXIT_CODE=$?

if [ $EXIT_CODE -eq 0 ]; then
    echo "Container $CONTAINER_NAME erfolgreich erstellt" | tee -a "$LOG_FILE"
else
    echo "FEHLER beim Erstellen von Container $CONTAINER_NAME (Exit Code: $EXIT_CODE)" | tee -a "$LOG_FILE"
fi

exit $EXIT_CODE
