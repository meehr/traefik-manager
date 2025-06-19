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
    # Der Pfad zum Skript, aus dem gelesen wird (das CLI-Skript selbst).
    # Die Variable SCRIPT_DIR wird im Hauptskript `traefik-manager.sh` definiert
    # und ist hier verfügbar, da diese Datei von dort gesourcet wird.
    local main_script_path="${SCRIPT_DIR}/traefik-manager.sh"

    # Extrahieren der Informationen mit `grep` und `sed` für Robustheit.
    # `sed 's/^[^:]*: //'` entfernt alles bis zum ersten Doppelpunkt und dem darauf folgenden Leerzeichen.
    local version=$(grep "^# Version:" "$main_script_path" | sed 's/^[^:]*: //')
    local author=$(grep "^# Author:" "$main_script_path" | sed 's/^[^:]*: //')
    local based_on=$(grep "^# Based on:" "$main_script_path" | sed 's/^[^:]*: //')

    # Fallback-Werte, falls grep nichts findet oder die Datei nicht existiert.
    version=${version:-"N/A"}
    author=${author:-"N/A"}
    based_on=${based_on:-"N/A"}

    # Header-Ausgabe
    clear; echo ""
    echo -e "${BLUE}+-----------------------------------------+${NC}"
    # Titel des aktuellen Menüs, zentriert und fett.
    printf "${BLUE}| %-38s|${NC}\n" "${BOLD}${title}${NC}"
    echo -e "${BLUE}+-----------------------------------------+${NC}"
    # Dynamisch generierte Informationen, formatiert für die Box.
    printf "${BLUE}| Version: %-29s |${NC}\n" "$version"
    printf "${BLUE}| Author: %-30s |${NC}\n" "$author"
    # Kürzen, falls die "Based on"-Zeile zu lang ist, damit der Rahmen nicht bricht.
    printf "${BLUE}| Based on: %-28.28s |${NC}\n" "$based_on"
    echo -e "${BLUE}+-----------------------------------------+${NC}"
    # Status-Informationen
    echo -e "| Current Time: $(date '+%Y-%m-%d %H:%M:%S %Z')    |"
    printf "| Traefik Status: %-23s |\n" "${BOLD}$(is_traefik_active && echo "${GREEN}ACTIVE  ${NC}" || echo "${RED}INACTIVE${NC}")${NC}"
    echo "+-----------------------------------------+";
}
