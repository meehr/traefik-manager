#!/bin/bash
# ===============================================================================
# Traefik Management Script - Helper Functions Library
# ===============================================================================

# --- Farben für die Ausgabe (optional) ---
if [ -t 1 ] && command -v tput &> /dev/null; then
    ncolors=$(tput colors)
    if [ -n "$ncolors" ] && [ "$ncolors" -ge 8 ]; then
        RED=$(tput setaf 1)
        GREEN=$(tput setaf 2)
        YELLOW=$(tput setaf 3)
        BLUE=$(tput setaf 4)
        MAGENTA=$(tput setaf 5)
        CYAN=$(tput setaf 6)
        WHITE=$(tput setaf 7)
        BOLD=$(tput bold)
        NC=$(tput sgr0)
    else
        RED=""
        GREEN=""
        YELLOW=""
        BLUE=""
        MAGENTA=""
        CYAN=""
        WHITE=""
        BOLD=""
        NC=""
    fi
else
    RED=""
    GREEN=""
    YELLOW=""
    BLUE=""
    MAGENTA=""
    CYAN=""
    WHITE=""
    BOLD=""
    NC=""
fi

# --- Hilfsfunktionen ---
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}FEHLER: Root-Rechte (sudo) erforderlich!${NC}" >&2
        exit 1
    fi
}

ask_confirmation() {
    local prompt="$1"
    # Nameref (-n) für sichere Variablenausgabe ohne 'eval' verwenden.
    local -n result_var="$2"
    local reply
    while true; do
        read -p "${CYAN}${prompt}${NC} Geben Sie '${BOLD}yes${NC}' oder '${BOLD}no${NC}' ein: " reply
        reply=$(echo "$reply" | tr '[:upper:]' '[:lower:]')
        if [[ "$reply" == "yes" ]]; then
            result_var=true
            return 0
        elif [[ "$reply" == "no" ]]; then
            result_var=false
            return 0
        else
            echo -e "${YELLOW}Unklare Antwort.${NC}"
        fi
    done
}

is_traefik_installed() {
    if [[ -f "$TRAEFIK_BINARY_PATH" && -d "$TRAEFIK_CONFIG_DIR" && -f "$STATIC_CONFIG_FILE" ]]; then
        return 0
    else
        return 1
    fi
}

is_traefik_active() {
    systemctl is-active --quiet "${TRAEFIK_SERVICE_NAME}"
    return $?
}

# Funktion für den Menükopf
print_header() {
    local title=$1
    local version="3.0 (Modular)"
    clear; echo ""; echo -e "${BLUE}+-----------------------------------------+${NC}"; echo -e "${BLUE}|${NC} ${BOLD}${title}${NC} ${BLUE}|${NC}"; echo -e "${BLUE}|${NC} Version: ${version}    Author: fbnlrz    ${BLUE}|${NC}"; echo -e "${BLUE}|${NC} Based on guide by: phoenyx          ${BLUE}|${NC}"; echo -e "${BLUE}+-----------------------------------------+${NC}"; echo -e "| Current Time: $(date '+%Y-%m-%d %H:%M:%S %Z')    |"; printf "| Traefik Status: %-23s |\n" "${BOLD}$(is_traefik_active && echo "${GREEN}ACTIVE  ${NC}" || echo "${RED}INACTIVE${NC}")${NC}"; echo "+-----------------------------------------+";
}
