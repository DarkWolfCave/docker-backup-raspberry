# 🚨 Docker Backup Wiederherstellung - Notfall-Anleitung

## Übersicht
Diese Anleitung hilft dir dabei, deine Docker-Container nach einem Systemausfall wiederherzustellen.

---

## 📋 Voraussetzungen
- Raspberry Pi mit frischem System
- Backup-Verzeichnis mit gesicherten Daten
- Root-Zugriff (sudo)

---

## 🔍 Schritt 1: Backup finden

**Suche nach deinen Backups:**
```bash
# Schaue ins Standard-Backup-Verzeichnis
ls -la /home/pi/backup/

# Oder suche überall nach Backup-Verzeichnissen
find / -name "*backup*" -type d 2>/dev/null
```

**Was du suchst:**
- Verzeichnisse wie: `2025-01-25_15-30-45`
- Oder verschlüsselte Dateien: `2025-01-25_15-30-45.tar.gpg`

**Notiere dir den vollständigen Pfad!** (z.B. `/home/pi/backup/2025-01-25_15-30-45`)

---

## ⚙️ Schritt 2: Konfiguration einrichten

**1. Konfigurationsdatei erstellen:**
```bash
cp config/config.example config/config
```

**2. Konfiguration bearbeiten:**
```bash
nano config/config
```

**3. Wichtige Einstellungen anpassen:**
```bash
# Backup-Verzeichnis (wo deine Backups liegen)
BACKUP_BASE_DIR="/home/pi/backup"

# Benutzername für Wiederherstellung (meist "pi")
RESTORE_USER="pi"

# HOME-Backup aktiviert (true/false)
BACKUP_HOME=true
```

**Speichern:** `Strg+X` → `Y` → `Enter`

---

## 🐳 Schritt 3: Docker installieren

**Falls Docker noch nicht installiert ist:**

```bash
# System aktualisieren
sudo apt update && sudo apt upgrade -y

# Docker installieren
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Benutzer zur Docker-Gruppe hinzufügen
sudo usermod -aG docker pi

# Docker starten
sudo systemctl start docker
sudo systemctl enable docker

# Testen
sudo docker --version
```

**Wichtig:** Nach der Installation einmal neu anmelden!

---

## 🔧 Schritt 4: Skripte vorbereiten

**Skripte ausführbar machen:**
```bash
chmod +x scripts/*.sh
```
|
---

## 🔄 Schritt 5: Wiederherstellung starten

**Restore-Befehl ausführen:**
```bash
sudo ./scripts/docker_restore.sh /home/pi/backup/2025-01-25_15-30-45
```

**Ersetze den Pfad mit deinem tatsächlichen Backup-Pfad!**

---

## 📝 Schritt 6: Was passiert beim Restore

Das Skript fragt dich nach:

1. **Ursprünglicher Benutzername** aus dem Backup
   - Wähle aus der Liste (meist Option 1)
   
2. **Neuer Benutzername** für die Wiederherstellung
   - Meist einfach "pi" eingeben

**Das Skript stellt dann wieder her:**
- ✅ Crontabs (geplante Aufgaben)
- ✅ HOME-Verzeichnis (Benutzerdaten)
- ✅ Docker Volumes (Container-Daten)
- ✅ Docker Images (Container-Programme)
- ✅ Container (mit korrektem Status)
- ✅ Berechtigungen

---

## 📊 Schritt 7: Überprüfung

**Nach dem Restore prüfen:**

```bash
# Alle Container anzeigen
sudo docker ps -a

# Alle Volumes anzeigen
sudo docker volume ls

# Alle Images anzeigen
sudo docker images

# Restore-Log anzeigen
cat /home/pi/backup/restore.log
```

**Erwartetes Ergebnis:**
- Container sind wiederhergestellt (laufend oder gestoppt)
- Volumes sind vorhanden
- Images sind geladen
- Log zeigt "erfolgreich abgeschlossen"

---

## 🆘 Bei Problemen

### Docker startet nicht:
```bash
sudo systemctl status docker
sudo systemctl restart docker
```

### Container starten nicht:
```bash
# Container-Logs anzeigen
sudo docker logs <container_name>

# Container manuell starten
sudo docker start <container_name>
```

### Berechtigungsprobleme:
```bash
sudo chown -R pi:pi /home/pi
```

### Logs überwachen:
```bash
# Während des Restores
tail -f /home/pi/backup/restore.log
```

---

## 📞 Support

**Bei Problemen:**
1. Schaue ins Log: `/home/pi/backup/restore.log`
2. Kopiere die Fehlermeldungen
3. Kontaktiere den Support

---

## ✅ Checkliste

- [ ] Backup-Verzeichnis gefunden
- [ ] Backup-Pfad notiert
- [ ] Konfiguration angepasst
- [ ] Docker installiert und läuft
- [ ] Skripte ausführbar gemacht
- [ ] Restore-Befehl ausgeführt
- [ ] Benutzername korrekt eingegeben
- [ ] Container und Volumes geprüft
- [ ] Alles funktioniert

---

## 🎯 Beispiel-Befehle

```bash
# Backup finden
ls -la /home/pi/backup/

# Konfiguration erstellen
cp config/config.example config/config

# Docker installieren
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Restore starten
sudo ./scripts/docker_restore.sh /home/pi/backup/2025-01-25_15-30-45

# Status prüfen
sudo docker ps -a
```

---

## ⚠️ Wichtiger Hinweis: Port-Wiederherstellung

**NEU:** Das Restore-Script stellt jetzt automatisch Ports, Volumes und Environment-Variablen aus der `container_configs.json` wieder her!

### Voraussetzung: jq installieren

```bash
# jq ist erforderlich für die Config-Parser-Funktion
sudo apt-get update
sudo apt-get install -y jq
```

**Ohne jq:** Container werden ohne Ports/Volumes erstellt (alte Methode)
**Mit jq:** Container werden vollständig mit allen Settings wiederhergestellt ✅

### Nach dem Restore prüfen

```bash
# Prüfe ob Ports korrekt gemappt sind
docker ps

# Du solltest sehen:
# 0.0.0.0:9000->9000/tcp  (Portainer)
# 0.0.0.0:9981->9981/tcp  (TVHeadend)
# etc.
```

### Falls Ports fehlen

Wenn Container ohne Ports laufen (nur "8000/tcp" statt "0.0.0.0:8000->8000/tcp"):

1. **jq installieren** (siehe oben)
2. **Container neu erstellen:**
   ```bash
   docker stop <container_name>
   docker rm <container_name>
   # Dann Restore nochmal ausführen für diesen Container
   sudo ./scripts/docker_restore.sh /pfad/zum/backup --container <container_name>
   ```

### Architektur-Hinweis: 32-bit vs 64-bit

**Wenn du Probleme mit "ELF not properly aligned" oder "Exit Code 159" hast:**

- Dein System ist **32-bit (armhf)** aber das Backup enthält **64-bit (arm64)** Images
- **Lösung:** Upgrade auf 64-bit Raspberry Pi OS (empfohlen!)
- **Alternative:** Verwende explizit 32-bit Images mit `--platform linux/arm/v7`

**64-bit System (empfohlen):**
- ✅ Keine Architektur-Probleme
- ✅ Bessere Performance
- ✅ Alle arm64 Images laufen nativ

---

**💡 Tipp:** Das System führt dich durch den gesamten Prozess. Folge einfach den Anweisungen auf dem Bildschirm!
