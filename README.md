# Traefik Manager - Umfassende Anleitung

## Inhaltsverzeichnis

- [Traefik Manager - Umfassende Anleitung](#traefik-manager---umfassende-anleitung)
  - [Inhaltsverzeichnis](#inhaltsverzeichnis)
  - [Einführung](#einführung)
  - [Verzeichnisstruktur](#verzeichnisstruktur)
  - [Installation \& Ersteinrichtung](#installation--ersteinrichtung)
    - [Voraussetzungen](#voraussetzungen)
    - [Einrichtung](#einrichtung)
  - [Nutzung der Grafischen Oberfläche (GUI)](#nutzung-der-grafischen-oberfläche-gui)
    - [Starten der GUI](#starten-der-gui)
    - [Navigation](#navigation)
    - [Menü-Übersicht](#menü-übersicht)
  - [Nutzung der Kommandozeilen-Oberfläche (CLI)](#nutzung-der-kommandozeilen-oberfläche-cli)
  - [Automatisierung (Cronjob / Timer)](#automatisierung-cronjob--timer)
  - [Konfiguration anpassen](#konfiguration-anpassen)
  - [Das Skript erweitern](#das-skript-erweitern)
    - [Menüpunkt in der GUI-Hilfsdatei hinzufügen:](#menüpunkt-in-der-gui-hilfsdatei-hinzufügen)
    - [Logik im Hauptskript verbinden:](#logik-im-hauptskript-verbinden)
  - [Fehlerbehebung](#fehlerbehebung)

## Einführung

Der Traefik Manager ist eine Sammlung von Bash-Skripten, die entwickelt wurden, um die Verwaltung einer Traefik v3 Instanz auf einem Debian-basierten System zu vereinfachen. Das Skript bietet eine umfassende Lösung für Installation, Konfiguration, Dienstverwaltung, Backup, Automatisierung und Wartung.

Es gibt zwei Möglichkeiten, das Skript zu bedienen:

Grafische Benutzeroberfläche (GUI): Eine benutzerfreundliche, menügeführte Oberfläche, die auf dem Tool dialog basiert. Sie wird für die tägliche Nutzung empfohlen.

Kommandozeilen-Interface (CLI): Eine klassische, auf Zahleneingaben basierende Menüführung.

## Verzeichnisstruktur

Das Projekt ist modular aufgebaut, um die Wartung und Erweiterbarkeit zu erleichtern.

```bash
traefik-manager/
├── traefik-manager-gui.sh    # HAUPTSKRIPT: Startet die grafische Oberfläche
├── traefik-manager.sh        # Startet die klassische Kommandozeilen-Oberfläche
|
├── conf/
│   └── traefik-manager.conf  # Zentrale Konfigurationsdatei mit allen Pfaden & Variablen
|
├── lib/
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

## Installation & Ersteinrichtung

### Voraussetzungen

Stellen Sie sicher, dass die folgenden Pakete auf Ihrem System installiert sind. Das Skript wird versuchen, fehlende Pakete bei der ersten Ausführung nachzuinstallieren, aber eine manuelle Installation im Voraus kann nicht schaden.

```bash
sudo apt update
sudo apt install dialog curl jq apache2-utils netcat-openbsd openssl yamllint
```

dialog: Wird für die GUI-Version zwingend benötigt.

### Einrichtung

Klonen oder Herunterladen: Laden Sie das gesamte traefik-manager-Verzeichnis auf Ihr System, z.B. in das Home-Verzeichnis Ihres Benutzers.

Ausführbar machen: Machen Sie die beiden Hauptskripte ausführbar:

```bash
cd /pfad/zum/traefik-manager
chmod +x traefik-manager-gui.sh
chmod +x traefik-manager.sh
```

Als root ausführen: Das Skript muss mit sudo ausgeführt werden, da es Systemdateien und -dienste verwaltet.

```bash
sudo ./traefik-manager-gui.sh
```

## Nutzung der Grafischen Oberfläche (GUI)

Dies ist die empfohlene Methode zur Interaktion mit dem Skript.

### Starten der GUI

Führen Sie das Skript mit sudo aus:

```bash
sudo ./traefik-manager-gui.sh
```

### Navigation

Pfeiltasten (Hoch/Runter): Navigation innerhalb der Menüs.

Enter: Auswählen eines Menüpunktes.

Tab: Wechseln zwischen Knöpfen (z.B. "Ja"/"Nein").

Esc: Aktuelles Menü/Dialogbox verlassen oder das Skript beenden.

### Menü-Übersicht

Die GUI leitet Sie durch alle verfügbaren Aktionen. Die meisten nicht-interaktiven Funktionen (wie z.B. "Status anzeigen") leiten ihre Ausgabe in eine temporäre Datei um und zeigen diese anschließend in einer scrollbaren Textbox an. So bleibt die Oberfläche sauber.

- Installation & Initial Setup: Führt Sie durch die Erstinstallation von Traefik. Dieser Prozess ist interaktiv und findet direkt im Terminal statt.

- Configuration & Routes: Hier können Sie neue Routen zu Ihren Diensten anlegen, bestehende ändern oder löschen. Sie können auch die zentralen Konfigurationsdateien direkt bearbeiten.

- Security & Certificates: Verwalten Sie Benutzer für das Traefik-Dashboard, prüfen Sie Ihre Let's Encrypt-Zertifikate oder lassen Sie sich eine Beispielkonfiguration für Fail2Ban anzeigen.

- Service & Logs: Starten, stoppen und starten Sie den Traefik-Dienst neu. Hier können Sie auch alle relevanten Log-Dateien live einsehen (tail -f).

- Backup & Restore: Erstellen Sie ein Backup Ihres gesamten /opt/traefik-Verzeichnisses oder stellen Sie ein früheres Backup wieder her.

- Diagnostics & Info: Nützliche Werkzeuge zur Fehlerbehebung, z.B. ein Health Check, Port-Prüfung oder Konnektivitätstests zu Ihren Backend-Diensten.

- Automation: Richten Sie systemd-Timer ein, um z.B. tägliche Backups oder eine regelmäßige IP-Protokollierung zu automatisieren.

- Maintenance & Updates: Suchen Sie nach neuen Traefik-Versionen und führen Sie das Update direkt aus dem Skript durch.

- Uninstall Traefik: Entfernt Traefik und alle zugehörigen Konfigurationen, Dienste und Logs vollständig vom System. Diese Aktion kann nicht rückgängig gemacht werden!

## Nutzung der Kommandozeilen-Oberfläche (CLI)

Für Puristen oder in Umgebungen, in denen dialog nicht verfügbar ist, kann die klassische CLI-Version verwendet werden.

```bash
sudo ./traefik-manager.sh
```

Die Navigation erfolgt durch die Eingabe der entsprechenden Ziffer und das Drücken der Enter-Taste. Die Menüstruktur und die verfügbaren Funktionen sind identisch mit der GUI-Version.

## Automatisierung (Cronjob / Timer)

Das Skript ist darauf ausgelegt, auch nicht-interaktiv ausgeführt zu werden. Dies ist besonders für die Backup-Funktion nützlich.

Automatisches Backup: Die empfohlene Methode ist die Einrichtung über das Menü 7 (Automation). Dies erstellt einen systemd-Timer, der die Backup-Funktion täglich aufruft.

Manuelle Einrichtung (z.B. Cronjob): Sie können die Backup-Funktion auch manuell über einen Cronjob aufrufen.

```bash
# Führt jeden Tag um 3:00 Uhr nachts ein Backup durch.
0 3 * * * /usr/bin/sudo /pfad/zum/traefik-manager/traefik-manager.sh --run-backup >> /var/log/traefik_autobackup.log 2>&1
```

Der Befehl hierfür lautet:

```bash
/pfad/zum/traefik-manager/traefik-manager.sh --run-backup
```

## Konfiguration anpassen

Die zentrale Konfigurationsdatei für das Skript selbst ist conf/traefik-manager.conf. Hier können Sie globale Pfade anpassen, falls Ihre Verzeichnisstruktur von den Standardwerten abweicht.

## Das Skript erweitern

Dank des modularen Aufbaus ist das Skript einfach zu erweitern. Um eine neue Funktion hinzuzufügen, folgen Sie diesen drei Schritten:

Funktion im Modul erstellen:
Schreiben Sie Ihre neue Bash-Funktion in der passenden Modul-Datei (z.B. eine neue Diagnosefunktion in modules/diagnostics.sh).

### Menüpunkt in der GUI-Hilfsdatei hinzufügen:

Öffnen Sie lib/gui_helpers.sh und fügen Sie einen neuen Menüeintrag in der entsprechenden show_*_menu-Funktion hinzu.
Beispiel:

```bash
# in show_diagnostics_menu()
"MeineFunktion" "Eine tolle neue Diagnose" \
```

### Logik im Hauptskript verbinden:

Öffnen Sie traefik-manager-gui.sh. Suchen Sie die case-Anweisung für das entsprechende Menü und fügen Sie einen neuen Fall für Ihr neues "tag" (MeineFunktion) hinzu. Rufen Sie dort Ihre neue Funktion auf.
Beispiel:

```bash
# in 'case "$main_menu_choice" in Diagnostics ...'
case "$choice" in
    # ... andere Fälle
    MeineFunktion) run_and_show "Meine neue Diagnose" meine_neue_funktion ;;
esac
```

Die run_and_show-Funktion kümmert sich automatisch darum, die Ausgabe Ihrer Funktion in einer Textbox anzuzeigen.

## Fehlerbehebung

- GUI wird nicht angezeigt: Stellen Sie sicher, dass das Paket dialog installiert ist.
- Funktionen schlagen fehl: Führen Sie das Skript immer mit sudo aus.
- Letzte Ausgabe prüfen: Das Skript leitet die Ausgabe der meisten Aktionen in eine temporäre Datei /tmp/traefik_manager.log um. Wenn ein Dialog zu schnell verschwindet, können Sie den Inhalt dieser Datei überprüfen, um die letzte Ausgabe zu sehen.
- Pfade kontrollieren: Stellen Sie sicher, dass die Pfade in conf/traefik-manager.conf mit Ihrer Systemkonfiguration übereinstimmen.
