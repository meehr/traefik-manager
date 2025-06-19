#!/bin/bash
# ===============================================================================
# Traefik Management Script - Security Module
# ===============================================================================

#===============================================================================
# Funktion: Dashboard-Benutzer verwalten
#===============================================================================
manage_dashboard_users() {
    if ! ensure_dependency_installed "htpasswd" "apache2-utils"; then return 1; fi
    while true; do
        print_header "Manage Dashboard Users";
        # ... (Menülogik für Benutzer hinzufügen, ändern, löschen)
        echo "1) Add User, 2) Remove User, 3) Change Password, 4) List Users, 0) Back"
        read -p "Choice: " user_choice
        case "$user_choice" in
            # Implementierung der htpasswd-Befehle hier
            0) break ;;
            *) echo "Invalid option" ;;
        esac
        read -p "Press Enter to continue..."
    done
    return 0
}

#===============================================================================
# Funktion: Beispiel für Fail2Ban-Konfiguration anzeigen
#===============================================================================
generate_fail2ban_config() {
    echo ""; echo -e "${MAGENTA}==================================================${NC}"; echo -e "${BOLD} Example Fail2Ban Configuration for Traefik Auth${NC}"; echo -e "${MAGENTA}==================================================${NC}";
    echo -e "${BOLD}1. Filter (/etc/fail2ban/filter.d/traefik-auth.conf):${NC}";
    cat << EOF
[Definition]
failregex = ^{.*"ClientHost":"<HOST>".*"RouterName":"traefik-dashboard-secure@file".*"StatusCode":401.*$
EOF
    echo ""; echo -e "${BOLD}2. Jail (in /etc/fail2ban/jail.local):${NC}";
    cat << EOF
[traefik-auth]
enabled   = true
port      = http,https
filter    = traefik-auth
logpath   = ${TRAEFIK_LOG_DIR}/access.log
maxretry  = 5
bantime   = 3600
EOF
    echo "=================================================="; return 0
}

#===============================================================================
# Funktion: Zertifikatdetails anzeigen
#===============================================================================
show_certificate_info() {
    if ! ensure_dependency_installed "jq" "jq" || ! ensure_dependency_installed "openssl" "openssl"; then return 1; fi
    if [[ ! -f "$ACME_TLS_FILE" ]]; then echo -e "${RED}ERROR: ACME file (${ACME_TLS_FILE}) not found.${NC}" >&2; return 1; fi

    echo -e "${BLUE}Reading certificates from ${ACME_TLS_FILE}...${NC}";
    # Vereinfachte Logik zur Anzeige der Domains
    sudo jq -r '.[].Certificates[].domain.main' "${ACME_TLS_FILE}"
    # Eine detailliertere Analyse würde das Zertifikat decodieren und mit openssl parsen.
    return 0
}

#===============================================================================
# Funktion: Auf unsichere API-Konfiguration prüfen
#===============================================================================
check_insecure_api() {
     if [[ ! -f "$STATIC_CONFIG_FILE" ]]; then echo -e "${RED}ERROR: Static config not found.${NC}" >&2; return 1; fi
     if sudo grep -q "insecure: true" "${STATIC_CONFIG_FILE}"; then
         echo -e "${RED}WARNING: Insecure API is enabled in ${STATIC_CONFIG_FILE}!${NC}" >&2
         return 1
     else
         echo -e "${GREEN}INFO: API seems securely configured (insecure: false or not set).${NC}"
     fi
     return 0
}
