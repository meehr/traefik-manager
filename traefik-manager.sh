#!/bin/bash
# ===============================================================================
# Traefik Management Script - Main Controller
# Version: 4.0 (Modular without GUI)
# Author: Martin Ehrentraut
# Unterstützt von: fbnlrz, Traefik Team, AI Assistants
# Based on: Traefik Manager from fbnlrz (Thanks for the inspiration!)
# Date: 2025-06-19
#
# DOKUMENTATION:
# Dieses Skript dient als Haupt-Controller für die Traefik Management Anwendung.
# Installation, Konfiguration und Verwaltung von Traefik werden hier zentral gesteuert.
# IP-Logging, Autobackup und weitere Funktionen sind modular aufgebaut. (Without Git functions)
# ===============================================================================

# --- Pfad zum Skriptverzeichnis ermitteln ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

# --- Konfiguration und Bibliotheken laden ---
# Prüfen, ob die Konfigurationsdatei existiert
if [ ! -f "${SCRIPT_DIR}/conf/traefik-manager.conf" ]; then
    echo "FEHLER: Konfigurationsdatei nicht gefunden: ${SCRIPT_DIR}/conf/traefik-manager.conf" >&2
    exit 1
fi
source "${SCRIPT_DIR}/conf/traefik-manager.conf"

# Hilfsfunktionen und Module laden
source "${SCRIPT_DIR}/lib/helpers.sh"
source "${SCRIPT_DIR}/lib/dependencies.sh"

