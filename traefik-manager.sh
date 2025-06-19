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
if [ ! -f "${SCRIPT_DIR}/conf/traefik-manager.conf" ]; then
    echo "FEHLER: Konfigurationsdatei nicht gefunden: ${SCRIPT_DIR}/conf/traefik-manager.conf" >&2
    exit 1
fi
source "${SCRIPT_DIR}/conf/traefik-manager.conf"
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
fi

# --- Hauptlogik ---
main() {
    if $non_interactive_mode && [[ "$1" == "--run-backup" ]]; then
        if declare -F backup_traefik > /dev/null; then
            echo "[$(date +'%Y-%m-%d %H:%M:%S')] Running non-interactive backup via ${SCRIPT_PATH}..."
            backup_traefik true
            local exit_code=$?
            echo "[$(date +'%Y-%m-%d %H:%M:%S')] Non-interactive backup finished with exit code ${exit_code}."
            exit $exit_code
        else
            echo "[$(date +'%Y-%m-%d %H:%M:%S')] CRITICAL ERROR: backup_traefik function not defined." >&2
            exit 1
        fi
    fi

    if ! $non_interactive_mode; then
        check_root
        check_dependencies

        while true; do
            print_header "Main Menu - Traefik Management"

            # Angepasste Menüanzeige ohne Rahmen
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

            local sub_choice=-1

            case "$main_choice" in
                1)
                    clear
                    print_header "Installation & Initial Setup"
                    echo -e "${BOLD}1)${NC} Install / Overwrite Traefik"
                    echo -e "${BOLD}0)${NC} Back"
                    read -p "Choice [0-1]: " sub_choice
                    case "$sub_choice" in 1) install_traefik ;; 0) ;; *) echo -e "${RED}Invalid choice.${NC}" >&2 ;; esac ;;
                2)
                    clear
                    print_header "Configuration & Routes"
                    echo -e "${BOLD}1)${NC} Add New Service / Route"
                    echo -e "${BOLD}2)${NC} Modify Service / Route"
                    echo -e "${BOLD}3)${NC} Remove Service / Route"
                    echo "---"
                    echo -e "${BOLD}4)${NC} Edit Static Config (...)"
                    echo -e "${BOLD}5)${NC} Edit Middleware Config (...)"
                    echo -e "${BOLD}6)${NC} Add Plugin (Experimental)"
                    echo -e "${BOLD}0)${NC} Back"
                    read -p "Choice [0-6]: " sub_choice
                    case "$sub_choice" in 1) add_service ;; 2) modify_service ;; 3) remove_service ;; 4) edit_static_config ;; 5) edit_middlewares_config ;; 6) install_plugin ;; 0) ;; *) echo -e "${RED}Invalid choice.${NC}" >&2 ;; esac ;;
                # ... die restlichen case-Blöcke würden einem ähnlichen, rahmenlosen Muster folgen ...
                9)
                     uninstall_traefik ;;
                0)
                    echo "Exiting script. Goodbye!"; exit 0 ;;
                *)
                    echo ""; echo -e "${RED}ERROR: Invalid choice '$main_choice'.${NC}" >&2 ;;
            esac

            if [[ "$main_choice" != "0" ]]; then
                if [[ "$sub_choice" -ne 0 ]]; then
                     echo ""; read -p "... Press Enter for main menu ..." dummy_var;
                fi
            fi
        done
    fi
}

# Skriptausführung starten
main "$@"
