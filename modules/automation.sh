#!/bin/bash
# ===============================================================================
# Traefik Management Script - Automation Module
# ===============================================================================

#===============================================================================
# Funktion: Automatisches Backup einrichten/ändern
#===============================================================================
setup_autobackup() {
    echo ""; echo -e "${MAGENTA}==================================================${NC}"; echo -e "${BOLD} Setup/Modify Automatic Backup${NC}"; echo -e "${MAGENTA}==================================================${NC}";

    local service_file="/etc/systemd/system/${AUTOBACKUP_SERVICE}"
    local timer_file="/etc/systemd/system/${AUTOBACKUP_TIMER}"
    local overwrite_confirmed=false

    if [[ -f "$service_file" || -f "$timer_file" ]]; then
        echo -e "${YELLOW}WARNING: Autobackup service/timer files already exist.${NC}"
        ask_confirmation "${YELLOW}Overwrite existing autobackup files and reconfigure?${NC}" overwrite_confirmed
        if ! $overwrite_confirmed; then
            echo "Aborting."; return 1
        fi
        echo -e "${BLUE}INFO: Overwriting existing configuration...${NC}"
    fi

    # --- Service File Content ---
    echo -e "${BLUE}Creating Systemd service file (${AUTOBACKUP_SERVICE})...${NC}"
    if ! sudo tee "$service_file" > /dev/null <<EOF
[Unit]
Description=Traefik Automatic Backup Service
Documentation=file://${SCRIPT_PATH}
After=network.target

[Service]
Type=oneshot
# Executes the main script in non-interactive backup mode
# Note: SCRIPT_DIR is determined by the main script
ExecStart=${SCRIPT_DIR}/traefik-manager.sh --run-backup
User=root
Group=root
StandardOutput=append:${AUTOBACKUP_LOG}
StandardError=append:${AUTOBACKUP_LOG}
WorkingDirectory=/tmp

[Install]
WantedBy=multi-user.target
EOF
    then
        echo -e "${RED}ERROR: Could not create service file '${service_file}'.${NC}" >&2
        return 1
    fi
    sudo chmod 644 "$service_file"

    # --- Timer File Content ---
    echo -e "${BLUE}Creating Systemd timer file (${AUTOBACKUP_TIMER})...${NC}"
    local backup_schedule="daily"
    local random_delay="1h"
    echo -e "${CYAN}INFO: Backup will run daily by default (with up to ${random_delay} delay).${NC}"
    echo -e "${CYAN}      You can adjust the schedule later in '${timer_file}'.${NC}"

    if ! sudo tee "$timer_file" > /dev/null <<EOF
[Unit]
Description=Traefik Automatic Backup Timer (runs ${AUTOBACKUP_SERVICE})
Documentation=file://${SCRIPT_PATH}
Requires=${AUTOBACKUP_SERVICE}

[Timer]
OnCalendar=${backup_schedule}
Persistent=true
RandomizedDelaySec=${random_delay}
Unit=${AUTOBACKUP_SERVICE}

[Install]
WantedBy=timers.target
EOF
    then
        echo -e "${RED}ERROR: Could not create timer file '${timer_file}'.${NC}" >&2
        sudo rm -f "$service_file" # Cleanup
        return 1
    fi
    sudo chmod 644 "$timer_file"

    # --- Enable and Start Timer ---
    echo -e "${BLUE}Enabling and starting the timer...${NC}"
    if ! sudo systemctl daemon-reload; then
        echo -e "${RED}ERROR: systemctl daemon-reload failed.${NC}" >&2; return 1
    fi
    if ! sudo systemctl enable --now "${AUTOBACKUP_TIMER}"; then
        echo -e "${RED}ERROR: Could not enable/start timer '${AUTOBACKUP_TIMER}'.${NC}" >&2; return 1
    fi

    echo "--------------------------------------------------"
    echo -e "${GREEN}Automatic backup set up successfully!${NC}"
    echo " Timer status: $(systemctl is-active ${AUTOBACKUP_TIMER})"
    echo " Next run: $(systemctl list-timers "${AUTOBACKUP_TIMER}" | grep NEXT | awk '{print $4, $5, $6, $7}')"
    echo "=================================================="
    return 0
}

