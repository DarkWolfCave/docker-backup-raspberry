#!/bin/bash
# scripts/docker_restore.sh
#
# Erstellt von: DarkWolfCave
# Version: 1.1.1
# Erstellt am: Januar 2025
# Letzte Änderung: 25.01.2025
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

# Hilfsfunktionen für Container und Volume Wiederherstellung
restore_single_container() {
    local backup_dir="$1"
    local container_name="$2"

    if [ ! -f "$backup_dir/${container_name}_backup.tar" ]; then
        log_error "Backup für Container $container_name nicht gefunden"
        return 1
    fi

    log "Stelle Container $container_name wieder her..."

    # Lade Container-Image
    if docker load < "$backup_dir/${container_name}_backup.tar" 2>> "$RESTORE_LOG_FILE"; then
        # Erstelle und starte Container
        if docker create --name "$container_name" "${container_name}_backup" 2>> "$RESTORE_LOG_FILE"; then
            log "Container $container_name erfolgreich wiederhergestellt"

            # Prüfe ob Container vorher lief
            if grep -q "$container_name,running" "$backup_dir/container_states.txt"; then
                docker start "$container_name" 2>> "$RESTORE_LOG_FILE"
                log "Container $container_name gestartet"
            fi
        else
            log_error "Fehler beim Erstellen des Containers $container_name"
            return 1
        fi
    else
        log_error "Fehler beim Laden des Images für $container_name"
        return 1
    fi
}

restore_single_volume() {
    local backup_dir="$1"
    local volume_name="$2"

    if [ ! -f "$backup_dir/${volume_name}.tar.gz" ]; then
        log_error "Backup für Volume $volume_name nicht gefunden"
        return 1
    fi

    log "Stelle Volume $volume_name wieder her..."

    if docker volume create "$volume_name" 2>> "$RESTORE_LOG_FILE" && \
       docker run --rm -v "$volume_name":/volume -v "$backup_dir":/backup ubuntu \
       tar -xzf "/backup/${volume_name}.tar.gz" -C /volume 2>> "$RESTORE_LOG_FILE"; then
        log "Volume $volume_name erfolgreich wiederhergestellt"
    else
        log_error "Fehler beim Wiederherstellen des Volumes $volume_name"
        return 1
    fi
}

# Parameter verarbeiten
while [[ $# -gt 0 ]]; do
    case $1 in
        --container)
            RESTORE_CONTAINER="$2"
            shift 2
            ;;
        --volume)
            RESTORE_VOLUME="$2"
            shift 2
            ;;
        *)
            INPUT_PATH="$1"  # Speichere den Eingabepfad
            shift
            ;;
    esac
done

# Prüfe ob ein Pfad angegeben wurde
if [ -z "$INPUT_PATH" ]; then
    echo "Bitte Backup-Verzeichnis angeben"
    echo "Verwendung: $0 /pfad/zum/backup/YYYY-MM-DD_HH-MM-SS"
    exit 1
fi

# Prüfe Root-Rechte
if [ "$EUID" -ne 0 ]; then
    log_error "Bitte als Root ausführen"
    exit 1
fi

# Prüfe ob Docker installiert ist und installiere es bei Bedarf
if ! command -v docker &> /dev/null; then
    log "Docker ist nicht installiert. Bitte installiere dies zuerst und richte es entsprechend für den Start ein"
    log "Anleitung findest du unter anderem hier: https://darkwolfcave.de/raspberry-pi-docker-ohne-probleme-installieren/"
    exit 1
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

# Setze Restore-Datum
RESTORE_DATE=$(date +%Y-%m-%d_%H-%M-%S)

# Prüfe ob es sich um ein verschlüsseltes Backup handelt
if [[ "$INPUT_PATH" == *.tar.gpg ]]; then
    log "Verschlüsseltes Backup erkannt"
    password_file="/root/.backup_password"

    if [ ! -f "$password_file" ]; then
        log_error "Keine Passwortdatei gefunden in $password_file"
        log_error "Stellen Sie sicher, dass die originale Passwortdatei vorhanden ist"
        exit 1
    fi

    # Erstelle temporäres Verzeichnis für entschlüsseltes Backup
    temp_dir=$(dirname "$INPUT_PATH")/temp_decrypt_$(date +%s)
    mkdir -p "$temp_dir"

    log "Entschlüssele Backup..."
    log "Temporäres Verzeichnis: $temp_dir"

    if gpg --batch --yes --passphrase-file "$password_file" \
        --decrypt "$INPUT_PATH" 2>/dev/null | \
        tar -xzf - -C "$temp_dir" 2>/dev/null; then

        log "Inhalt des temp_dir nach Entschlüsselung:"
        ls -la "$temp_dir" >> "$RESTORE_LOG_FILE"

        # Finde das tatsächliche Backup-Verzeichnis in der verschachtelten Struktur
        BACKUP_DIR=$(find "$temp_dir" -type d -name "2???-??-??_*" -o -name "backup_*" | sort | tail -n1)

        if [ -z "$BACKUP_DIR" ]; then
            log_error "Konnte kein gültiges Backup-Verzeichnis nach Entschlüsselung finden"
            log_error "Verzeichnisinhalt:"
            ls -R "$temp_dir" | tee -a "$RESTORE_LOG_FILE"
            rm -rf "$temp_dir"
            exit 1
        fi

        log "Backup-Verzeichnis gefunden: $BACKUP_DIR"
    else
        log_error "Fehler bei der Entschlüsselung"
        rm -rf "$temp_dir"
        exit 1
    fi
