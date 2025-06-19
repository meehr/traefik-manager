#!/bin/bash
# ===============================================================================
# Traefik Management Script - Installation Module
# ===============================================================================

#===============================================================================
# Funktion: Installieren oder Überschreiben von Traefik
#===============================================================================
install_traefik() {
  print_header "Traefik Installation / Update"
  echo -e "${BLUE}INFO: Installiert/aktualisiert Traefik.${NC}"; echo "--------------------------------------------------"
  if is_traefik_installed; then local c=false; ask_confirmation "${YELLOW}WARNUNG: Traefik scheint bereits installiert zu sein. Bestehende Konfiguration und Binärdatei überschreiben?${NC}" c; if ! $c; then echo "Abbruch."; return 1; fi; echo -e "${YELLOW}INFO: Fahre mit dem Überschreiben fort...${NC}"; fi
  read -p "Traefik-Version [${DEFAULT_TRAEFIK_VERSION}]: " TRAEFIK_VERSION; TRAEFIK_VERSION=${TRAEFIK_VERSION:-$DEFAULT_TRAEFIK_VERSION};
  read -p "E-Mail für Let's Encrypt: " LETSENCRYPT_EMAIL; while ! [[ "$LETSENCRYPT_EMAIL" =~ ^[^@]+@[^@]+\.[^@]+$ ]]; do echo -e "${RED}FEHLER: Ungültige E-Mail.${NC}" >&2; read -p "E-Mail: " LETSENCRYPT_EMAIL; done;
  read -p "Domain für das Dashboard (z.B. traefik.ihredomain.com): " TRAEFIK_DOMAIN; while [[ -z "$TRAEFIK_DOMAIN" ]]; do echo -e "${RED}FEHLER: Domain fehlt.${NC}" >&2; read -p "Dashboard-Domain: " TRAEFIK_DOMAIN; done;
  read -p "Dashboard-Benutzername: " BASIC_AUTH_USER; while [[ -z "$BASIC_AUTH_USER" ]]; do echo -e "${RED}FEHLER: Benutzername fehlt.${NC}" >&2; read -p "Login-Benutzername: " BASIC_AUTH_USER; done;
  while true; do read -sp "Passwort für '${BASIC_AUTH_USER}': " BASIC_AUTH_PASSWORD; echo; if [[ -z "$BASIC_AUTH_PASSWORD" ]]; then echo -e "${RED}FEHLER: Passwort leer.${NC}" >&2; continue; fi; read -sp "Passwort bestätigen: " BASIC_AUTH_PASSWORD_CONFIRM; echo; if [[ "$BASIC_AUTH_PASSWORD" == "$BASIC_AUTH_PASSWORD_CONFIRM" ]]; then echo -e "${GREEN}Passwort OK.${NC}"; break; else echo -e "${RED}FEHLER: Passwörter stimmen nicht überein.${NC}" >&2; fi; done; echo ""

  echo -e "${BLUE}>>> [1/7] System & Werkzeuge aktualisieren...${NC}";
  if ! sudo apt update; then echo -e "${RED}FEHLER: apt update fehlgeschlagen.${NC}" >&2; return 1; fi
  check_dependencies;
  echo -e "${GREEN} Werkzeuge OK.${NC}";

  echo -e "${BLUE}>>> [2/7] Verzeichnisse erstellen...${NC}";
  sudo mkdir -p "${TRAEFIK_CONFIG_DIR}"/{config,dynamic_conf,certs} || { echo -e "${RED}FEHLER: Konfigurationsverzeichnisse konnten nicht erstellt werden.${NC}" >&2; return 1; }
  sudo mkdir -p "${TRAEFIK_LOG_DIR}" || { echo -e "${RED}FEHLER: Log-Verzeichnis konnte nicht erstellt werden.${NC}" >&2; return 1; }
  sudo touch "${ACME_TLS_FILE}" || { echo -e "${RED}FEHLER: ACME-Datei konnte nicht erstellt werden.${NC}" >&2; return 1; }
  sudo chmod 600 "${ACME_TLS_FILE}" || echo -e "${YELLOW}WARNUNG: Berechtigungen für ACME-Datei konnten nicht gesetzt werden.${NC}" >&2
  echo -e "${GREEN} Verzeichnisse/ACME-Datei OK.${NC}";

  echo -e "${BLUE}>>> [3/7] Traefik ${TRAEFIK_VERSION} herunterladen...${NC}";
  local ARCH=$(dpkg --print-architecture); local TARGET_ARCH="amd64";
  if [[ "$ARCH" != "$TARGET_ARCH" ]]; then local ac=false; ask_confirmation "${YELLOW}WARNUNG: Ihre Systemarchitektur ('${ARCH}') weicht vom typischen Ziel ('${TARGET_ARCH}') ab. Download fortsetzen?${NC}" ac; if ! $ac; then echo "Abbruch."; return 1; fi; fi;
  local DOWNLOAD_URL="https://github.com/${GITHUB_REPO}/releases/download/${TRAEFIK_VERSION}/traefik_${TRAEFIK_VERSION}_linux_${TARGET_ARCH}.tar.gz";
  local TAR_FILE="/tmp/traefik_${TRAEFIK_VERSION}_linux_${TARGET_ARCH}.tar.gz";
  echo " Von: ${DOWNLOAD_URL}";
  if ! curl -sfL -o "$TAR_FILE" "$DOWNLOAD_URL"; then echo -e "${RED}FEHLER: Download fehlgeschlagen! URL prüfen? Version ${TRAEFIK_VERSION} existiert?${NC}" >&2; return 1; fi; echo "OK";

  echo " Entpacken...";
  sudo tar xzvf "$TAR_FILE" -C /tmp/ traefik || { echo -e "${RED}FEHLER: Entpacken fehlgeschlagen!${NC}" >&2; rm -f "$TAR_FILE"; return 1; }
  echo " Installieren...";
  sudo mv -f /tmp/traefik "${TRAEFIK_BINARY_PATH}" || { echo -e "${RED}FEHLER: Konnte Binärdatei nicht verschieben!${NC}" >&2; rm -f "$TAR_FILE"; return 1; }
  sudo chmod +x "${TRAEFIK_BINARY_PATH}" || echo -e "${YELLOW}WARNUNG: Konnte Ausführungsrechte für Binärdatei nicht setzen.${NC}" >&2
  echo " Aufräumen..."; rm -f "$TAR_FILE";
  local INSTALLED_VERSION=$("${TRAEFIK_BINARY_PATH}" version 2>/dev/null | grep -i Version | awk '{print $2}');
  echo -e "${GREEN} Traefik ${INSTALLED_VERSION:-unbekannt} installiert.${NC}";

  echo -e "${BLUE}>>> [4/7] ${STATIC_CONFIG_FILE} erstellen...${NC}";
  sudo mkdir -p "$(dirname "${STATIC_CONFIG_FILE}")" || { echo -e "${RED}ERROR: Could not create config subdirectory.${NC}" >&2; return 1; }
  sudo tee "${STATIC_CONFIG_FILE}" > /dev/null <<EOF
# Statische Hauptkonfiguration für Traefik
global:
  checkNewVersion: true
  sendAnonymousUsage: false
api:
  dashboard: true
  insecure: false
log:
  level: INFO
  filePath: "${TRAEFIK_LOG_DIR}/traefik.log"
  format: json
accessLog:
  filePath: "${TRAEFIK_LOG_DIR}/access.log"
  format: json
  bufferingSize: 100
entryPoints:
  web:
    address: ":80"
    http:
      redirections:
        entryPoint:
          to: websecure
          scheme: https
          permanent: true
    forwardedHeaders:
      trustedIPs:
        - "127.0.0.1/8"
        - "::1/128"
        - "192.168.0.0/16" # BITTE ANPASSEN
        - "172.16.0.0/12"
        - "10.0.0.0/8"
  websecure:
    address: ":443"
    http:
      tls:
        certResolver: tls_resolver
        options: default@file
    forwardedHeaders:
      trustedIPs:
        - "127.0.0.1/8"
        - "::1/128"
        - "192.168.0.0/16" # BITTE ANPASSEN
        - "172.16.0.0/12"
        - "10.0.0.0/8"
providers:
  file:
    directory: "${TRAEFIK_DYNAMIC_CONF_DIR}"
    watch: true
certificatesResolvers:
  tls_resolver:
    acme:
      email: "${LETSENCRYPT_EMAIL}"
      storage: "${ACME_TLS_FILE}"
      httpChallenge:
         entryPoint: web
EOF
  echo -e "${GREEN} Hauptkonfiguration OK.${NC}";

  echo -e "${BLUE}>>> [5/7] Dynamische Basiskonfigurationen erstellen...${NC}";
  sudo mkdir -p "$(dirname "${MIDDLEWARES_FILE}")" || { echo -e "${RED}ERROR: Could not create dynamic config directory.${NC}" >&2; return 1; }
  sudo tee "${MIDDLEWARES_FILE}" > /dev/null <<EOF
# Middleware-Definitionen & Globale TLS-Optionen
http:
  middlewares:
    traefik-auth:
      basicAuth:
        usersFile: "${TRAEFIK_AUTH_FILE}"
    default-security-headers:
      headers:
        contentTypeNosniff: true
        forceSTSHeader: true
        stsIncludeSubdomains: true
        stsPreload: true
        stsSeconds: 31536000
        frameDeny: true
    default-chain:
      chain:
        middlewares:
          - default-security-headers@file
tls:
  options:
    default:
      minVersion: VersionTLS12
      cipherSuites:
        - TLS_AES_128_GCM_SHA256
        - TLS_AES_256_GCM_SHA384
        - TLS_CHACHA20_POLY1305_SHA256
        - TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256
        - TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384
EOF
  echo -e "${GREEN} middlewares.yml OK.${NC}";
  sudo tee "${TRAEFIK_DYNAMIC_CONF_DIR}/traefik_dashboard.yml" > /dev/null <<EOF
# Dynamische Konfiguration NUR für das Traefik-Dashboard
http:
  routers:
    traefik-dashboard-secure:
      rule: "Host(\`${TRAEFIK_DOMAIN}\`)"
      service: api@internal
      entryPoints:
        - websecure
      middlewares:
        - "traefik-auth@file"
      tls:
        certResolver: tls_resolver
EOF
  echo -e "${GREEN} Dynamische Konfigurationen OK.${NC}";

  echo -e "${BLUE}>>> [6/7] Passwortschutz einrichten...${NC}";
  local htpasswd_cmd="sudo htpasswd -b";
  if [[ ! -f "${TRAEFIK_AUTH_FILE}" ]]; then htpasswd_cmd="sudo htpasswd -cb"; fi
  $htpasswd_cmd "${TRAEFIK_AUTH_FILE}" "${BASIC_AUTH_USER}" "${BASIC_AUTH_PASSWORD}" || { echo -e "${RED}FEHLER bei htpasswd!${NC}" >&2; return 1; }
  sudo chmod 600 "${TRAEFIK_AUTH_FILE}" || echo -e "${YELLOW}WARNUNG: Berechtigungen für Passwortdatei konnten nicht gesetzt werden.${NC}" >&2
  echo -e "${GREEN} Passwortschutz OK.${NC}";

  echo -e "${BLUE}>>> [7/7] Systemd-Dienst erstellen...${NC}";
  sudo tee "${TRAEFIK_SERVICE_FILE}" > /dev/null <<EOF
[Unit]
Description=Traefik Modern HTTP Reverse Proxy
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
Group=root
CapabilityBoundingSet=CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_BIND_SERVICE
NoNewPrivileges=true
ExecStart=${TRAEFIK_BINARY_PATH} --configfile=${STATIC_CONFIG_FILE}
Restart=on-failure
RestartSec=5s
ReadWritePaths=${TRAEFIK_CONFIG_DIR} ${TRAEFIK_LOG_DIR}

[Install]
WantedBy=multi-user.target
EOF
  echo -e "${GREEN} Systemd OK.${NC}";

  echo -e "${BLUE}>>> Traefik-Dienst aktivieren & starten...${NC}";
  sudo systemctl daemon-reload && sudo systemctl enable --now "${TRAEFIK_SERVICE_NAME}"
  echo " Warte 5s..."; sleep 5;
  sudo systemctl status "${TRAEFIK_SERVICE_NAME}" --no-pager -l

  echo "--------------------------------------------------"; echo -e "${GREEN}${BOLD} Installation/Update abgeschlossen! ${NC}";
  return 0
}

