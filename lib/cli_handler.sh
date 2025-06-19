#!/bin/bash
# ===============================================================================
# Traefik Management Script - Command Line Interface (CLI) Handler
# ===============================================================================

# --- Hilfefunktion für Befehlsaufrufe ---
show_cli_help() {
    echo "Traefik Manager - Unified Controller"
    echo "----------------------------------------"
    echo "Usage: $0 [command|--gui]"
    echo ""
    echo "Execution Modes:"
    echo "  (no argument)         - Start the interactive menu in the console."
    echo "  --gui                 - Start the graphical user interface (GUI)."
    echo ""
    echo "Available commands:"
    echo "  install               - Start the interactive installation."
    echo "  add                   - Start the interactive process to add a new service/route."
    echo "  remove                - Start the interactive process to remove a service/route."
    echo "  start|stop|restart    - Manage the Traefik service."
    echo "  status                - Show the status of the Traefik service."
    echo "  backup                - Create a new configuration backup (non-interactive)."
    echo "  restore               - Start the interactive process to restore a backup."
    echo "  logs [type]           - View logs. Type can be: traefik, access, journal,"
    echo "                          ip, autobackup, iplogger"
    echo "  check-update          - Check for new Traefik versions."
    echo "  update                - Start the interactive process to update the Traefik binary."
    echo "  health-check          - Perform a full health check."
    echo "  uninstall             - Start the interactive process to uninstall Traefik."
    echo "  help                  - Show this help message."
}

# --- Hauptfunktion zur Verarbeitung der CLI-Argumente ---
# Diese Funktion wird vom Hauptskript aufgerufen.
handle_cli_args() {
    # Wenn keine Argumente übergeben wurden, beende die Funktion einfach.
    # Das Hauptskript fährt dann mit dem interaktiven Menü fort.
    if [ "$#" -eq 0 ]; then
        return 1 # Gibt 1 zurück, um dem Hauptskript zu signalisieren, fortzufahren
    fi

    # Das erste Argument ist der Befehl.
    local cmd="$1"
    # Das zweite Argument wird als Option für Befehle wie 'logs' verwendet.
    local opt="$2"

    case "$cmd" in
        # Der --gui-Fall wird im Hauptskript behandelt, bevor diese Funktion aufgerufen wird.
        install) install_traefik ;;
        add) add_service ;;
        remove) remove_service ;;
        start) manage_service "start" ;;
        stop) manage_service "stop" ;;
        restart) manage_service "restart" ;;
        status) manage_service "status" ;;
        backup|--run-backup) backup_traefik true ;; # Non-interactive
        restore) restore_traefik ;;
        check-update) check_traefik_updates ;;
        update) update_traefik_binary ;;
        uninstall) uninstall_traefik ;;
        health-check) health_check ;;
        
        logs)
            if [ -z "$opt" ]; then
                echo -e "${RED}Error: 'logs' command requires a type.${NC}" >&2
                echo "Usage: $0 logs [traefik|access|journal|ip|autobackup|iplogger]" >&2
                exit 1
            fi
            # 'view_logs' direkt mit dem zweiten Argument aufrufen
            # Die Live-Anzeige wird direkt im Terminal gestartet.
            view_logs "$opt"
            ;;

        help|--help|-h)
            show_cli_help
            ;;
        *)
            echo -e "${RED}Error: Unknown command '$cmd'${NC}" >&2
            show_cli_help
            exit 1
            ;;
    esac

    # Wenn ein Befehl erfolgreich verarbeitet wurde, beende das gesamte Skript.
    exit 0
}
