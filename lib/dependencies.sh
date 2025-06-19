#!/bin/bash
# ===============================================================================
# Traefik Management Script - Dependency Management Library
# ===============================================================================

# Stellt sicher, dass ein einzelnes, benötigtes Tool installiert ist.
ensure_dependency_installed() {
    local cmd="$1"
    local pkg="$2"
    if command -v "$cmd" &> /dev/null; then
        return 0 # Tool ist bereits vorhanden
    fi

    echo -e "${YELLOW}HINWEIS: Das Kommando '${BOLD}${cmd}${NC}${YELLOW}' wird für diese Funktion benötigt, ist aber nicht installiert.${NC}"
    local install_confirmed=false
    ask_confirmation "Das fehlende Paket '${pkg}' jetzt installieren (via sudo apt install)? " install_confirmed
    if $install_confirmed; then
        echo -e "${BLUE}Installiere Paket: ${pkg}...${NC}"
        if ! sudo apt-get update || ! sudo apt-get install -y "$pkg"; then
            echo -e "${RED}FEHLER: Das Paket '${pkg}' konnte nicht installiert werden. Bitte manuell prüfen.${NC}" >&2
            return 1
        else
            echo -e "${GREEN}Paket '${pkg}' wurde erfolgreich installiert.${NC}"
            return 0
        fi
    else
        echo -e "${RED}FEHLER: Das benötigte Kommando '${cmd}' ist nicht installiert. Funktion wird abgebrochen.${NC}" >&2
        return 1
    fi
}

# Prüft beim Start des Skripts eine Liste von Abhängigkeiten.
check_dependencies() {
    local missing_pkgs=(); local pkgs_to_install=()
    local dependencies=( "jq:jq" "curl:curl" "htpasswd:apache2-utils" "nc:netcat-openbsd" "openssl:openssl" "stat:coreutils" "sed:sed" "grep:grep" "awk:gawk" "tar:tar" "find:findutils" "ss:iproute2" "yamllint:yamllint")
    echo -e "${BLUE}Checking required additional tools...${NC}"
    local jq_needed=false

    # Prüfen, ob die IP-Logger-Service-Unit existiert
    if systemctl list-unit-files --no-pager 2>/dev/null | grep -q "^${IPLOGGER_SERVICE}"; then jq_needed=true; fi

    for item in "${dependencies[@]}"; do local cmd="${item%%:*}"; local pkg="${item##*:}";
        if ! command -v "$cmd" &> /dev/null; then
           local is_needed=true
           if [[ "$cmd" == "yamllint" ]]; then
               is_needed=false # Nur optional
           elif [[ "$cmd" == "jq" ]] && ! $jq_needed; then
               is_needed=false # Nur benötigt, wenn IP-Logger aktiv ist
           fi

            if $is_needed && [[ ! " ${pkgs_to_install[@]} " =~ " ${pkg} " ]]; then
                 pkgs_to_install+=("$pkg");
                 missing_pkgs+=("$cmd ($pkg)");
            fi
        fi
    done

    if [ ${#missing_pkgs[@]} -gt 0 ]; then
        echo -e "${YELLOW}WARNUNG: Die folgenden Befehle/Pakete fehlen für einige Kernfunktionen:${NC}"; printf "  - %s\n" "${missing_pkgs[@]}"; local install_confirmed=false; ask_confirmation "${YELLOW}Die fehlenden Pakete (${pkgs_to_install[*]}) jetzt installieren (sudo apt install...)?${NC} " install_confirmed
        if $install_confirmed; then local install_list=$(echo "${pkgs_to_install[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '); echo -e "${BLUE}Installiere: ${install_list}...${NC}"; if ! sudo apt-get update || ! sudo apt-get install -y $install_list; then echo -e "${RED}FEHLER: Pakete konnten nicht installiert werden.${NC}" >&2; else echo -e "${GREEN}Zusätzliche Pakete installiert.${NC}"; fi; else echo -e "${YELLOW}INFO: Fehlende Pakete nicht installiert.${NC}"; fi; echo "--------------------------------------------------"; sleep 1
    else echo -e "${GREEN}Alle erforderlichen zusätzlichen Kernwerkzeuge sind vorhanden.${NC}"; fi

    if ! command -v yamllint &> /dev/null; then
         echo -e "${YELLOW}INFO: Optionales Werkzeug 'yamllint' nicht gefunden (nützlich für Menü 6->6). Installieren: sudo apt install yamllint${NC}"
    fi
    if $jq_needed && ! command -v jq &> /dev/null; then
        echo -e "${RED}FEHLER: 'jq' wird für den IP-Logger benötigt (Dienst existiert), ist aber nicht installiert!${NC}" >&2
        echo -e "${RED}        Bitte installieren: sudo apt install jq ${NC}" >&2
    fi
}