#===============================================================================
# Funktion: Traefik deinstallieren
#===============================================================================
uninstall_traefik() {
    echo ""; echo -e "${RED}!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!${NC}"; echo -e "${RED}!! ACHTUNG: DEINSTALLATION! ALLES WIRD GELÖSCHT!                           !!${NC}"; echo -e "${RED}!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!${NC}";
    local d=false; ask_confirmation "${RED}${BOLD}Letzte Chance:${NC}${RED} Wirklich ALLES im Zusammenhang mit Traefik löschen?${NC}" d; if ! $d; then echo "Abbruch."; return 1; fi;
    
    echo -e "${BLUE}>>> Deinstallation wird gestartet...${NC}";
    remove_autobackup >/dev/null 2>&1
    remove_ip_logging >/dev/null 2>&1

    echo "[1/8] Dienst stoppen..."; sudo systemctl stop "${TRAEFIK_SERVICE_NAME}" 2>/dev/null
    echo "[2/8] Autostart deaktivieren..."; sudo systemctl disable "${TRAEFIK_SERVICE_NAME}" 2>/dev/null
    echo "[3/8] Dienstdatei entfernen..."; sudo rm -f "${TRAEFIK_SERVICE_FILE}"
    echo "[4/8] Systemd neu laden..."; sudo systemctl daemon-reload; sudo systemctl reset-failed
    echo "[5/8] Binärdatei entfernen..."; sudo rm -f "${TRAEFIK_BINARY_PATH}"
    echo "[6/8] Konfigurationen entfernen..."; sudo rm -rf "${TRAEFIK_CONFIG_DIR}"
    echo "[7/8] Logs entfernen..."; sudo rm -rf "${TRAEFIK_LOG_DIR}"
    echo "[8/8] Hilfsskripte & Logrotate-Konfigs entfernen...";
    sudo rm -f "${IPLOGGER_HELPER_SCRIPT}" "${IPLOGGER_LOGROTATE_CONF}"

    echo ""; echo -e "${GREEN}===========================================${NC}"; echo -e "${GREEN} Deinstallation abgeschlossen.${NC}"; echo -e "${GREEN}===========================================${NC}";
    return 0
}
