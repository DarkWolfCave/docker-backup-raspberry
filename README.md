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
cp config/config.example config/config
# Konfiguration in config.sh anpassen
nano config/config
chmod +x scripts/*.sh
```

## Was wird gesichert?

- Docker Container (laufend und gestoppt)
- Docker Images
- Docker Volumes
- Docker Konfigurationen
- HOME Verzeichnis (optional)
- Crontabs aller Benutzer
- docker-compose Dateien

## Verwendung

### Backup erstellen:
```bash
sudo ./scripts/docker_backup.sh
```

### Backup wiederherstellen:
```bash
sudo ./scripts/docker_restore.sh /path/to/backup/YYYY-MM-DD_HH-MM-SS
```

### Beispiel für einen Cron-Job:
```bash
# Tägliches Backup um 3 Uhr morgens
0 3 * * * /pfad/zu/scripts/docker_backup.sh
```

## Konfiguration

Kopiere `config.example` nach `config` und passe die Werte an:
- BACKUP_BASE_DIR: Verzeichnis für die Backups
- LOG_FILE: Pfad zur Backup-Log-Datei
- RESTORE_LOG_FILE: Pfad zur Restore-Log-Datei
- DOCKER_DIR: Pfad zu Docker (in der Regel keine Änderung notwendig)
- DOCKER_VOLUMES_DIR Pfad zu Docker-Volumes (in der Regel keine Änderung notwendig)
- HOME_DIR: Pfad zu den HOME-Verzeichnissen ((in der Regel keine Änderung notwendig))
- BACKUP_HOME:  false=HOME wird NICHT gesichert / true=HOME wird gesichert
- EXCLUDE_DIRS: Verzeichnisse die ausgeschlossen werden beim Backup (immer das BACKUP-Verzeichnis selbst ausschließen!)

## Logging

Die Skripte erstellen detaillierte Logs:
- Backup-Log: `backup.log` im Backup-Verzeichnis
- Restore-Log: `restore.log` im Backup-Verzeichnis

## Fehlerbehandlung

Die Skripte prüfen:
- Root-Rechte
- Existenz der Backup-Verzeichnisse
- Erfolg jeder Operation
- Fehlermeldungen werden im Log festgehalten
- Zusammenfassung am Ende des Restore-Vorgangs

## Lizenz

Copyright (c) 2024 DarkWolfCave.de

Dieses Projekt steht unter einer benutzerdefinierten Lizenz mit folgenden Bedingungen:

1. **Urheberrechtshinweis:** Der ursprüngliche Urheberrechtshinweis und dieser Lizenztext müssen in allen Kopien oder wesentlichen Teilen des Skripts enthalten bleiben.

2. **Verbot des Weiterverkaufs:** Der Verkauf dieses Skripts, ob in seiner ursprünglichen oder modifizierten Form, ist untersagt. Eine kommerzielle Nutzung ist nur nach ausdrücklicher schriftlicher Genehmigung des Autors gestattet.

3. **Integration in andere Projekte:** Die Integration dieses Skripts in andere Projekte ist nur erlaubt, wenn das Skript als eigenständige Komponente erkennbar bleibt und die oben genannten Bedingungen eingehalten werden.

4. **Haftungsausschluss:** DIESES SKRIPT WIRD OHNE JEGLICHE GEWÄHRLEISTUNG, AUSDRÜCKLICH ODER IMPLIZIT, BEREITGESTELLT. DER AUTOR HAFTET NICHT FÜR IRGENDWELCHE SCHÄDEN ODER FOLGESCHÄDEN, DIE DURCH DIE NUTZUNG DES SKRIPTS ENTSTEHEN.

Vollständige Lizenzbedingungen siehe [LICENSE](LICENSE)

## Autor

DarkWolfCave
- Website: https://darkwolfcave.de
- GitHub: https://github.com/DarkWolfCave

## Support

Bei Fragen oder Problemen kannst du:
- Ein Issue auf GitHub erstellen
- Die Dokumentation auf der Website konsultieren
- Mich über [Discord](https://discord.gg/neyGWMUdjQ) erreichen 

## Changelog

Für detaillierte Informationen über alle Änderungen und Versionen, siehe das [Changelog](CHANGELOG.md).
