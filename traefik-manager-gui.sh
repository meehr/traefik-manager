#!/bin/bash
# ===============================================================================
# Traefik Management Script - Vollständige GUI-Version
# Version: 4.1 (Full GUI)
# ===============================================================================
# Author: Martin Ehrentraut
# Unterstützt von: fbnlrz, Traefik Team, AI Assistants
# Based on: Traefik Manager from fbnlrz (Thanks for the inspiration!)
# Date: 2025-06-19
# ===============================================================================
#
# DOKUMENTATION:
# Dieses Skript dient als Haupt-Controller für die GUI-Anwendung.
#
# PROGRAMMFLUSS:
# 1. Abhängigkeiten prüfen: Stellt sicher, dass 'dialog' installiert ist.
# 2. Konfiguration & Module laden: Alle Konfigurationsvariablen und Funktionen
#    werden aus den `conf/`, `lib/` und `modules/` Verzeichnissen geladen.
# 3. Hauptschleife:
#    a. Ruft `show_main_menu` aus `lib/gui_helpers.sh` auf, um das Menü anzuzeigen.
#    b. Wertet die Auswahl des Benutzers in einer `case`-Anweisung aus.
#    c. Ruft entweder direkt eine Funktion aus einem Modul auf oder zeigt ein
#       entsprechendes Untermenü (z.B. `show_automation_menu`).
#
# AUSGABEN BEHANDELN:
# Die Standardausgabe der Funktionen aus den Modulen wird in eine temporäre Datei
# umgeleitet (`/tmp/traefik_manager.log`). Der Inhalt dieser Datei wird dann in
# einer `dialog --textbox` angezeigt. Dies verhindert, dass die GUI durch
# direkte `echo`-Befehle "zerstört" wird.
#
# ERWEITERN DES SKRIPTS:
# 1. Neue Funktion erstellen: Fügen Sie eine neue Funktion in einer der
#    `modules/*.sh`-Dateien hinzu (z.B. eine neue Diagnose in `diagnostics.sh`).
# 2. Menüpunkt hinzufügen: Öffnen Sie `lib/gui_helpers.sh` und fügen Sie
#    einen neuen Eintrag im entsprechenden Menü hinzu (z.B. im `show_diagnostics_menu`).
# 3. Logik im Hauptskript hinzufügen: Fügen Sie in `traefik-manager-gui.sh`
#    im entsprechenden `case`-Block einen neuen Eintrag hinzu, der Ihre neue
#    Funktion aufruft und die Ausgabe in einer Textbox anzeigt.
# ===============================================================================

# --- Pfad zum Skriptverzeichnis und temporäre Datei ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
TMP_LOG="/tmp/traefik_manager.log"

# --- Konfiguration und Bibliotheken laden ---
source "${SCRIPT_DIR}/conf/traefik-manager.conf"
source "${SCRIPT_DIR}/lib/helpers.sh"
source "${SCRIPT_DIR}/lib/dependencies.sh"
source "${SCRIPT_DIR}/lib/gui_helpers.sh" # NEU: GUI-Helfer laden

