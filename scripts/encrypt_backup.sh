#!/bin/bash
# scripts/encrypt_backup.sh

source "$(dirname "$0")/../config/config"

# Logging-Funktion
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Prüfe ob gpg installiert ist
if ! command -v gpg &> /dev/null; then
    log "GPG ist nicht installiert. Installiere mit: sudo apt-get install gpg"
    exit 1
fi

# Verschlüssele ein Backup-Verzeichnis
encrypt_backup() {
    local backup_dir="$1"
    local output_file="${backup_dir}.tar.gpg"
    local password_file="/root/.backup_password"
    
    # Wenn keine Passwortdatei existiert, erstelle eine
    if [ ! -f "$password_file" ]; then
        # Generiere ein zufälliges 32-Zeichen-Passwort
        log "Erstelle neue Backup-Verschlüsselungs-Passwortdatei"
        openssl rand -base64 32 > "$password_file"
        chmod 600 "$password_file"
    fi
    
    log "Verschlüssele Backup: $backup_dir"
    
    # Erstelle verschlüsseltes Archiv mit Passwort aus Datei
    if tar -czf - "$backup_dir" 2>/dev/null | gpg --batch --yes --passphrase-file "$password_file" \
        --symmetric --cipher-algo AES256 \
        --output "$output_file" 2>/dev/null; then
        
        log "Backup erfolgreich verschlüsselt: $output_file"
        
        # Optional: Lösche ursprüngliches Backup
        # rm -rf "$backup_dir"
        return 0
    else
        log "Fehler bei der Verschlüsselung"
        return 1
    fi
}

# Entschlüssele ein Backup
decrypt_backup() {
    local encrypted_file="$1"
    local output_dir="${encrypted_file%.tar.gpg}"
    local password_file="/root/.backup_password"
    
    if [ ! -f "$password_file" ]; then
        log "FEHLER: Keine Passwortdatei gefunden!"
        return 1
    fi
    
    log "Entschlüssele Backup: $encrypted_file"
    
    if gpg --batch --yes --passphrase-file "$password_file" \
        --decrypt "$encrypted_file" 2>/dev/null | \
        tar -xzf - -C "$(dirname "$encrypted_file")" 2>/dev/null; then
        
        log "Backup erfolgreich entschlüsselt: $output_dir"
        return 0
    else
        log "Fehler bei der Entschlüsselung"
        return 1
    fi
}

# Parameter-Handling
case "$1" in
    encrypt)
        if [ -z "$2" ]; then
            log "Backup-Verzeichnis angeben"
            log "Verwendung: $0 encrypt /pfad/zum/backup"
            exit 1
        fi
        encrypt_backup "$2"
        exit $?
        ;;
    decrypt)
        if [ -z "$2" ]; then
            log "Verschlüsseltes Backup angeben"
            log "Verwendung: $0 decrypt /pfad/zum/backup.tar.gpg"
            exit 1
        fi
        decrypt_backup "$2"
        exit $?
        ;;
    *)
        log "Verwendung: $0 {encrypt|decrypt} /pfad/zum/backup"
        exit 1
        ;;
esac