for module in "${SCRIPT_DIR}"/modules/*.sh; do
    if [ -f "$module" ]; then
        source "$module"
    fi
done

# --- Argument-Parsing für nicht-interaktiven Modus ---
declare -g non_interactive_mode=false
if [[ "$1" == "--run-backup" ]]; then
    non_interactive_mode=true
    # Die Funktion wird nach der Überprüfung der Root-Rechte aufgerufen
fi

# --- Hauptlogik ---
main() {
    if $non_interactive_mode && [[ "$1" == "--run-backup" ]]; then
        if declare -F backup_traefik > /dev/null; then
            echo "[$(date +'%Y-%m-%d %H:%M:%S')] Running non-interactive backup via ${SCRIPT_PATH}..."
            backup_traefik true # Funktion mit nicht-interaktivem Flag aufrufen
            local exit_code=$?
            echo "[$(date +'%Y-%m-%d %H:%M:%S')] Non-interactive backup finished with exit code ${exit_code}."
            exit $exit_code
        else
            echo "[$(date +'%Y-%m-%d %H:%M:%S')] CRITICAL ERROR: backup_traefik function not defined." >&2
            exit 1
        fi
    fi

    # Nur im interaktiven Modus das Menü anzeigen
    if ! $non_interactive_mode; then
        check_root
        check_dependencies # Abhängigkeiten direkt zu Beginn prüfen

        while true; do
            print_header "Main Menu - Traefik Management"
            echo -e "| ${CYAN}1) Installation & Initial Setup    ${NC} |"
            echo -e "| ${CYAN}2) Configuration & Routes          ${NC} |"
            echo -e "| ${CYAN}3) Security & Certificates         ${NC} |"
            echo -e "| ${CYAN}4) Service & Logs                  ${NC} |"
            echo -e "| ${CYAN}5) Backup & Restore                ${NC} |"
            echo -e "| ${CYAN}6) Diagnostics & Info              ${NC} |"
            echo -e "| ${CYAN}7) Automation                      ${NC} |"
            echo -e "| ${CYAN}8) Maintenance & Updates           ${NC} |"
            echo "|-----------------------------------------|"
            echo -e "|   ${BOLD}9)${NC} Uninstall Traefik ${RED}(RISK!)      ${NC} |"
            echo "|-----------------------------------------|"
            echo -e "|   ${BOLD}0)${NC} Exit Script                     ${NC} |"
            echo "+-----------------------------------------+";
            read -p "Your choice [0-9]: " main_choice

            local sub_choice=-1

            case "$main_choice" in
                1) # --- Installation Submenu ---
                    clear; print_header "Installation & Initial Setup";
                    echo -e "|   ${BOLD}1)${NC} Install / Overwrite Traefik        |";
                    echo "|-----------------------------------------|";
                    echo -e "|   ${BOLD}0)${NC} Back                               |";
                    echo "+-----------------------------------------+";
                    read -p "Choice [0-1]: " sub_choice
                    case "$sub_choice" in 1) install_traefik ;; 0) ;; *) echo -e "${RED}Invalid choice.${NC}" >&2 ;; esac ;;
                2) # --- Config & Routes Submenu ---
                    clear; print_header "Configuration & Routes";
                    echo -e "|   ${BOLD}1)${NC} Add New Service / Route            |";
                    echo -e "|   ${BOLD}2)${NC} Modify Service / Route             |";
                    echo -e "|   ${BOLD}3)${NC} Remove Service / Route             |";
                    echo "|-----------------------------------------|";
                    echo -e "|   ${BOLD}4)${NC} Edit Static Config (...)           |";
                    echo -e "|   ${BOLD}5)${NC} Edit Middleware Config (...)       |";
                    echo -e "|   ${BOLD}6)${NC} Edit EntryPoints (...)             |";
                    echo -e "|   ${BOLD}7)${NC} Edit Global TLS Opts (...)         |";
                    echo -e "|   ${BOLD}8)${NC} Add Plugin (Experimental)          |";
                    echo "|-----------------------------------------|";
                    echo -e "|   ${BOLD}0)${NC} Back                               |";
                    echo "+-----------------------------------------+";
                    read -p "Choice [0-8]: " sub_choice
                    case "$sub_choice" in 1) add_service ;; 2) modify_service ;; 3) remove_service ;; 4) edit_static_config ;; 5) edit_middlewares_config ;; 6) edit_entrypoints ;; 7) edit_tls_options ;; 8) install_plugin ;; 0) ;; *) echo -e "${RED}Invalid choice.${NC}" >&2 ;; esac ;;
                3) # --- Security & Certificates Submenu ---
                    clear; print_header "Security & Certificates";
                    echo -e "|   ${BOLD}1)${NC} Manage Dashboard Users             |";
                    echo -e "|   ${BOLD}2)${NC} Show Certificate Details (ACME)    |";
                    echo -e "|   ${BOLD}3)${NC} Check Cert Expiry (< 14 Days)    |";
                    echo -e "|   ${BOLD}4)${NC} Check for Insecure API             |";
                    echo -e "|   ${BOLD}5)${NC} Show Example Fail2Ban Config       |";
                    echo "|-----------------------------------------|";
                    echo -e "|   ${BOLD}0)${NC} Back                               |";
                    echo "+-----------------------------------------+";
                    read -p "Choice [0-5]: " sub_choice
                    case "$sub_choice" in 1) manage_dashboard_users ;; 2) show_certificate_info ;; 3) check_certificate_expiry ;; 4) check_insecure_api ;; 5) generate_fail2ban_config ;; 0) ;; *) echo -e "${RED}Invalid choice.${NC}" >&2 ;; esac ;;
                4) # --- Service & Logs Submenu ---
                    clear; print_header "Service & Logs";
                    echo -e "|   ${BOLD}1)${NC} START Traefik Service              |";
                    echo -e "|   ${BOLD}2)${NC} STOP Traefik Service               |";
                    echo -e "|   ${BOLD}3)${NC} RESTART Traefik Service            |";
                    echo -e "|   ${BOLD}4)${NC} Show Traefik Service STATUS        |";
                    echo "|-----------------------------------------|";
                    echo -e "|   ${BOLD}5)${NC} View Traefik Log (traefik.log)     |";
                    echo -e "|   ${BOLD}6)${NC} View Access Log (access.log)       |";
                    echo -e "|   ${BOLD}7)${NC} View Systemd Journal Log (traefik) |";
                    echo -e "|   ${BOLD}8)${NC} View IP Access Log (...)           |";
                    echo -e "|   ${BOLD}9)${NC} View Autobackup Log (File)         |";
                    echo -e "|  ${BOLD}10)${NC} View Autobackup Log (Journal)      |";
                    echo -e "|  ${BOLD}11)${NC} View IP Logger Service Log (Jrnl)  |";
                    echo "|-----------------------------------------|";
                    echo -e "|   ${BOLD}0)${NC} Back                               |";
                    echo "+-----------------------------------------+";
                    read -p "Choice [0-11]: " sub_choice
                    case "$sub_choice" in
                         1) manage_service "start" ;; 2) manage_service "stop" ;; 3) manage_service "restart" ;; 4) manage_service "status" ;;
                         5) view_logs "traefik" ;; 6) view_logs "access" ;; 7) view_logs "journal" ;; 8) view_logs "ip_access" ;;
                         9) view_logs "autobackup_file" ;; 10) view_logs "autobackup" ;; 11) view_logs "ip_logger" ;;
                         0) ;; *) echo -e "${RED}Invalid choice.${NC}" >&2 ;; esac ;;
                5) # --- Backup & Restore Submenu ---
                     clear; print_header "Backup & Restore";
                     echo -e "|   ${BOLD}1)${NC} Create Configuration Backup        |";
                     echo -e "|   ${BOLD}2)${NC} Restore Backup ${YELLOW}(CAUTION!)${NC}       |";
                     echo "|-----------------------------------------|";
                     echo -e "|   ${BOLD}0)${NC} Back                               |";
                     echo "+-----------------------------------------+";
                     read -p "Choice [0-2]: " sub_choice
                     case "$sub_choice" in 1) backup_traefik false ;; 2) restore_traefik ;; 0) ;; *) echo -e "${RED}Invalid choice.${NC}" >&2 ;; esac ;;
                6) # --- Diagnostics & Info Submenu ---
                    clear; print_header "Diagnostics & Info";
                    echo -e "|   ${BOLD}1)${NC} Show Installed Traefik Version     |";
                    echo -e "|   ${BOLD}2)${NC} Check Listening Ports (ss)         |";
                    echo -e "|   ${BOLD}3)${NC} Test Backend Connectivity          |";
                    echo -e "|   ${BOLD}4)${NC} Show Active Config (API/jq)        |";
                    echo -e "|   ${BOLD}5)${NC} Perform Health Check               |";
                    echo -e "|   ${BOLD}6)${NC} Check Static Config Syntax (Hint)  |";
                    echo "|-----------------------------------------|";
                    echo -e "|   ${BOLD}0)${NC} Back                               |";
                    echo "+-----------------------------------------+";
                    read -p "Choice [0-6]: " sub_choice
                    case "$sub_choice" in 1) show_traefik_version ;; 2) check_listening_ports ;; 3) test_backend_connectivity ;; 4) show_active_config ;; 5) health_check ;; 6) check_static_config ;; 0) ;; *) echo -e "${RED}Invalid choice.${NC}" >&2 ;; esac ;;
                7) # --- Automation Submenu ---
                    clear; print_header "Automation";
                    echo -e "|   ${BOLD}1)${NC} Setup/Modify Auto Backup           |";
                    echo -e "|   ${BOLD}2)${NC} Remove Automatic Backup            |";
                    echo -e "|   ${BOLD}3)${NC} Setup Dedicated IP Logging         |";
                    echo -e "|   ${BOLD}4)${NC} Remove Dedicated IP Log          |";
                    echo "|-----------------------------------------|";
                    echo -e "|   ${BOLD}0)${NC} Back                               |";
                    echo "+-----------------------------------------+";
                    read -p "Choice [0-4]: " sub_choice
                    case "$sub_choice" in
                        1) setup_autobackup ;; 2) remove_autobackup ;; 3) setup_ip_logging ;; 4) remove_ip_logging ;;
                        0) ;; *) echo -e "${RED}Invalid choice.${NC}" >&2 ;; esac ;;
                8) # --- Maintenance & Updates Submenu ---
                     clear; print_header "Maintenance & Updates";
                     echo -e "|   ${BOLD}1)${NC} Check for New Traefik Version      |";
                     echo -e "|   ${BOLD}2)${NC} Update Traefik Binary ${YELLOW}(RISK!)${NC}   |";
                     echo "|-----------------------------------------|";
                     echo -e "|   ${BOLD}0)${NC} Back                               |";
                     echo "+-----------------------------------------+";
                     read -p "Choice [0-2]: " sub_choice
                     case "$sub_choice" in
                        1) check_traefik_updates ;; 2) update_traefik_binary ;;
                        0) ;; *) echo -e "${RED}Invalid choice.${NC}" >&2 ;; esac ;;
                9) # --- Uninstall ---
                     uninstall_traefik ;;
                0) # --- Exit Script ---
                    echo "Exiting script. Goodbye!"; exit 0 ;;
                *) # --- Invalid Main Menu Choice ---
                    echo ""; echo -e "${RED}ERROR: Invalid choice '$main_choice'.${NC}" >&2 ;;
            esac

            if [[ "$main_choice" != "0" ]]; then
                if [[ "$sub_choice" -ne 0 ]] && [[ "$main_choice" -ne 9 ]]; then
                     echo ""; read -p "... Press Enter for main menu ..." dummy_var;
                fi
            fi
        done
    fi
}

# Skriptausführung starten
main "$@"
