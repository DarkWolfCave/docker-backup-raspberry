#!/bin/bash

# Skript: update_user_in_docker_config.sh
# Beschreibung: Dieses Skript sucht in der container_configs.json nach Pfaden
# mit einem spezifischen Benutzernamen im HOME-Verzeichnis und ersetzt diesen
# durch einen neuen Benutzernamen, wie in den Docker-Volume-Bindings konfiguriert.

# Prüfen, ob die erforderlichen Argumente (Backup-Verzeichnis, alter Benutzername, neuer Benutzername) vorhanden sind
if [ "$#" -ne 3 ]; then
    echo "Verwendung: $0 <Backup-Verzeichnis> <AlterBenutzername> <NeuerBenutzername>"
    exit 1
fi

# Übernehme die Argumente
BACKUP_DIR="$1"
ORIGINAL_USER="$2"
NEW_USER="$3"
CONFIG_FILE="$BACKUP_DIR/container_configs.json"

# Überprüfen, ob die Datei container_configs.json existiert
if [ -f "$CONFIG_FILE" ]; then
    echo "Aktualisiere Benutzernamen in der container_configs.json..."
    # Verwendung von 'sed' zum Ersetzen des alten Benutzernamens durch den neuen in spezifischen Pfaden
    sed -i "s|/home/${ORIGINAL_USER}|/home/${NEW_USER}|g" "$CONFIG_FILE"
    echo "Benutzername in der container_configs.json von ${ORIGINAL_USER} zu ${NEW_USER} geändert"
else
    echo "container_configs.json nicht im angegebenen Verzeichnis gefunden: $BACKUP_DIR"
    exit 1
fi

echo "Benutzeraktualisierung abgeschlossen."
