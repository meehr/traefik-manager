# Traefik Manager - Umfassende Anleitung

## Inhaltsverzeichnis
- [Traefik Manager - Umfassende Anleitung](#traefik-manager---umfassende-anleitung)
  - [Inhaltsverzeichnis](#inhaltsverzeichnis)
    - [1. Einführung](#1-einführung)
    - [2. Verzeichnisstruktur](#2-verzeichnisstruktur)
    - [3. Installation \& Ersteinrichtung](#3-installation--ersteinrichtung)
      - [Voraussetzungen](#voraussetzungen)
      - [Einrichtung](#einrichtung)
    - [4. Nutzung des Skripts](#4-nutzung-des-skripts)
      - [Starten der Grafischen Oberfläche (GUI)](#starten-der-grafischen-oberfläche-gui)
      - [Starten des interaktiven CLI-Menüs](#starten-des-interaktiven-cli-menüs)
      - [Direkte Befehlsausführung (CLI)](#direkte-befehlsausführung-cli)
    - [5. Automatisierung (Cronjob / Timer)](#5-automatisierung-cronjob--timer)
    - [6. Konfiguration anpassen](#6-konfiguration-anpassen)
    - [7. Das Skript erweitern](#7-das-skript-erweitern)
    - [8. Fehlerbehebung](#8-fehlerbehebung)

---

### 1. Einführung

Der Traefik Manager ist eine Sammlung von Bash-Skripten, die entwickelt wurden, um die Verwaltung einer Traefik v3 Instanz auf einem Debian-basierten System zu vereinfachen. Das Skript bietet eine umfassende Lösung für Installation, Konfiguration, Dienstverwaltung, Backup, Automatisierung und Wartung.

Es wird über ein einziges Hauptskript, `traefik-manager.sh`, bedient, das drei verschiedene Ausführungsmodi unterstützt:
* **Grafische Benutzeroberfläche (GUI):** Eine benutzerfreundliche, menügeführte Oberfläche, die auf dem Tool `dialog` basiert. Dies ist die empfohlene Methode für die interaktive Nutzung.
* **Interaktives Kommandozeilen-Interface (CLI):** Eine klassische, auf Zahleneingaben basierende Menüführung für Umgebungen ohne GUI.
* **Direkte Befehlsausführung:** Für die Automatisierung und schnelle, gezielte Aktionen können Funktionen direkt als Kommandozeilen-Argumente aufgerufen werden.

### 2. Verzeichnisstruktur

Das Projekt ist modular aufgebaut, um die Wartung und Erweiterbarkeit zu erleichtern.

```
traefik-manager/
├── traefik-manager.sh        # DAS EINZIGE HAUPTSKRIPT: Steuert alle Modi
|
├── conf/
│   └── traefik-manager.conf  # Zentrale Konfigurationsdatei mit allen Pfaden & Variablen
|
├── lib/
│   ├── cli_handler.sh        # Verarbeitet alle direkten Kommandozeilen-Argumente
│   ├── gui_helpers.sh        # Definiert das Aussehen aller GUI-Menüs
│   ├── helpers.sh            # Allgemeine Hilfsfunktionen (z.B. Farbausgabe)
│   └── dependencies.sh       # Funktionen zur Überprüfung von Abhängigkeiten
|
└── modules/
    ├── install.sh            # Installation und Deinstallation von Traefik
    ├── config.sh             # Hinzufügen, Ändern, Entfernen von Routen
    ├── service.sh            # Steuerung des systemd-Dienstes & Log-Anzeige
    ├── backup.sh             # Backup- und Wiederherstellungsfunktionen
    ├── security.sh           # Benutzerverwaltung, Zertifikatsinfos etc.
    ├── diagnostics.sh        # Diagnosewerkzeuge (Port-Prüfung, Health Check)
    ├── automation.sh         # Einrichtung von systemd-Timern (Autobackup, etc.)
    └── maintenance.sh        # Update-Prüfung und Aktualisierung
```

### 3. Installation & Ersteinrichtung

#### Voraussetzungen

Stellen Sie sicher, dass die folgenden Pakete auf Ihrem System installiert sind. Das Skript wird versuchen, fehlende Pakete bei der ersten Ausführung nachzuinstallieren.

```bash
sudo apt update
sudo apt install dialog curl jq apache2-utils netcat-openbsd openssl yamllint
```

* `dialog`: Wird für die GUI-Version zwingend benötigt.

#### Einrichtung

1. **Klonen oder Herunterladen:** Laden Sie das gesamte `traefik-manager`-Verzeichnis auf Ihr System.

2. **Ausführbar machen:** Machen Sie das Hauptskript ausführbar:

   ```bash
   cd /pfad/zum/traefik-manager
   chmod +x traefik-manager.sh
   ```

3. **Als `root` ausführen:** Das Skript muss mit `sudo` ausgeführt werden, da es Systemdateien und -dienste verwaltet.

### 4. Nutzung des Skripts

#### Starten der Grafischen Oberfläche (GUI)

Dies ist die empfohlene Methode für die interaktive Nutzung.

```bash
sudo ./traefik-manager.sh --gui
```

* **Navigation:** Pfeiltasten, Enter zum Auswählen, Esc zum Verlassen.

#### Starten des interaktiven CLI-Menüs

Starten Sie das Skript ohne Argumente, um das klassische, textbasierte Menü zu erhalten.

```bash
sudo ./traefik-manager.sh
```

* **Navigation:** Ziffer eingeben und mit Enter bestätigen.

#### Direkte Befehlsausführung (CLI)

Für Automatisierung und schnelle Aktionen. Rufen Sie `sudo ./traefik-manager.sh help` auf, um eine Liste aller Befehle zu sehen.

**Beispiele:**

```bash
# Startet den Traefik-Dienst
sudo ./traefik-manager.sh start

# Erstellt ein Backup (nicht-interaktiv)
sudo ./traefik-manager.sh backup

# Zeigt das Access-Log live an
sudo ./traefik-manager.sh logs access
```

### 5. Automatisierung (Cronjob / Timer)

Das Skript ist darauf ausgelegt, auch nicht-interaktiv ausgeführt zu werden.

* **Automatisches Backup:** Die empfohlene Methode ist die Einrichtung über das **Menü 7 (Automation)** in der GUI oder CLI. Dies erstellt einen `systemd`-Timer.

* **Manuelle Einrichtung (z.B. Cronjob):**

  ```cron
  # Führt jeden Tag um 3:00 Uhr nachts ein Backup durch.
  0 3 * * * /usr/bin/sudo /pfad/zum/traefik-manager/traefik-manager.sh backup >> /var/log/traefik_autobackup.log 2>&1
  ```

### 6. Konfiguration anpassen

Die zentrale Konfigurationsdatei für das Skript selbst ist `conf/traefik-manager.conf`. Hier können Sie globale Pfade anpassen.

### 7. Das Skript erweitern

Um eine neue Funktion als direkten CLI-Befehl und Menüpunkt hinzuzufügen:

1. **Funktion im Modul erstellen:**
   Schreiben Sie Ihre neue Bash-Funktion in der passenden Modul-Datei (z.B. eine neue Funktion `meine_funktion` in `modules/diagnostics.sh`).

2. **CLI-Befehl hinzufügen:**
   Öffnen Sie `lib/cli_handler.sh` und fügen Sie einen neuen `case` für Ihren Befehl hinzu.
   *Beispiel:*

   ```bash
   # in handle_cli_args()
   case "$cmd" in
       # ... andere Befehle
       meine-funktion) meine_funktion ;;
   esac
   ```

   Aktualisieren Sie auch die `show_cli_help`-Funktion, um Ihren neuen Befehl zu dokumentieren.

3. **GUI-Menüpunkt hinzufügen (optional):**
   Öffnen Sie `lib/gui_helpers.sh` und fügen Sie einen Eintrag in der entsprechenden `show_*_menu`-Funktion hinzu.

4. **Logik im Hauptskript verbinden (optional):**
   Öffnen Sie `traefik-manager.sh`. Fügen Sie in den `case`-Anweisungen für die GUI (`start_gui_mode`) und CLI (`start_interactive_cli`) einen neuen Eintrag hinzu, der Ihre Funktion aufruft.

### 8. Fehlerbehebung

* **GUI wird nicht angezeigt:** Stellen Sie sicher, dass das Paket `dialog` installiert ist.

* **Funktionen schlagen fehl:** Führen Sie das Skript immer mit `sudo` aus.

* **Letzte Ausgabe prüfen (GUI):** Die Ausgabe der meisten Aktionen wird in `/tmp/traefik_manager.log` gespeichert. Wenn ein Dialog zu schnell verschwindet, können Sie diese Datei prüfen.

* **Pfade kontrollieren:** Stellen Sie sicher, dass die Pfade in `conf/traefik-manager.conf` korrekt sind.
