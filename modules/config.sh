#!/bin/bash
# ===============================================================================
# Traefik Management Script - Configuration Module
# ===============================================================================

#===============================================================================
# Funktion: Neuen Dienst / Route hinzufügen
#===============================================================================
add_service() {
    echo ""; echo -e "${MAGENTA}==================================================${NC}"; echo -e "${BOLD} Add New Service / Route${NC}"; echo -e "${MAGENTA}==================================================${NC}"
    if ! is_traefik_installed; then echo -e "${RED}ERROR: Traefik not installed.${NC}" >&2; return 1; fi
    read -p "1. Unique name for this service (e.g., 'nextcloud'): " SERVICE_NAME; SERVICE_NAME=$(echo "$SERVICE_NAME" | sed -e 's/[^a-z0-9_-]//g' | tr '[:upper:]' '[:lower:]'); while [[ -z "$SERVICE_NAME" ]]; do echo -e "${RED}ERROR: Service name cannot be empty.${NC}" >&2; read -p "1. Service name (a-z, 0-9, -, _): " SERVICE_NAME; SERVICE_NAME=$(echo "$SERVICE_NAME" | sed -e 's/[^a-z0-9_-]//g' | tr '[:upper:]' '[:lower:]'); done
    CONFIG_FILE="${TRAEFIK_DYNAMIC_CONF_DIR}/${SERVICE_NAME}.yml"; echo "     INFO: Configuration file: '${CONFIG_FILE}'"
    if [[ -f "$CONFIG_FILE" ]]; then local ow=false; ask_confirmation "${YELLOW}WARNING: Configuration file '${CONFIG_FILE}' already exists. Overwrite?${NC}" ow; if ! $ow; then echo "Aborting."; return 1; fi; fi
    read -p "2. Full domain (e.g., 'cloud.domain.com'): " FULL_DOMAIN; while [[ -z "$FULL_DOMAIN" ]]; do echo -e "${RED}ERROR: Domain missing.${NC}" >&2; read -p "2. Domain: " FULL_DOMAIN; done
    read -p "3. Internal IP/Hostname of the target: " BACKEND_TARGET; while [[ -z "$BACKEND_TARGET" ]]; do echo -e "${RED}ERROR: IP/Hostname missing.${NC}" >&2; read -p "3. IP/Hostname: " BACKEND_TARGET; done
    read -p "4. Internal port of the target: " BACKEND_PORT; while ! [[ "$BACKEND_PORT" =~ ^[0-9]+$ ]] || [[ "$BACKEND_PORT" -lt 1 ]] || [[ "$BACKEND_PORT" -gt 65535 ]]; do echo -e "${RED}ERROR: Invalid port.${NC}" >&2; read -p "4. Port (1-65535): " BACKEND_PORT; done
    local backend_uses_https=false; ask_confirmation "5. Does the target service itself use HTTPS? " backend_uses_https
    BACKEND_SCHEME="http"; if $backend_uses_https; then BACKEND_SCHEME="https"; fi

    echo -e "${BLUE}Creating configuration...${NC}";
    sudo mkdir -p "$(dirname "$CONFIG_FILE")" || { echo -e "${RED}ERROR: Could not create directory for config.${NC}" >&2; return 1; }
    sudo tee "$CONFIG_FILE" > /dev/null <<EOF
# Dynamic configuration for Service: ${SERVICE_NAME}
http:
  routers:
    router-${SERVICE_NAME}-secure:
      rule: "Host(\`${FULL_DOMAIN}\`)"
      entryPoints:
        - "websecure"
      middlewares:
        - "default-chain@file"
      service: "service-${SERVICE_NAME}"
      tls:
        certResolver: "tls_resolver"
  services:
    service-${SERVICE_NAME}:
      loadBalancer:
        servers:
          - url: "${BACKEND_SCHEME}://${BACKEND_TARGET}:${BACKEND_PORT}"
        passHostHeader: true
EOF
    sudo chmod 644 "$CONFIG_FILE" || echo -e "${YELLOW}WARNING: Could not set permissions for '${CONFIG_FILE}'.${NC}" >&2
    echo -e "${GREEN}==================================================${NC}"; echo -e "${GREEN} Config for '${SERVICE_NAME}' created!${NC}";
    return 0
}

