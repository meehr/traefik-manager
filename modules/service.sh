#!/bin/bash
# ===============================================================================
# Traefik Management Script - Service and Log Module
# ===============================================================================

#===============================================================================
# Funktion: Traefik-Dienst verwalten
#===============================================================================
manage_service() {
    local action=$1; echo ""; echo -e "${MAGENTA}==================================================${NC}"; echo -e "${BOLD} Traefik Service: Action '${action}'...${NC}"; echo -e "${MAGENTA}==================================================${NC}"
    if ! is_traefik_installed; then echo -e "${RED}ERROR: Traefik not installed.${NC}" >&2; return 1; fi;
    case "$action" in
        start|stop|restart|status)
            if sudo systemctl "$action" "${TRAEFIK_SERVICE_NAME}"; then
                echo -e "${GREEN}Action '${action}' successful.${NC}"
                if [[ "$action" != "status" ]]; then sleep 2; fi
                sudo systemctl status "${TRAEFIK_SERVICE_NAME}" --no-pager -l
            else
                echo -e "${RED}ERROR: Action '${action}' failed!${NC}" >&2; return 1;
            fi
            ;;
        *) echo -e "${RED}ERROR: Action '$action' unknown.${NC}" >&2; return 1 ;;
    esac; echo "=================================================="; return 0
}

#===============================================================================
# Funktion: Logs anzeigen
#===============================================================================
view_logs() {
    local log_type=$1; echo ""; echo -e "${MAGENTA}==================================================${NC}"; echo -e "${BOLD} Show Logs: ${log_type}${NC}"; echo -e "${MAGENTA}==================================================${NC}"; echo -e "${CYAN}INFO: Press Ctrl+C to exit.${NC}"; sleep 1
    local f=""
    case "$log_type" in
       traefik) f="${TRAEFIK_LOG_DIR}/traefik.log" ;;
       access) f="${TRAEFIK_LOG_DIR}/access.log" ;;
       ip_access) f="${IP_LOG_FILE}" ;;
       autobackup_file) f="${AUTOBACKUP_LOG}" ;;
       journal) sudo journalctl -u "${TRAEFIK_SERVICE_NAME}" -n 100 -f; return 0 ;;
       autobackup) sudo journalctl -u "${AUTOBACKUP_SERVICE}" -n 100 -f; return 0 ;;
       ip_logger) sudo journalctl -u "${IPLOGGER_SERVICE}" -n 100 -f; return 0 ;;
       *) echo -e "${RED}ERROR: Log type '$log_type' unknown.${NC}" >&2; return 1 ;;
    esac;

    if [[ -f "$f" ]]; then
        sudo tail -n 100 -f "$f";
    else
        echo -e "${RED}ERROR: Log (${f}) not found.${NC}" >&2; return 1;
    fi
    return 0
}