else
    BACKUP_DIR="$INPUT_PATH"
fi

# Entdecke alle Benutzerverzeichnisse im Backup
declare -a users

echo "Ermittle Benutzernamen aus dem Backup..."

# Extrahiere Benutzernamen
while IFS= read -r line; do
  user=$(echo "$line" | cut -d'/' -f2)
  # Überprüfe, ob der Benutzername in der Liste vorhanden ist und füge ihn hinzu, falls nötig
  if [[ ! " ${users[@]} " =~ " ${user} " ]]; then
      users+=("$user")
  fi
done < <(tar -tzf "$BACKUP_DIR/home.tar.gz" | grep '^./[^/]\+/')

# Zeige gefundene Benutzernamen
echo "Gefundene Benutzerverzeichnisse:"
for i in "${!users[@]}"; do
    echo "$(($i + 1)): ${users[$i]}"
done

# Erlaube dem Benutzer, einen Namen auszuwählen
read -p "Bitte wählen Sie den ursprünglichen Benutzer, um ihn zu ändern (1-${#users[@]}): " choice

# Überprüfe die Benutzerauswahl
if [[ "$choice" =~ ^[0-9]+$ && "$choice" -ge 1 && "$choice" -le "${#users[@]}" ]]; then
    original_user="${users[$((choice - 1))]}"
    log "Ausgewählter Benutzer: $original_user"
else
    log_error "Ungültige Auswahl. Abbruch."
    exit 1
fi

# Bestätigen oder ändern des Benutzernamens
echo "Aktueller Benutzername für die Wiederherstellung ist: $RESTORE_USER"
read -p "Möchtest du diesen Benutzernamen ändern? (ja/Nein): " confirm
# Standard auf "Nein" setzen, falls keine Eingabe
confirm=${confirm:-nein}
if [[ "$confirm" =~ ^[Jj]([Aa])?$ ]]; then
    read -p "Gib den neuen Benutzernamen ein: " input_username
    if [ -n "$input_username" ]; then
        RESTORE_USER="$input_username"
        log "Der Benutzername wurde geändert. Neuer Benutzername: $RESTORE_USER"
    else
        log "Keine Eingabe. Der Benutzername bleibt: $RESTORE_USER"
    fi
else
    log "Der Benutzername wurde nicht geändert. Aktueller Benutzername: $RESTORE_USER"
fi

# Aufruf des Update-Skripts mit den Benutzernamen zur Aktualisierung der Docker-Konfigurationen
UPDATE_SCRIPT="$SCRIPT_DIR/update_user_in_docker_config.sh"
if [ -x "$UPDATE_SCRIPT" ]; then
    echo "Rufe Update-Skript auf, um Benutzernamen in container_configs.json zu ändern..."
    "$UPDATE_SCRIPT" "$BACKUP_DIR" "$original_user" "$RESTORE_USER"
    if [ $? -eq 0 ]; then
        log "Benutzernamen in container_configs.json von $original_user zu $RESTORE_USER erfolgreich ersetzt"
    else
        log_error "Fehler beim Ausführen des Update-Skripts"
    fi
else
    log_error "Update-Skript nicht gefunden oder nicht ausführbar: $UPDATE_SCRIPT"
fi

# Prüfe ob Backup-Verzeichnis existiert
if [ ! -d "$BACKUP_DIR" ]; then
    log_error "Backup-Verzeichnis existiert nicht: $BACKUP_DIR"
    exit 1
fi
log "Starte Wiederherstellung aus $BACKUP_DIR"

# Prüfe ob nur einzelne Container oder Volumes wiederhergestellt werden sollen
SKIP_GENERAL_RESTORE=false
if [ -n "$RESTORE_CONTAINER" ]; then
    restore_single_container "$BACKUP_DIR" "$RESTORE_CONTAINER"
    SKIP_GENERAL_RESTORE=true
fi

if [ -n "$RESTORE_VOLUME" ]; then
    restore_single_volume "$BACKUP_DIR" "$RESTORE_VOLUME"
    SKIP_GENERAL_RESTORE=true
fi

if ! $SKIP_GENERAL_RESTORE; then
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

        # Extrahiere mit Pfadumleitung
        if tar --warning=no-file-ignored --exclude="$EXCLUDE_DIR" -xvzf "$BACKUP_DIR/home.tar.gz" \
           --transform "s|^./${original_user}|./$RESTORE_USER|" -C "$HOME_DIR" | while read -r file; do
            # Logge jeden Pfad, der aus dem Archiv extrahiert wird
            log "Wiederhergestellt mit neuem Pfad: ${file/$original_user/$RESTORE_USER}"
        done 2>> "$RESTORE_LOG_FILE"; then
            log "HOME-Verzeichnis erfolgreich wiederhergestellt mit Benutzeranpassung"
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
        if [ -f "$BACKUP_DIR/container_states.txt" ]; then
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
        if chown -R $RESTORE_USER:$RESTORE_USER "$HOME_DIR/$RESTORE_USER" 2>> "$RESTORE_LOG_FILE"; then
            log "Berechtigungen für Benutzer $RESTORE_USER korrigiert"
        else
            log_error "Fehler beim Korrigieren der Berechtigungen für Benutzer $RESTORE_USER"
        fi
fi
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

# Aufräumen bei verschlüsselten Backups
if [[ "$INPUT_PATH" == *.tar.gpg ]]; then
    log "Räume temporäre Dateien auf..."
    rm -rf "$temp_dir"
    log "Aufräumen abgeschlossen"
fi