# Alle Module laden
for module in "${SCRIPT_DIR}"/modules/*.sh; do
    if [ -f "$module" ]; then
        source "$module"
    fi
done

# --- GUI-Abhängigkeit prüfen ---
ensure_gui_dependencies() {
    if ! command -v dialog &> /dev/null; then
        echo "Das Programm 'dialog' wird für die GUI benötigt, ist aber nicht installiert."
        read -p "Möchten Sie es jetzt installieren (sudo apt install dialog)? [j/n] " choice
        if [[ "$choice" == "j" || "$choice" == "J" ]]; then
            sudo apt-get update && sudo apt-get install -y dialog
            if ! command -v dialog &> /dev/null; then exit 1; fi
        else
            exit 1
        fi
        clear
    fi
}

# --- Wrapper zum Ausführen und Anzeigen von Funktionen ---
# Diese Funktion kapselt den Aufruf einer Modul-Funktion und die Anzeige der Ausgabe.
# Verwendung: run_and_show "Titel der Box" "funktions_name" "arg1" "arg2" ...
run_and_show() {
    local title="$1"
    # Entfernt den Titel aus der Argumentenliste, der Rest ist der Befehl.
    shift
    
    # Führt den Befehl aus und leitet stdout & stderr in die temporäre Log-Datei um.
    # Das `&>` ist eine Kurzform für `> ... 2>&1`.
    "$@" &> "$TMP_LOG"
    
    # Zeigt den Inhalt der Log-Datei in einer Textbox an.
    show_textbox "$title" "$TMP_LOG"
}

# --- Live-Log-Anzeige ---
# 'dialog --tailbox' ist perfekt für Live-Logs.
show_live_log() {
    local title="$1"
    local file_or_cmd="$2"

    # Prüfen, ob eine Datei existiert. Wenn nicht, als Befehl behandeln.
    if [[ -f "$file_or_cmd" ]]; then
        dialog --backtitle "$BACKTITLE" --title "$title" --tailbox "$file_or_cmd" 22 80
    else
        # Führt den Befehl aus und leitet die Ausgabe an die tailbox.
        # Nützlich für `journalctl -f`.
        eval "$file_or_cmd" | dialog --backtitle "$BACKTITLE" --title "$title" --programbox 22 80
    fi
}


# --- Hauptlogik ---
main() {
    ensure_gui_dependencies
    check_root

    while true; do
        main_menu_choice=$(show_main_menu)
        exit_status=$?

        # Beenden, wenn der Benutzer 'ESC' oder 'Cancel' drückt.
        if [ $exit_status -ne 0 ]; then
            clear
            echo "Skript beendet."
            exit 0
        fi

        case "$main_menu_choice" in
            Install)
                local choice; choice=$(show_install_menu)
                if [[ "$choice" == "Install" ]]; then
                    # Die Installationsfunktion ist interaktiv und benötigt kein run_and_show
                    # Sie wird direkt im Terminal ausgeführt.
                    clear
                    install_traefik
                    show_msgbox "Abschluss" "Installation beendet.\n\nDrücken Sie OK, um zum Hauptmenü zurückzukehren."
                fi
                ;;
            Config)
                local choice; choice=$(show_config_menu)
                case "$choice" in
                    Add) clear; add_service; show_msgbox "Info" "Prozess beendet." ;;
                    Modify) clear; modify_service ;;
                    Remove) run_and_show "Remove Service" remove_service ;;
                    EditStatic) clear; edit_static_config ;;
                    EditMiddleware) clear; edit_middlewares_config ;;
                    AddPlugin) clear; install_plugin; show_msgbox "Info" "Prozess beendet." ;;
                esac
                ;;
            Security)
                local choice; choice=$(show_security_menu)
                case "$choice" in
                    Users) clear; manage_dashboard_users ;;
                    Certs) run_and_show "Certificate Details" show_certificate_info ;;
                    Expiry) run_and_show "Certificate Expiry Check" check_certificate_expiry ;;
                    InsecureAPI) run_and_show "Insecure API Check" check_insecure_api ;;
                    Fail2Ban) run_and_show "Fail2Ban Example" generate_fail2ban_config ;;
                esac
                ;;
            Service)
                local choice; choice=$(show_service_menu)
                case "$choice" in
                    Start) run_and_show "Service Start" manage_service "start" ;;
                    Stop) run_and_show "Service Stop" manage_service "stop" ;;
                    Restart) run_and_show "Service Restart" manage_service "restart" ;;
                    Status) run_and_show "Service Status" manage_service "status" ;;
                    LogTraefik) show_live_log "Traefik Log" "${TRAFIK_LOG_DIR}/traefik.log" ;;
                    LogAccess) show_live_log "Access Log" "${TRAFIK_LOG_DIR}/access.log" ;;
                    LogJournal) show_live_log "Systemd Journal (traefik)" "sudo journalctl -u ${TRAEFIK_SERVICE_NAME} -f" ;;
                    LogIP) show_live_log "IP Access Log" "$IP_LOG_FILE" ;;
                    LogAutobackup) show_live_log "Autobackup Log" "sudo journalctl -u ${AUTOBACKUP_SERVICE} -f" ;;
                    LogIPLogger) show_live_log "IP Logger Log" "sudo journalctl -u ${IPLOGGER_SERVICE} -f" ;;
                esac
                ;;
            Backup)
                local choice; choice=$(show_backup_menu)
                case "$choice" in
                    Create) run_and_show "Create Backup" backup_traefik false ;;
                    Restore) clear; restore_traefik; show_msgbox "Info" "Prozess beendet." ;;
                esac
                ;;
            Diagnostics)
                local choice; choice=$(show_diagnostics_menu)
                case "$choice" in
                    Version) run_and_show "Traefik Version" show_traefik_version ;;
                    Ports) run_and_show "Listening Ports" check_listening_ports ;;
                    Connectivity) clear; test_backend_connectivity; show_msgbox "Info" "Prozess beendet." ;;
                    ActiveConfig) run_and_show "Active Config (API)" show_active_config ;;
                    Health) run_and_show "Health Check" health_check ;;
                    CheckStatic) run_and_show "Check Static Config" check_static_config ;;
                esac
                ;;
            Automation)
                local choice; choice=$(show_automation_menu)
                case "$choice" in
                    SetupBackup) run_and_show "Setup Auto Backup" setup_autobackup ;;
                    RemoveBackup) run_and_show "Remove Auto Backup" remove_autobackup ;;
                    SetupIPLog) run_and_show "Setup IP Logging" setup_ip_logging ;;
                    RemoveIPLog) run_and_show "Remove IP Logging" remove_ip_logging ;;
                esac
                ;;
            Maintenance)
                local choice; choice=$(show_maintenance_menu)
                case "$choice" in
                    CheckUpdate) run_and_show "Check for Updates" check_traefik_updates ;;
                    Update) clear; update_traefik_binary; show_msgbox "Info" "Prozess beendet." ;;
                esac
                ;;
            Uninstall)
                if ask_yesno "Dies wird Traefik vollständig von Ihrem System entfernen.\n\nDiese Aktion kann nicht rückgängig gemacht werden.\n\nSind Sie absolut sicher?"; then
                    run_and_show "Deinstallationsprotokoll" uninstall_traefik
                else
                    show_infobox "Deinstallation abgebrochen."
                fi
                ;;
        esac
    done
}

# --- Skriptstart ---
# Bereinigt temporäre Dateien beim Beenden des Skripts (egal wie).
trap "rm -f $TMP_LOG 2>/dev/null" EXIT

# Hauptfunktion aufrufen
main "$@"