#===============================================================================
# Funktion: Automatisches Backup entfernen
#===============================================================================
remove_autobackup() {
    echo ""; echo -e "${MAGENTA}==================================================${NC}"; echo -e "${BOLD} Remove Automatic Backup${NC}"; echo -e "${MAGENTA}==================================================${NC}";

    local service_file="/etc/systemd/system/${AUTOBACKUP_SERVICE}"
    local timer_file="/etc/systemd/system/${AUTOBACKUP_TIMER}"
    local remove_confirmed=false

    if [[ ! -f "$service_file" && ! -f "$timer_file" ]]; then
        echo -e "${YELLOW}INFO: Autobackup service/timer files not found.${NC}"; return 0
    fi

    ask_confirmation "${RED}Really stop, disable, and delete the autobackup service and timer?${NC}" remove_confirmed
    if ! $remove_confirmed; then echo "Aborting."; return 1; fi

    echo -e "${BLUE}Stopping and disabling timer...${NC}"
    sudo systemctl stop "${AUTOBACKUP_TIMER}" 2>/dev/null || true
    sudo systemctl disable "${AUTOBACKUP_TIMER}" 2>/dev/null || true

    echo -e "${BLUE}Removing Systemd unit files...${NC}"
    sudo rm -f "$timer_file" "$service_file"

    echo -e "${BLUE}Reloading Systemd...${NC}"
    sudo systemctl daemon-reload 2>/dev/null || true
    sudo systemctl reset-failed "${AUTOBACKUP_TIMER}" "${AUTOBACKUP_SERVICE}" 2>/dev/null || true

    echo "--------------------------------------------------"
    echo -e "${GREEN}Automatic backup removed successfully.${NC}"
    echo "=================================================="
    return 0
}

#===============================================================================
# Funktion: Dediziertes IP-Logging einrichten
#===============================================================================
setup_ip_logging() {
    echo ""; echo -e "${MAGENTA}==================================================${NC}"; echo -e "${BOLD} Setup Dedicated IP Logging${NC}"; echo -e "${MAGENTA}==================================================${NC}";

    if ! ensure_dependency_installed "jq" "jq"; then return 1; fi

    local access_log_format
    # CORRECTED: Replaced the complex awk block with the simple, user-verified one-liner.
    access_log_format=$(sudo awk '/^[[:space:]]*accessLog:/ {flag=1; next} flag && /^[[:space:]]*format:/ {print $2; exit}' "${STATIC_CONFIG_FILE}")

    if [[ "$access_log_format" != "json" ]]; then
        echo -e "${RED}ERROR: Traefik Access Log Format is not set to 'json' in ${STATIC_CONFIG_FILE} (or could not be read)!${NC}" >&2
        echo -e "${RED}        The IP logging script requires JSON logs. Please correct the Traefik configuration.${NC}" >&2
        return 1
    fi

    local service_file="/etc/systemd/system/${IPLOGGER_SERVICE}"
    local timer_file="/etc/systemd/system/${IPLOGGER_SERVICE%.service}.timer"
    local overwrite_confirmed=false

    if [[ -f "$service_file" || -f "$timer_file" || -f "$IPLOGGER_HELPER_SCRIPT" || -f "$IPLOGGER_LOGROTATE_CONF" ]]; then
        ask_confirmation "${YELLOW}IP Logger files exist. Overwrite?${NC}" overwrite_confirmed
        if ! $overwrite_confirmed; then echo "Aborting."; return 1; fi
    fi

    # --- Helper Script Content ---
    echo -e "${BLUE}Creating helper script (${IPLOGGER_HELPER_SCRIPT})...${NC}"
    if ! sudo tee "$IPLOGGER_HELPER_SCRIPT" > /dev/null <<EOF
#!/bin/bash
ACCESS_LOG="${TRAFIK_LOG_DIR}/access.log"
IP_LOG="${IP_LOG_FILE}"
if [ ! -r "\${ACCESS_LOG}" ]; then exit 0; fi
mkdir -p "$(dirname "\${IP_LOG}")"
# Use jq to safely parse JSON and extract the client IP
jq -r 'select(.ClientHost != null or .ClientAddr != null) | now | strftime("+%Y-%m-%d %H:%M:%S") + " " + (.ClientHost // .ClientAddr)' "\${ACCESS_LOG}" >> "\${IP_LOG}"
EOF
    then echo -e "${RED}ERROR: Could not create helper script.${NC}" >&2; return 1; fi
    sudo chmod +x "$IPLOGGER_HELPER_SCRIPT"

    # --- Service File Content ---
    echo -e "${BLUE}Creating Systemd service file (${IPLOGGER_SERVICE})...${NC}"
    if ! sudo tee "$service_file" > /dev/null <<EOF
[Unit]
Description=Traefik IP Address Logger Service
After=traefik.service
[Service]
Type=oneshot
ExecStart=${IPLOGGER_HELPER_SCRIPT}
User=root
EOF
    then echo -e "${RED}ERROR: Could not create service file '${service_file}'.${NC}" >&2; return 1; fi
    sudo chmod 644 "$service_file"

    # --- Timer File Content ---
    echo -e "${BLUE}Creating Systemd timer file...${NC}"
    if ! sudo tee "$timer_file" > /dev/null <<EOF
[Unit]
Description=Traefik IP Address Logger Timer
[Timer]
OnCalendar=*:0/15
Persistent=true
[Install]
WantedBy=timers.target
EOF
    then echo -e "${RED}ERROR: Could not create timer file '${timer_file}'.${NC}" >&2; return 1; fi
    sudo chmod 644 "$timer_file"

    # --- Logrotate Configuration ---
    echo -e "${BLUE}Creating Logrotate configuration...${NC}"
    if ! sudo tee "$IPLOGGER_LOGROTATE_CONF" > /dev/null <<EOF
${IP_LOG_FILE} {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 0640 root adm
}
EOF
    then echo -e "${RED}ERROR: Could not create logrotate file '${IPLOGGER_LOGROTATE_CONF}'.${NC}" >&2; return 1; fi
    sudo chmod 644 "$IPLOGGER_LOGROTATE_CONF"

    # --- Enable and Start Timer ---
    echo -e "${BLUE}Enabling and starting the timer...${NC}"
    sudo systemctl daemon-reload
    if ! sudo systemctl enable --now "${timer_file}"; then
        echo -e "${RED}ERROR: Could not enable/start timer '${timer_file}'.${NC}" >&2; return 1
    fi

    echo "--------------------------------------------------"
    echo -e "${GREEN}Dedicated IP Logging set up successfully!${NC}"
    echo " Timer Status: $(systemctl is-active ${timer_file})"
    echo "=================================================="
    return 0
}

