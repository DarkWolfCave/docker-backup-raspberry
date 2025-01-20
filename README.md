# Docker Backup für Raspberry Pi

Ein Set von Skripten zum vollständigen Backup und Restore von Docker-Umgebungen auf einem Raspberry Pi.

## Features

- Vollständiges Backup aller Docker Container (laufend und gestoppt)
- Sicherung aller Docker Volumes
- Backup von Konfigurationsdateien
- Sicherung des HOME-Verzeichnisses
- Backup der Crontabs
- Detailliertes Logging
- Wiederherstellungsfunktion

## Voraussetzungen

- Docker installiert
- Root-Rechte für die Ausführung
- Ausreichend Speicherplatz für Backups

## Installation

```bash
git clone https://github.com/DarkWolfCave/docker-backup-raspberry.git
cd docker-backup-raspberry
cp config/config.example.sh config/config.sh
# Konfiguration in config.sh anpassen
chmod +x scripts/*.sh
