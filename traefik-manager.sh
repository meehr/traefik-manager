#!/bin/bash
# ===============================================================================
# Traefik Management Script - Unified Controller
# Version: 6.0 (Unified CLI and GUI)
# Author: Martin Ehrentraut
# Unterstützt von: fbnlrz, Traefik Team, AI Assistants
# Based on: Traefik Manager from fbnlrz (Thanks for the inspiration!)
# Date: 2025-06-19
# ===============================================================================

# --- Pfad zum Skriptverzeichnis und temporäre Datei ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
TMP_LOG="/tmp/traefik_manager.log"

# --- Alle Konfigurationen und Bibliotheken laden ---
source "${SCRIPT_DIR}/conf/traefik-manager.conf"
source "${SCRIPT_DIR}/lib/helpers.sh"
source "${SCRIPT_DIR}/lib/dependencies.sh"
source "${SCRIPT_DIR}/lib/gui_helpers.sh"
source "${SCRIPT_DIR}/lib/cli_handler.sh"

# Alle Module laden
for module in "${SCRIPT_DIR}"/modules/*.sh; do
    if [ -f "$module" ]; then
        source "$module"
    fi
done

# --- GUI-Modus ---
start_gui_mode() {
    ensure_gui_dependencies
    
    # Wrapper-Funktionen für die GUI
    run_and_show() {
        local title="$1"; shift
        "$@" &> "$TMP_LOG"
        show_textbox "$title" "$TMP_LOG"
    }

    show_live_log() {
        local title="$1"; local file_or_cmd="$2"
        if [[ -f "$file_or_cmd" ]]; then
            dialog --backtitle "$BACKTITLE" --title "$title" --tailbox "$file_or_cmd" 22 80
        else
            eval "$file_or_cmd" | dialog --backtitle "$BACKTITLE" --title "$title" --programbox 22 80
        fi
    }

    # Hauptschleife für die GUI
    while true; do
        main_menu_choice=$(show_main_menu)
        exit_status=$?
        if [ $exit_status -ne 0 ]; then
            clear; echo "Skript beendet."; exit 0
        fi

        case "$main_menu_choice" in
            Install)
                local choice; choice=$(show_install_menu)
                if [[ "$choice" == "Install" ]]; then
                    clear; install_traefik; show_msgbox "Abschluss" "Installation beendet."
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
                    LogTraefik) show_live_log "Traefik Log" "${TRAEFIK_LOG_DIR}/traefik.log" ;;
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
                if ask_yesno "Dies wird Traefik vollständig von Ihrem System entfernen.\n\nSind Sie absolut sicher?"; then
                    run_and_show "Deinstallationsprotokoll" uninstall_traefik
                else
                    show_infobox "Deinstallation abgebrochen."
                fi
                ;;
        esac
    done
}

# --- Interaktiver CLI-Modus (Vollständig implementiert) ---
start_interactive_cli() {
    while true; do
        print_header "Main Menu - Traefik Management"
        echo -e "${BOLD}1)${NC} Installation & Initial Setup"
        echo -e "${BOLD}2)${NC} Configuration & Routes"
        echo -e "${BOLD}3)${NC} Security & Certificates"
        echo -e "${BOLD}4)${NC} Service & Logs"
        echo -e "${BOLD}5)${NC} Backup & Restore"
        echo -e "${BOLD}6)${NC} Diagnostics & Info"
        echo -e "${BOLD}7)${NC} Automation"
        echo -e "${BOLD}8)${NC} Maintenance & Updates"
        echo "-----------------------------------------"
        echo -e "${BOLD}9)${NC} Uninstall Traefik ${RED}(RISK!)${NC}"
        echo "-----------------------------------------"
        echo -e "${BOLD}0)${NC} Exit Script"
        echo ""
        read -p "Your choice [0-9]: " main_choice

        local sub_choice=0 # Wird auf 1 gesetzt, wenn eine Aktion stattfindet, die eine Pause erfordert
        case "$main_choice" in
            1) # Installation
                clear; print_header "Installation & Initial Setup"
                echo -e "1) Install / Overwrite Traefik"; echo "0) Back"
                read -p "Choice: " sub_choice_val
                if [[ "$sub_choice_val" == 1 ]]; then install_traefik; sub_choice=1; fi
                ;;
            2) # Config
                clear; print_header "Configuration & Routes"
                echo "1) Add New Service"; echo "2) Modify Service"; echo "3) Remove Service"; echo "---"; echo "4) Edit Static Config"; echo "5) Edit Middleware Config"; echo "6) Add Plugin"; echo "0) Back"
                read -p "Choice: " sub_choice_val
                case "$sub_choice_val" in
                    1) add_service; sub_choice=1 ;;
                    2) modify_service; sub_choice=1 ;;
                    3) remove_service; sub_choice=1 ;;
                    4) edit_static_config; sub_choice=1 ;;
                    5) edit_middlewares_config; sub_choice=1 ;;
                    6) install_plugin; sub_choice=1 ;;
                esac
                ;;
            3) # Security
                clear; print_header "Security & Certificates"
                echo "1) Manage Dashboard Users"; echo "2) Show Certificate Details"; echo "3) Check Cert Expiry"; echo "4) Check for Insecure API"; echo "5) Show Fail2Ban Example"; echo "0) Back"
                read -p "Choice: " sub_choice_val
                case "$sub_choice_val" in
                    1) manage_dashboard_users; sub_choice=1 ;; # Hat eigene Schleife/Pause
                    2) show_certificate_info; sub_choice=1 ;;
                    3) check_certificate_expiry; sub_choice=1 ;;
                    4) check_insecure_api; sub_choice=1 ;;
                    5) generate_fail2ban_config; sub_choice=1 ;;
                esac
                ;;
            4) # Service
                clear; print_header "Service & Logs"
                echo "1) Start"; echo "2) Stop"; echo "3) Restart"; echo "4) Status"; echo "---"; echo "5) View Traefik Log"; echo "6) View Access Log"; echo "7) View Journal"; echo "0) Back"
                read -p "Choice: " sub_choice_val
                case "$sub_choice_val" in
                    1) manage_service "start"; sub_choice=1 ;;
                    2) manage_service "stop"; sub_choice=1 ;;
                    3) manage_service "restart"; sub_choice=1 ;;
                    4) manage_service "status"; sub_choice=1 ;;
                    5) view_logs "traefik" ;; # Hat eigene Schleife
                    6) view_logs "access" ;; # Hat eigene Schleife
                    7) view_logs "journal" ;; # Hat eigene Schleife
                esac
                ;;
            9) # Uninstall
                uninstall_traefik; sub_choice=1 ;;
            0)
                echo "Exiting script. Goodbye!"; exit 0 ;;
            *)
                echo -e "${RED}ERROR: Invalid choice '$main_choice'.${NC}" >&2; sub_choice=1 ;;
        esac

        # Nur pausieren, wenn eine Aktion stattgefunden hat.
        if [[ "$sub_choice" -ne 0 ]]; then
             echo ""; read -p "... Press Enter for main menu ..."
        fi
    done
}

# --- Haupt-Controller ---
main() {
    check_root
    check_dependencies
    
    # GUI-Modus prüfen
    if [[ "$1" == "--gui" ]]; then
        start_gui_mode
        exit 0
    fi

    # CLI-Befehle verarbeiten
    # handle_cli_args gibt 1 zurück, wenn keine Argumente verarbeitet wurden.
    handle_cli_args "$@"
    if [ $? -eq 0 ]; then
        exit 0 # Erfolgreich beendet nach CLI-Befehl
    fi

    # Interaktiven CLI-Modus starten, wenn keine Befehle übergeben wurden
    start_interactive_cli
}

# --- Skriptstart ---
trap "rm -f $TMP_LOG 2>/dev/null" EXIT
main "$@"