#===============================================================================
# Funktion: Dediziertes IP-Logging entfernen
#===============================================================================
remove_ip_logging() {
    echo ""; echo -e "${MAGENTA}==================================================${NC}"; echo -e "${BOLD} Remove Dedicated IP Logging${NC}"; echo -e "${MAGENTA}==================================================${NC}";

    local service_file="/etc/systemd/system/${IPLOGGER_SERVICE}"
    local timer_file="/etc/systemd/system/${IPLOGGER_SERVICE%.service}.timer"
    local remove_confirmed=false

    if [[ ! -f "$service_file" && ! -f "$timer_file" && ! -f "$IPLOGGER_HELPER_SCRIPT" && ! -f "$IPLOGGER_LOGROTATE_CONF" ]]; then
        echo -e "${YELLOW}INFO: IP Logger files not found.${NC}"; return 0
    fi

    ask_confirmation "${RED}Really remove the IP Logger service, timer, helper script, and logrotate config?${NC}" remove_confirmed
    if ! $remove_confirmed; then echo "Aborting."; return 1; fi

    echo -e "${BLUE}Stopping and disabling timer...${NC}"
    sudo systemctl stop "${timer_file}" 2>/dev/null || true
    sudo systemctl disable "${timer_file}" 2>/dev/null || true

    echo -e "${BLUE}Removing files...${NC}"
    sudo rm -f "$timer_file" "$service_file" "$IPLOGGER_HELPER_SCRIPT" "$IPLOGGER_LOGROTATE_CONF"

    echo -e "${BLUE}Reloading Systemd...${NC}"
    sudo systemctl daemon-reload 2>/dev/null || true
    sudo systemctl reset-failed "${timer_file}" "${IPLOGGER_SERVICE}" 2>/dev/null || true

    echo "--------------------------------------------------"
    echo -e "${GREEN}Dedicated IP Logging removed successfully.${NC}"
    echo "=================================================="
    return 0
}
