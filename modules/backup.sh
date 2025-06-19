#!/bin/bash
# ===============================================================================
# Traefik Management Script - Backup and Restore Module
# ===============================================================================

#===============================================================================
# Funktion: Backup erstellen
#===============================================================================
backup_traefik() {
    local non_interactive=${1:-false}
    if ! $non_interactive; then
        echo ""; echo -e "${MAGENTA}==================================================${NC}"; echo -e "${BOLD} Backup Traefik Configuration${NC}"; echo -e "${MAGENTA}==================================================${NC}"
    fi
    if ! is_traefik_installed; then echo -e "${RED}ERROR: Traefik not installed.${NC}" >&2; return 1; fi
    sudo mkdir -p "${BACKUP_DIR}" || { echo -e "${RED}ERROR: Could not create backup directory ${BACKUP_DIR}.${NC}" >&2; return 1; }
    
    local backup_filename="traefik-backup-$(date +%Y%m%d-%H%M%S).tar.gz";
    local full_backup_path="${BACKUP_DIR}/${backup_filename}"

    if $non_interactive; then
        echo "[$(date +'%Y-%m-%d %H:%M:%S')] Creating backup: ${full_backup_path} ..."
    else
        echo "Creating backup of ${TRAEFIK_CONFIG_DIR} to ${full_backup_path} ...";
    fi

    if sudo tar -czvf "${full_backup_path}" -C "${TRAEFIK_CONFIG_DIR}" . ; then
        if $non_interactive; then
             echo "[$(date +'%Y-%m-%d %H:%M:%S')] Backup created successfully."
        else
             echo -e "${GREEN} Backup successful: ${full_backup_path}${NC}";
        fi
         return 0
    else
         echo -e "${RED}ERROR: Backup failed!${NC}" >&2
         sudo rm -f "${full_backup_path}"; return 1;
    fi
}

#===============================================================================
# Funktion: Backup wiederherstellen
#===============================================================================
restore_traefik() {
    echo ""; echo -e "${MAGENTA}==================================================${NC}"; echo -e "${BOLD} Restore Traefik Configuration${NC}"; echo -e "${MAGENTA}==================================================${NC}";
    if [ ! -d "$BACKUP_DIR" ]; then echo -e "${RED}ERROR: Backup directory ${BACKUP_DIR} not found.${NC}" >&2; return 1; fi
    echo "Available backups:"; local files=(); local i=1;
    while IFS= read -r -d $'\0' file; do
        files+=("$(basename "$file")"); echo -e "    ${BOLD}${i})${NC} $(basename "$file")"; ((i++));
    done < <(find "${BACKUP_DIR}" -maxdepth 1 -name 'traefik-backup-*.tar.gz' -type f -print0 | sort -zr)
    if [ ${#files[@]} -eq 0 ]; then echo -e "${YELLOW}No backups found.${NC}"; return 1; fi; echo -e "    ${BOLD}0)${NC} Back";
    read -p "Number of the backup to restore [0-${#files[@]}]: " choice
    if ! [[ "$choice" =~ ^[0-9]+$ ]] || [[ "$choice" -lt 0 ]] || [[ "$choice" -gt ${#files[@]} ]]; then echo -e "${RED}ERROR: Invalid selection.${NC}" >&2; return 1; fi; if [[ "$choice" -eq 0 ]]; then return 1; fi

    local fname="${files[$((choice-1))]}"; local fpath="${BACKUP_DIR}/${fname}";
    local restore_confirmed=false; ask_confirmation "${RED}${BOLD}WARNING:${NC} This will overwrite the current configuration in ${TRAEFIK_CONFIG_DIR}. Are you sure?${NC}" restore_confirmed; if ! $restore_confirmed; then echo "Aborting."; return 1; fi
    
    echo -e "${BLUE}Stopping Traefik...${NC}";
    manage_service "stop"
    
    echo -e "${BLUE}Restoring '${fname}'...${NC}";
    if sudo tar -xzvf "${fpath}" -C "${TRAEFIK_CONFIG_DIR}" --overwrite; then
        echo -e "${GREEN}Backup restored successfully.${NC}";
    else
        echo -e "${RED}ERROR: Restore failed!${NC}" >&2; return 1;
    fi

    local start_confirmed=false; ask_confirmation "Start Traefik now?" start_confirmed; if $start_confirmed; then manage_service "start"; fi
    return 0
}
