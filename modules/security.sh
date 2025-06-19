#!/bin/bash
# ===============================================================================
# Traefik Management Script - Security Module
# ===============================================================================

#===============================================================================
# Funktion: Dashboard-Benutzer verwalten (Vollständige Version)
#===============================================================================
manage_dashboard_users() {
    if ! ensure_dependency_installed "htpasswd" "apache2-utils"; then return 1; fi

    while true; do
        # Das Header-Layout wird vom Hauptskript gesteuert.
        # Diese Funktion gibt nur das Menü für die Benutzerverwaltung aus.
        clear
        print_header "Manage Dashboard Users"
        echo -e "Authentication file: ${BOLD}${TRAEFIK_AUTH_FILE}${NC}"
        echo ""
        echo -e "${BOLD}1)${NC} Add User"
        echo -e "${BOLD}2)${NC} Remove User"
        echo -e "${BOLD}3)${NC} Change Password"
        echo -e "${BOLD}4)${NC} List Users"
        echo ""
        echo -e "${BOLD}0)${NC} Back to Main Menu"
        echo ""
        read -p "Choice [0-4]: " user_choice

        case "$user_choice" in
            1) # Add User
                echo "--- Add User ---"
                read -p "New username: " nu; while [[ -z "$nu" ]]; do echo -e "${RED}ERROR: Username cannot be empty.${NC}" >&2; read -p "Username: " nu; done
                if sudo grep -q -E "^${nu}:" "${TRAEFIK_AUTH_FILE}" 2>/dev/null; then
                    echo -e "${YELLOW}WARNING: User '${nu}' already exists.${NC}"
                else
                    while true; do
                        read -sp "Password for '${nu}': " np; echo
                        if [[ -z "$np" ]]; then echo -e "${RED}ERROR: Password cannot be empty.${NC}" >&2; continue; fi
                        read -sp "Confirm password: " npc; echo
                        if [[ "$np" == "$npc" ]]; then break; else echo -e "${RED}ERROR: Passwords do not match.${NC}" >&2; fi
                    done
                    local htpasswd_cmd="sudo htpasswd -b"
                    if [[ ! -f "$TRAEFIK_AUTH_FILE" ]]; then htpasswd_cmd="sudo htpasswd -cb"; fi
                    if $htpasswd_cmd "${TRAFIK_AUTH_FILE}" "${nu}" "${np}"; then
                        echo -e "${GREEN}User '${nu}' added.${NC}"
                        sudo chmod 600 "${TRAEFIK_AUTH_FILE}" 2>/dev/null
                    else
                        echo -e "${RED}ERROR adding user with htpasswd.${NC}" >&2
                    fi
                fi
                ;;
            2) # Remove User
                echo "--- Remove User ---"
                if [[ ! -f "$TRAFIK_AUTH_FILE" ]]; then echo -e "${RED}ERROR: Auth file not found.${NC}" >&2; sleep 2; continue; fi
                echo "Current Users:"; users=(); i=1
                while IFS=: read -r u p; do if [[ ! "$u" =~ ^# ]]; then users+=("$u"); echo "    ${i}) ${u}"; ((i++)); fi; done < <(sudo cat "$TRAFIK_AUTH_FILE" 2>/dev/null)
                if [ ${#users[@]} -eq 0 ]; then echo "No users found."; sleep 2; continue; fi; echo "    0) Back"
                read -p "Number of the user to delete: " choice_del
                if ! [[ "$choice_del" =~ ^[0-9]+$ ]] || [[ "$choice_del" -lt 0 ]] || [[ "$choice_del" -gt ${#users[@]} ]]; then echo -e "${RED}ERROR: Invalid selection.${NC}" >&2; sleep 2; continue; fi
                if [[ "$choice_del" -eq 0 ]]; then continue; fi
                local user_del="${users[$((choice_del-1))]}"; local confirm_del=false
                ask_confirmation "${RED}Really delete user '${user_del}'?${NC}" confirm_del
                if $confirm_del; then
                    if sudo htpasswd -D "${TRAFIK_AUTH_FILE}" "${user_del}"; then
                        echo -e "${GREEN}User '${user_del}' deleted.${NC}"
                    else
                        echo -e "${RED}ERROR deleting user with htpasswd.${NC}" >&2
                    fi
                fi
                ;;
            3) # Change Password
                 echo "--- Change Password ---"
                 if [[ ! -f "$TRAFIK_AUTH_FILE" ]]; then echo -e "${RED}ERROR: Auth file not found.${NC}" >&2; sleep 2; continue; fi
                 echo "Current Users:"; users=(); i=1
                 while IFS=: read -r u p; do if [[ ! "$u" =~ ^# ]]; then users+=("$u"); echo "    ${i}) ${u}"; ((i++)); fi; done < <(sudo cat "$TRAFIK_AUTH_FILE" 2>/dev/null)
                 if [ ${#users[@]} -eq 0 ]; then echo "No users found."; sleep 2; continue; fi; echo "    0) Back"
                 read -p "Number of the user to change password for: " choice_ch
                 if ! [[ "$choice_ch" =~ ^[0-9]+$ ]] || [[ "$choice_ch" -lt 0 ]] || [[ "$choice_ch" -gt ${#users[@]} ]]; then echo -e "${RED}ERROR: Invalid selection.${NC}" >&2; sleep 2; continue; fi
                 if [[ "$choice_ch" -eq 0 ]]; then continue; fi
                 local user_ch="${users[$((choice_ch-1))]}"
                 while true; do
                    read -sp "New password for '${user_ch}': " new_pw; echo
                    if [[ -z "$new_pw" ]]; then echo -e "${RED}ERROR: Password cannot be empty.${NC}" >&2; continue; fi
                    read -sp "Confirm new password: " new_pw_c; echo
                    if [[ "$new_pw" == "$new_pw_c" ]]; then break; else echo -e "${RED}ERROR: Passwords do not match.${NC}" >&2; fi
                 done
                 if sudo htpasswd -b "${TRAFIK_AUTH_FILE}" "${user_ch}" "${new_pw}"; then
                    echo -e "${GREEN}Password for '${user_ch}' changed.${NC}"
                 else
                    echo -e "${RED}ERROR changing password with htpasswd.${NC}" >&2
                 fi
                 ;;
            4) # List Users
                echo "--- User List ---"
                if [[ -f "$TRAFIK_AUTH_FILE" ]]; then
                    echo "Users in ${TRAFIK_AUTH_FILE}:"
                    sudo grep -v '^#' "${TRAFIK_AUTH_FILE}" 2>/dev/null | cut -d: -f1 | sed 's/^/ - /' || echo " (File is empty or error reading)"
                else
                    echo -e "${RED}ERROR: Auth file not found.${NC}" >&2
                fi
                ;;
            0)
                return 0 ;;
            *)
                echo -e "${RED}ERROR: Invalid choice.${NC}" >&2 ;;
        esac
        echo ""; read -p "... Press Enter to continue ..."
    done
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
