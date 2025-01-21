#!/bin/bash
# scripts/encrypt_backup.sh

source "$(dirname "$0")/../config/config"

# Prüfe ob gpg installiert ist
if ! command -v gpg &> /dev/null; then
    echo "GPG ist nicht installiert. Installiere mit: sudo apt-get install gpg"
    exit 1
fi

# Verschlüssele ein Backup-Verzeichnis
encrypt_backup() {
    local backup_dir="$1"
    local output_file="${backup_dir}.tar.gpg"

    echo "Verschlüssele Backup: $backup_dir"

    # Erstelle verschlüsseltes Archiv
    tar -czf - "$backup_dir" | \
    gpg --symmetric --cipher-algo AES256 \
        --output "$output_file"

    if [ $? -eq 0 ]; then
        echo "Backup erfolgreich verschlüsselt: $output_file"
        # Optional: Lösche ursprüngliches Backup
        # rm -rf "$backup_dir"
    else
        echo "Fehler bei der Verschlüsselung"
        exit 1
    fi
}

# Entschlüssele ein Backup
decrypt_backup() {
    local encrypted_file="$1"
    local output_dir="${encrypted_file%.tar.gpg}"

    echo "Entschlüssele Backup: $encrypted_file"

    gpg --decrypt "$encrypted_file" | \
    tar -xzf - -C "$(dirname "$encrypted_file")"

    if [ $? -eq 0 ]; then
        echo "Backup erfolgreich entschlüsselt: $output_dir"
            else
                echo "Fehler bei der Entschlüsselung"
                exit 1
            fi
        }

        # Parameter-Handling
        case "$1" in
            encrypt)
                if [ -z "$2" ]; then
                    echo "Backup-Verzeichnis angeben"
                    echo "Verwendung: $0 encrypt /pfad/zum/backup"
                    exit 1
                fi
                encrypt_backup "$2"
                ;;
            decrypt)
                if [ -z "$2" ]; then
                    echo "Verschlüsseltes Backup angeben"
                    echo "Verwendung: $0 decrypt /pfad/zum/backup.tar.gpg"
                    exit 1
                fi
                decrypt_backup "$2"
                ;;
            *)
                echo "Verwendung: $0 {encrypt|decrypt} /pfad/zum/backup"
                exit 1
                ;;
        esac
