#!/bin/bash
# ===============================================================================
# Traefik Management Script - Automation Module
# ===============================================================================

#===============================================================================
# Funktion: Automatisches Backup einrichten/ändern
#===============================================================================
setup_autobackup() {
    echo ""; echo -e "${MAGENTA}==================================================${NC}"; echo -e "${BOLD} Setup Automatic Backup${NC}"; echo -e "${MAGENTA}==================================================${NC}";
    local service_file="/etc/systemd/system/${AUTOBACKUP_SERVICE}"
    local timer_file="/etc/systemd/system/${AUTOBACKUP_TIMER}"

    echo -e "${BLUE}Creating Systemd service file...${NC}"
    sudo tee "$service_file" > /dev/null <<EOF
[Unit]
Description=Traefik Automatic Backup Service
[Service]
Type=oneshot
ExecStart=${SCRIPT_DIR}/traefik-manager.sh --run-backup
EOF

    echo -e "${BLUE}Creating Systemd timer file...${NC}"
    sudo tee "$timer_file" > /dev/null <<EOF
[Unit]
Description=Traefik Automatic Backup Timer
[Timer]
OnCalendar=daily
Persistent=true
[Install]
WantedBy=timers.target
EOF

    echo -e "${BLUE}Enabling and starting timer...${NC}"
    sudo systemctl daemon-reload
    sudo systemctl enable --now "${AUTOBACKUP_TIMER}"
    echo -e "${GREEN}Automatic backup set up successfully!${NC}"
    return 0
}

#===============================================================================
# Funktion: Automatisches Backup entfernen
#===============================================================================
remove_autobackup() {
    echo ""; echo -e "${MAGENTA}==================================================${NC}"; echo -e "${BOLD} Remove Automatic Backup${NC}"; echo -e "${MAGENTA}==================================================${NC}";
    sudo systemctl stop "${AUTOBACKUP_TIMER}" 2>/dev/null
    sudo systemctl disable "${AUTOBACKUP_TIMER}" 2>/dev/null
    sudo rm -f "/etc/systemd/system/${AUTOBACKUP_TIMER}" "/etc/systemd/system/${AUTOBACKUP_SERVICE}"
    sudo systemctl daemon-reload
    echo -e "${GREEN}Automatic backup removed successfully.${NC}"
    return 0
}

#===============================================================================
# Funktion: Dediziertes IP-Logging einrichten
#===============================================================================
setup_ip_logging() {
    echo ""; echo -e "${MAGENTA}==================================================${NC}"; echo -e "${BOLD} Setup Dedicated IP Logging${NC}"; echo -e "${MAGENTA}==================================================${NC}";
    # Diese Funktion würde das Hilfsskript, den Service, den Timer und die logrotate-Konfiguration erstellen.
    echo "Diese Funktion ist komplex und muss die Erstellung mehrerer Dateien handhaben:"
    echo " - ${IPLOGGER_HELPER_SCRIPT}"
    echo " - /etc/systemd/system/${IPLOGGER_SERVICE}"
    echo " - /etc/systemd/system/${IPLOGGER_SERVICE%.service}.timer"
    echo " - ${IPLOGGER_LOGROTATE_CONF}"
    echo "Die Implementierung wurde aus Übersichtlichkeitsgründen hier gekürzt."
    return 1
}

#===============================================================================
# Funktion: Dediziertes IP-Logging entfernen
#===============================================================================
remove_ip_logging() {
    echo ""; echo -e "${MAGENTA}==================================================${NC}"; echo -e "${BOLD} Remove Dedicated IP Logging${NC}"; echo -e "${MAGENTA}==================================================${NC}";
    # Diese Funktion würde den Timer stoppen und alle zugehörigen Dateien löschen.
    echo "Diese Funktion würde den Timer stoppen/deaktivieren und alle zugehörigen Dateien löschen."
    return 1
}
