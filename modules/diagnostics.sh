#!/bin/bash
# ===============================================================================
# Traefik Management Script - Diagnostics Module
# ===============================================================================

#===============================================================================
# Funktion: Installierte Traefik-Version prüfen
#===============================================================================
show_traefik_version() {
    if [[ -f "$TRAEFIK_BINARY_PATH" ]]; then
        sudo "${TRAEFIK_BINARY_PATH}" version
    else
        echo -e "${RED}ERROR: Traefik binary not found.${NC}" >&2;
    fi;
    return 0
}

#===============================================================================
# Funktion: Statische Konfiguration prüfen (Hinweis für v3)
#===============================================================================
check_static_config() {
    echo -e "${BLUE}INFO for Traefik v3:${NC}"
    echo " Validation happens when Traefik is started."
    echo -e "${YELLOW}Recommendation: Restart Traefik and check logs for errors.${NC}"
    if command -v yamllint &> /dev/null; then
        echo -e "${BLUE}Checking basic YAML syntax with 'yamllint'...${NC}"
        yamllint "${STATIC_CONFIG_FILE}"
    else
         echo -e "${YELLOW}HINT: 'yamllint' not found (sudo apt install yamllint).${NC}"
    fi
    return 0
}

#===============================================================================
# Funktion: Backend-Konnektivität testen
#===============================================================================
test_backend_connectivity() {
    if ! ensure_dependency_installed "curl" "curl"; then return 1; fi
    read -p "Internal URL of the backend (e.g., http://192.168.1.50:8080): " url;
    curl -vL --connect-timeout 5 "${url}"
    return $?
}

#===============================================================================
# Funktion: Lausch-Ports für Traefik prüfen
#===============================================================================
check_listening_ports() {
    if ! ensure_dependency_installed "ss" "iproute2"; then return 1; fi
    echo "Checking for processes listening on port 80 and 443..."
    sudo ss -tlpn '( sport = :80 or sport = :443 )'
    return 0
}

#===============================================================================
# Funktion: Aktive Konfiguration anzeigen (via Traefik API)
#===============================================================================
show_active_config() {
    if ! ensure_dependency_installed "curl" "curl" || ! ensure_dependency_installed "jq" "jq"; then return 1; fi
    echo "Attempting to query local Traefik API (http://127.0.0.1:8080/api)..."
    if curl -s "http://127.0.0.1:8080/api/rawdata" | jq '.'; then
        return 0
    else
        echo -e "${RED}Failed. Is API enabled and insecure, or do you need an authenticated router?${NC}" >&2
        return 1
    fi
}

#===============================================================================
# Funktion: Traefik Health Check
#===============================================================================
health_check() {
    local all_ok=true
    echo "--- [1/3] Service Status ---"
    if ! is_traefik_active; then echo -e "${RED}ERROR: Service is INACTIVE!${NC}" >&2; all_ok=false; fi
    echo "--- [2/3] Listening Ports ---"
    if ! sudo ss -tlpn | grep -q 'traefik'; then echo -e "${RED}ERROR: Traefik process not found listening on any port.${NC}" >&2; all_ok=false; fi
    echo "--- [3/3] Insecure API Check ---"
    if check_insecure_api; then echo "OK"; else all_ok=false; fi
    
    if $all_ok; then echo -e "${GREEN}HEALTH CHECK PASSED.${NC}"; else echo -e "${RED}HEALTH CHECK FAILED.${NC}" >&2; fi
    return 0
}

#===============================================================================
# Funktion: Zertifikatsablauf prüfen
#===============================================================================
check_certificate_expiry() {
    # Diese Funktion erfordert eine komplexere Logik zum Parsen des acme.json
    # und Überprüfen jedes Zertifikats mit openssl.
    echo "Checking certificate expiry..."
    show_certificate_info # Einfache Version für den Anfang
    return 0
}