#===============================================================================
# Funktion: Bestehenden Dienst / Route ändern
#===============================================================================
modify_service() {
    echo ""; echo -e "${MAGENTA}==================================================${NC}"; echo -e "${BOLD} Modify Existing Service / Route${NC}"; echo -e "${MAGENTA}==================================================${NC}"
    if ! is_traefik_installed; then echo -e "${RED}ERROR: Traefik not installed.${NC}" >&2; return 1; fi
    echo "Available service configurations:"; local files=(); local i=1; local file;
    while IFS= read -r -d $'\0' file; do
        base=$(basename "$file")
        if [[ "$base" != "middlewares.yml" && "$base" != "traefik_dashboard.yml" ]]; then
            files+=("$base"); echo -e "    ${BOLD}${i})${NC} ${base}"; ((i++));
        fi
    done < <(find "${TRAEFIK_DYNAMIC_CONF_DIR}" -maxdepth 1 -name '*.yml' -type f -print0)
    if [ ${#files[@]} -eq 0 ]; then echo -e "${YELLOW}No modifiable configs found.${NC}"; return 1; fi; echo -e "    ${BOLD}0)${NC} Back";
    read -p "Number of the file to modify [0-${#files[@]}]: " choice
    if ! [[ "$choice" =~ ^[0-9]+$ ]] || [[ "$choice" -lt 0 ]] || [[ "$choice" -gt ${#files[@]} ]]; then echo -e "${RED}ERROR: Invalid selection.${NC}" >&2; return 1; fi; if [[ "$choice" -eq 0 ]]; then return 1; fi
    local fname="${files[$((choice-1))]}"; local fpath="${TRAEFIK_DYNAMIC_CONF_DIR}/${fname}"; local editor="${EDITOR:-nano}";
    echo -e "${BLUE}Opening '${fname}' with '${editor}'...${NC}"; sleep 2
    if sudo -E "$editor" "$fpath"; then
         echo -e "${GREEN}File '${fname}' edited. Traefik should detect changes automatically.${NC}";
    else
         echo -e "${YELLOW}WARNING: Editor exited with an error or file not saved.${NC}" >&2; return 1;
    fi; return 0
}

#===============================================================================
# Funktion: Dienst / Route entfernen
#===============================================================================
remove_service() {
    echo ""; echo -e "${MAGENTA}==================================================${NC}"; echo -e "${BOLD} Remove Service / Route${NC}"; echo -e "${MAGENTA}==================================================${NC}"
    if ! is_traefik_installed; then echo -e "${RED}ERROR: Traefik not installed.${NC}" >&2; return 1; fi
    echo "Available configs to remove:"; local files=(); local i=1; local file;
    while IFS= read -r -d $'\0' file; do
        base=$(basename "$file")
        if [[ "$base" != "middlewares.yml" && "$base" != "traefik_dashboard.yml" ]]; then
            files+=("$base"); echo -e "    ${BOLD}${i})${NC} ${base}"; ((i++));
        fi
    done < <(find "${TRAEFIK_DYNAMIC_CONF_DIR}" -maxdepth 1 -name '*.yml' -type f -print0)
    if [ ${#files[@]} -eq 0 ]; then echo -e "${YELLOW}No removable configs found.${NC}"; return 1; fi; echo -e "    ${BOLD}0)${NC} Back";
    read -p "Number [0-${#files[@]}]: " choice
    if ! [[ "$choice" =~ ^[0-9]+$ ]] || [[ "$choice" -lt 0 ]] || [[ "$choice" -gt ${#files[@]} ]]; then echo -e "${RED}ERROR: Invalid selection.${NC}" >&2; return 1; fi; if [[ "$choice" -eq 0 ]]; then return 1; fi
    local fname="${files[$((choice-1))]}"; local fpath="${TRAEFIK_DYNAMIC_CONF_DIR}/${fname}";
    local d=false; ask_confirmation "${RED}Are you sure you want to delete '${fname}'?${NC}" d; if ! $d; then echo "Aborting."; return 1; fi;
    if sudo rm -f "${fpath}"; then
        echo -e "${GREEN}File '${fname}' deleted.${NC}";
    else
         echo -e "${RED}ERROR: Deletion failed.${NC}" >&2; return 1;
    fi; return 0
}

#===============================================================================
# Funktion: Statische Traefik-Konfiguration bearbeiten
#===============================================================================
edit_static_config() {
    if [[ ! -f "$STATIC_CONFIG_FILE" ]]; then echo -e "${RED}ERROR: File (${STATIC_CONFIG_FILE}) not found.${NC}" >&2; return 1; fi;
    local editor="${EDITOR:-nano}";
    echo -e "${YELLOW}WARNING: Changes require a Traefik restart!${NC}";
    echo "Opening '${STATIC_CONFIG_FILE}' with '${editor}'..."; sleep 2
    if sudo -E "$editor" "$STATIC_CONFIG_FILE"; then
        echo -e "${GREEN}File edited.${NC}";
        local r=false; ask_confirmation "${YELLOW}Restart Traefik now?${NC}" r; if $r; then manage_service "restart"; fi;
    else
         echo -e "${YELLOW}WARNING: Editor exited with an error.${NC}" >&2; return 1;
    fi; return 0
}

#===============================================================================
# Funktion: Middleware-Konfiguration bearbeiten
#===============================================================================
edit_middlewares_config() {
    if [[ ! -f "$MIDDLEWARES_FILE" ]]; then echo -e "${RED}ERROR: File (${MIDDLEWARES_FILE}) not found.${NC}" >&2; return 1; fi;
    local editor="${EDITOR:-nano}";
    echo -e "${BLUE}INFO: Changes are usually detected automatically.${NC}";
    echo "Opening '${MIDDLEWARES_FILE}' with '${editor}'..."; sleep 2
    if sudo -E "$editor" "$MIDDLEWARES_FILE"; then
         echo -e "${GREEN}File edited.${NC}";
    else
         echo -e "${YELLOW}WARNING: Editor exited with an error.${NC}" >&2; return 1;
    fi; return 0
}

#===============================================================================
# Funktion: EntryPoints bearbeiten
#===============================================================================
edit_entrypoints() {
    echo -e "${YELLOW}Opening the main static config (${STATIC_CONFIG_FILE}) to edit EntryPoints...${NC}";
    edit_static_config
    return $?
}

#===============================================================================
# Funktion: Globale TLS-Optionen bearbeiten
#===============================================================================
edit_tls_options() {
     echo -e "${YELLOW}Opening the middlewares file (${MIDDLEWARES_FILE}) to edit global TLS options...${NC}";
     edit_middlewares_config
     return $?
}

#===============================================================================
# Funktion: Traefik-Plugin installieren
#===============================================================================
install_plugin() {
    echo ""; echo -e "${MAGENTA}==================================================${NC}"; echo -e "${BOLD} Add Traefik Plugin (Experimental)${NC}"; echo -e "${MAGENTA}==================================================${NC}";
    if ! is_traefik_installed; then echo -e "${RED}ERROR: Traefik not installed.${NC}" >&2; return 1; fi
    read -p "Plugin module name (e.g., github.com/user/traefik-plugin): " MODULE_NAME;
    read -p "Plugin version (e.g., v1.2.0): " VERSION;
    local PLUGIN_KEY_NAME=$(basename "$MODULE_NAME" | sed -e 's/[^a-zA-Z0-9]//g' | tr '[:upper:]' '[:lower:]');

    # Hier würde eine robustere Logik zum Einfügen des Plugins in die YAML-Datei stehen.
    # Dies ist ein vereinfachtes Beispiel.
    echo -e "\nexperimental:\n  plugins:\n    ${PLUGIN_KEY_NAME}:\n      moduleName: \"${MODULE_NAME}\"\n      version: \"${VERSION}\"" | sudo tee -a "${STATIC_CONFIG_FILE}"
    
    echo -e "${GREEN}Plugin declaration added to ${STATIC_CONFIG_FILE}.${NC}";
    echo -e "${YELLOW}IMPORTANT: Traefik RESTART required!${NC}";
    local r=false; ask_confirmation "${YELLOW}Restart Traefik now?${NC}" r; if $r; then manage_service "restart"; fi;
    return 0
}
