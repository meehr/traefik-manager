#!/bin/bash
# ===============================================================================
# Traefik Management GUI - Helper Library
# Enthält alle 'dialog'-Definitionen für Menüs, Boxen und Eingabefelder.
# Diese Datei definiert nur das AUSSEHEN, die Logik befindet sich im Hauptskript.
# ===============================================================================

# --- Globale Dialog-Optionen ---
BACKTITLE="Traefik Management Script v4.1 (GUI)"

# --- Wrapper-Funktionen für Standard-Dialoge ---

# Zeigt eine temporäre Infobox an.
show_infobox() {
    dialog --backtitle "$BACKTITLE" --title "Info" --infobox "$1" 5 50
    sleep 2
}

# Zeigt eine Nachrichtenbox an, die der Benutzer mit OK bestätigen muss.
show_msgbox() {
    dialog --backtitle "$BACKTITLE" --title "$1" --msgbox "$2" 10 70
}

# Zeigt den Inhalt einer Datei in einer scrollbaren Textbox an.
show_textbox() {
    dialog --backtitle "$BACKTITLE" --title "$1" --textbox "$2" 22 80
}

# Stellt eine Ja/Nein-Frage.
ask_yesno() {
    dialog --backtitle "$BACKTITLE" --title "Bestätigung" --yesno "$1" 8 70
    return $?
}

# --- Menü-Definitionen ---
# Jede Funktion gibt ein 'tag' (z.B. "Install", "Config") zurück,
# das im Hauptskript in der `case`-Anweisung ausgewertet wird.

# Hauptmenü -> aufgerufen von: main()
show_main_menu() {
    dialog --clear --backtitle "$BACKTITLE" --title "Hauptmenü" \
        --menu "Bitte wählen Sie eine der folgenden Optionen:" 20 70 12 \
        "Install" "Installation & Initial Setup" \
        "Config" "Configuration & Routes" \
        "Security" "Security & Certificates" \
        "Service" "Service & Logs" \
        "Backup" "Backup & Restore" \
        "Diagnostics" "Diagnostics & Info" \
        "Automation" "Automation" \
        "Maintenance" "Maintenance & Updates" \
        "Uninstall" "Uninstall Traefik (RISK!)" \
        2>&1 >/dev/tty
}

# Untermenü: Installation -> aufgerufen von: case "Install"
show_install_menu() {
     dialog --backtitle "$BACKTITLE" --title "Installation & Initial Setup" \
        --menu "Wählen Sie eine Aktion:" 20 70 12 \
        "Install" "Install / Overwrite Traefik" \
        2>&1 >/dev/tty
}

# Untermenü: Konfiguration -> aufgerufen von: case "Config"
show_config_menu() {
    dialog --backtitle "$BACKTITLE" --title "Configuration & Routes" \
        --menu "Wählen Sie eine Konfigurations-Aktion:" 20 70 12 \
        "Add" "Add New Service / Route" \
        "Modify" "Modify Service / Route" \
        "Remove" "Remove Service / Route" \
        "---" "--------------------------------" \
        "EditStatic" "Edit Static Config (traefik.yaml)" \
        "EditMiddleware" "Edit Middleware Config (middlewares.yml)" \
        "AddPlugin" "Add Plugin (Experimental)" \
        2>&1 >/dev/tty
}

# Untermenü: Sicherheit -> aufgerufen von: case "Security"
show_security_menu() {
    dialog --backtitle "$BACKTITLE" --title "Security & Certificates" \
        --menu "Wählen Sie eine Sicherheits-Aktion:" 20 70 12 \
        "Users" "Manage Dashboard Users" \
        "Certs" "Show Certificate Details (ACME)" \
        "Expiry" "Check Cert Expiry (< 14 Days)" \
        "InsecureAPI" "Check for Insecure API" \
        "Fail2Ban" "Show Example Fail2Ban Config" \
        2>&1 >/dev/tty
}

# Untermenü: Service & Logs -> aufgerufen von: case "Service"
show_service_menu() {
     dialog --backtitle "$BACKTITLE" --title "Service & Logs" \
        --menu "Wählen Sie eine Aktion:" 20 70 12 \
        "Start" "START Traefik Service" \
        "Stop" "STOP Traefik Service" \
        "Restart" "RESTART Traefik Service" \
        "Status" "Show Traefik Service STATUS" \
        "---" "--------------------------------" \
        "LogTraefik" "View Traefik Log (traefik.log)" \
        "LogAccess" "View Access Log (access.log)" \
        "LogJournal" "View Systemd Journal Log (traefik)" \
        "LogIP" "View IP Access Log" \
        "LogAutobackup" "View Autobackup Log (Journal)" \
        "LogIPLogger" "View IP Logger Log (Journal)" \
        2>&1 >/dev/tty
}

# Untermenü: Backup & Restore -> aufgerufen von: case "Backup"
show_backup_menu() {
    dialog --backtitle "$BACKTITLE" --title "Backup & Restore" \
        --menu "Wählen Sie eine Aktion:" 20 70 12 \
        "Create" "Create Configuration Backup" \
        "Restore" "Restore Backup (CAUTION!)" \
        2>&1 >/dev/tty
}

# Untermenü: Diagnose -> aufgerufen von: case "Diagnostics"
show_diagnostics_menu() {
    dialog --backtitle "$BACKTITLE" --title "Diagnostics & Info" \
        --menu "Wählen Sie eine Diagnose-Aktion:" 20 70 12 \
        "Version" "Show Installed Traefik Version" \
        "Ports" "Check Listening Ports (ss)" \
        "Connectivity" "Test Backend Connectivity" \
        "ActiveConfig" "Show Active Config (API/jq)" \
        "Health" "Perform Health Check" \
        "CheckStatic" "Check Static Config Syntax (Hint)" \
        2>&1 >/dev/tty
}

# Untermenü: Automatisierung -> aufgerufen von: case "Automation"
show_automation_menu() {
    dialog --backtitle "$BACKTITLE" --title "Automation" \
        --menu "Wählen Sie eine Automatisierungs-Aktion:" 20 70 12 \
        "SetupBackup" "Setup/Modify Auto Backup" \
        "RemoveBackup" "Remove Automatic Backup" \
        "SetupIPLog" "Setup Dedicated IP Logging" \
        "RemoveIPLog" "Remove Dedicated IP Logging" \
        2>&1 >/dev/tty
}

# Untermenü: Wartung -> aufgerufen von: case "Maintenance"
show_maintenance_menu() {
    dialog --backtitle "$BACKTITLE" --title "Maintenance & Updates" \
        --menu "Wählen Sie eine Aktion:" 20 70 12 \
        "CheckUpdate" "Check for New Traefik Version" \
        "Update" "Update Traefik Binary (RISK!)" \
        2>&1 >/dev/tty
}
