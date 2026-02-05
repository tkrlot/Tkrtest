#!/bin/bash
# SinusBot + TeamSpeak client/server installer
# Base: SinusBot installer by Philipp Eßwein (modified)
# Modifications:
#  - custom SinusBot download (tkrlot/Tkrtest sinusbot1.1.bz2)
#  - TeamSpeak client updated to 3.6.2
#  - Optional TeamSpeak 6 server download/install (systemd service, license acceptance, admin token capture)
# Installer version: 1.5-custom-ts6

set -euo pipefail

MACHINE=$(uname -m)
Instversion="1.5-custom-ts6"
USE_SYSTEMD=true

# === CONFIGURABLE VARIABLES ===
# Custom SinusBot release (user requested)
SINUSBOT_DOWNLOAD_URL="https://github.com/tkrlot/Tkrtest/releases/download/sinus/sinusbot1.1.bz2"
SINUSBOT_ARCHIVE_NAME="sinusbot1.1.bz2"

# TeamSpeak 3 client (fixed to 3.6.2)
TS3_VERSION="3.6.2"
TS3_CLIENT_URL="https://files.teamspeak-services.com/releases/client/${TS3_VERSION}/TeamSpeak3-Client-linux_amd64-${TS3_VERSION}.run"

# TeamSpeak 6 server (user asked for "teamspeak6 server github download and install")
# Replace this URL with the actual GitHub release URL for the TeamSpeak 6 server binary/tarball.
# Example placeholder (update if your actual release URL differs):
TS6_SERVER_URL="https://github.com/TeamSpeak-Systems/ts6-server/releases/latest/download/ts6-server-linux_amd64.tar.bz2"
# Local filename for TS6 archive
TS6_ARCHIVE_NAME="ts6-server.tar.bz2"

# Where to install SinusBot and TS6 server by default
DEFAULT_LOCATION="/opt/sinusbot"
DEFAULT_TS6_LOCATION="/opt/ts6server"

# === Helper functions ===
function greenMessage()  { echo -e "\\033[32;1m${*}\\033[0m"; }
function magentaMessage(){ echo -e "\\033[35;1m${*}\\033[0m"; }
function cyanMessage()   { echo -e "\\033[36;1m${*}\\033[0m"; }
function redMessage()    { echo -e "\\033[31;1m${*}\\033[0m"; }
function yellowMessage() { echo -e "\\033[33;1m${*}\\033[0m"; }
function errorExit()     { redMessage "${*}"; exit 1; }
function makeDir()       { if [ -n "${1:-}" ] && [ ! -d "$1" ]; then mkdir -p "$1"; fi; }

# Trap to show failing line on error
trap 'redMessage "Installer failed at line $LINENO"; exit 1' ERR

# Must be root
if [ "$(id -u)" != "0" ]; then
  errorExit "This installer must be run as root."
fi

# Ensure wget, tar, bunzip2 available
if ! command -v wget >/dev/null 2>&1; then
  if [[ -f /etc/centos-release ]]; then
    yum -y -q install wget
  else
    apt-get update -qq
    apt-get -qq install wget -y
  fi
fi

# Detect systemd
if [[ $(command -v systemctl) == "" ]]; then
  USE_SYSTEMD=false
fi

# === Interactive choices (keeps original flow) ===
cyanMessage "Installer version $Instversion"
sleep 1

redMessage "What should the installer do?"
OPTIONS=("Install" "Update" "Remove" "PW Reset" "Quit")
select OPTION in "${OPTIONS[@]}"; do
  case "$REPLY" in
    1|2|3|4) break ;;
    5) errorExit "User aborted." ;;
    *) redMessage "Invalid option." ;;
  esac
done

if [ "$OPTION" == "Install" ]; then INSTALL="Inst"
elif [ "$OPTION" == "Update" ]; then INSTALL="Updt"
elif [ "$OPTION" == "Remove" ]; then INSTALL="Rem"
elif [ "$OPTION" == "PW Reset" ]; then INSTALL="Res"
fi

# Choose install location for SinusBot
yellowMessage "Automatic usage or own directories?"
OPTIONS=("Automatic" "Own path" "Quit")
select CHOICE in "${OPTIONS[@]}"; do
  case "$REPLY" in
    1) LOCATION="$DEFAULT_LOCATION"; break ;;
    2) read -rp "Enter location (e.g. /opt/sinusbot): " LOCATION; break ;;
    3) errorExit "User aborted." ;;
    *) redMessage "Invalid option." ;;
  esac
done

makeDir "$LOCATION"
LOCATIONEX="$LOCATION/sinusbot"

# Ask whether to install TeamSpeak client (TS3) and whether to install TS6 server
if [[ "$INSTALL" == "Inst" || "$INSTALL" == "Updt" ]]; then
  yellowMessage "Install TeamSpeak 3 client (for SinusBot) and/or TeamSpeak 6 server?"
  OPTIONS=("Install both (TS3 client + TS6 server)" "Only TS3 client" "Only TS6 server" "Neither")
  select CH in "${OPTIONS[@]}"; do
    case "$REPLY" in
      1) INSTALL_TS3=true; INSTALL_TS6=true; break ;;
      2) INSTALL_TS3=true; INSTALL_TS6=false; break ;;
      3) INSTALL_TS3=false; INSTALL_TS6=true; break ;;
      4) INSTALL_TS3=false; INSTALL_TS6=false; break ;;
      *) redMessage "Invalid option." ;;
    esac
  done
fi

# Ask about YT-DL
redMessage "Should YT-DL (yt-dlp) be installed/updated?"
OPTIONS=("Yes" "No")
select YTCHOICE in "${OPTIONS[@]}"; do
  case "$REPLY" in 1) INSTALL_YT=true; break ;; 2) INSTALL_YT=false; break ;; *) redMessage "Invalid option." ;; esac
done

# Create or ensure SinusBot user exists (if installing)
if [ "$INSTALL" != "Rem" ]; then
  if [ "$INSTALL" == "Updt" ]; then
    SINUSBOTUSER=$(ls -ld "$LOCATION" | awk '{print $3}')
    [ -z "$SINUSBOTUSER" ] && SINUSBOTUSER=sinusbot
  else
    read -rp "Enter SinusBot username [sinusbot]: " SINUSBOTUSER
    SINUSBOTUSER=${SINUSBOTUSER:-sinusbot}
    if [ "$SINUSBOTUSER" == "root" ]; then errorExit "Do not use root as SinusBot user."; fi
    if ! id "$SINUSBOTUSER" >/dev/null 2>&1; then
      groupadd "$SINUSBOTUSER" || true
      useradd -m -s /bin/bash -g "$SINUSBOTUSER" "$SINUSBOTUSER" || errorExit "Failed to create user $SINUSBOTUSER"
    fi
    chown -R "$SINUSBOTUSER:$SINUSBOTUSER" "$LOCATION" || true
    chmod 750 -R "$LOCATION" || true
  fi
fi

# === Install TeamSpeak 3 client (3.6.2) if requested ===
if [[ "${INSTALL_TS3:-false}" == "true" ]]; then
  greenMessage "Installing TeamSpeak 3 client $TS3_VERSION..."
  makeDir "$LOCATION/teamspeak3-client"
  chown -R "$SINUSBOTUSER:$SINUSBOTUSER" "$LOCATION"
  cd "$LOCATION/teamspeak3-client"

  # Download TS3 client
  su -c "wget -q \"$TS3_CLIENT_URL\" -O TeamSpeak3-Client-linux_${ARCH:-amd64}-${TS3_VERSION}.run" "$SINUSBOTUSER"

  if [[ ! -f TeamSpeak3-Client-linux_${ARCH:-amd64}-${TS3_VERSION}.run ]]; then
    errorExit "Failed to download TeamSpeak 3 client."
  fi

  chmod +x TeamSpeak3-Client-linux_${ARCH:-amd64}-${TS3_VERSION}.run
  greenMessage "Running TeamSpeak 3 client installer (interactive EULA acceptance required)..."
  # Run installer as the SinusBot user (interactive)
  su -c "./TeamSpeak3-Client-linux_${ARCH:-amd64}-${TS3_VERSION}.run --quiet" "$SINUSBOTUSER" || true

  # If the installer created a directory, copy files to expected location
  if [ -d "TeamSpeak3-Client-linux_${ARCH:-amd64}" ]; then
    cp -R TeamSpeak3-Client-linux_${ARCH:-amd64}/* . || true
    rm -rf TeamSpeak3-Client-linux_${ARCH:-amd64}
  fi

  # Clean up run file
  rm -f TeamSpeak3-Client-linux_${ARCH:-amd64}-${TS3_VERSION}.run || true
  greenMessage "TeamSpeak 3 client installation finished."
fi

# === Download & extract SinusBot (custom) ===
if [[ "$INSTALL" == "Inst" || "$INSTALL" == "Updt" ]]; then
  greenMessage "Downloading custom SinusBot release..."
  cd "$LOCATION"
  su -c "wget -q \"$SINUSBOT_DOWNLOAD_URL\" -O \"$SINUSBOT_ARCHIVE_NAME\"" "$SINUSBOTUSER"

  if [[ ! -f "$SINUSBOT_ARCHIVE_NAME" && ! -f "$LOCATION/sinusbot" ]]; then
    errorExit "SinusBot download failed."
  fi

  greenMessage "Extracting SinusBot..."
  EXTRACT_OK=false
  # Try tar -xjf (tar.bz2)
  if su -c "tar -xjf \"$SINUSBOT_ARCHIVE_NAME\" -C \"$LOCATION\"" "$SINUSBOTUSER" 2>/dev/null; then
    EXTRACT_OK=true
  fi

  if [ "$EXTRACT_OK" != "true" ]; then
    TMP_UNBZ="/tmp/sinusbot_unbz_$$"
    if su -c "bunzip2 -c \"$SINUSBOT_ARCHIVE_NAME\" > \"$TMP_UNBZ\"" "$SINUSBOTUSER" 2>/dev/null; then
      if file "$TMP_UNBZ" | grep -qi 'tar archive'; then
        su -c "tar -xf \"$TMP_UNBZ\" -C \"$LOCATION\"" "$SINUSBOTUSER" 2>/dev/null && EXTRACT_OK=true || true
        rm -f "$TMP_UNBZ"
      else
        # treat as single binary
        su -c "mv \"$TMP_UNBZ\" \"$LOCATION/sinusbot\"" "$SINUSBOTUSER" 2>/dev/null || true
        su -c "chmod 755 \"$LOCATION/sinusbot\"" "$SINUSBOTUSER" 2>/dev/null || true
        EXTRACT_OK=true
      fi
    fi
  fi

  if [ "$EXTRACT_OK" != "true" ]; then
    errorExit "SinusBot extraction failed."
  fi

  rm -f "$SINUSBOT_ARCHIVE_NAME" || true
  chown -R "$SINUSBOTUSER:$SINUSBOTUSER" "$LOCATION"
  chmod 755 "$LOCATION/sinusbot" || true
  greenMessage "SinusBot installed/updated at $LOCATION."
fi

# === Install yt-dlp (optional) ===
if [[ "${INSTALL_YT:-false}" == "true" ]]; then
  greenMessage "Installing yt-dlp as youtube-dl replacement..."
  wget -q https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp -O /usr/local/bin/youtube-dl
  chmod a+rx /usr/local/bin/youtube-dl
  greenMessage "yt-dlp installed to /usr/local/bin/youtube-dl"
  # Add cronjob for updates if not present
  if ! grep -q 'youtube-dl -U' /etc/cron.d/ytdl 2>/dev/null; then
    echo "0 0 * * * $SINUSBOTUSER PATH=$PATH:/usr/local/bin; youtube-dl -U --restrict-filename >/dev/null" > /etc/cron.d/ytdl
    greenMessage "Added daily yt-dlp update cronjob."
  fi
fi

# === TeamSpeak 6 server install (optional) ===
# This section:
#  - downloads a TS6 server archive from TS6_SERVER_URL
#  - extracts it to DEFAULT_TS6_LOCATION (or user-chosen)
#  - creates a dedicated user 'ts6' (if not exists)
#  - creates a systemd service that restarts always (24/7)
#  - starts the server and attempts to capture the admin token from server logs
if [[ "${INSTALL_TS6:-false}" == "true" ]]; then
  greenMessage "Preparing TeamSpeak 6 server installation..."

  # Ask for TS6 install location
  read -rp "Install TeamSpeak 6 server to [${DEFAULT_TS6_LOCATION}]: " TS6_LOCATION
  TS6_LOCATION=${TS6_LOCATION:-$DEFAULT_TS6_LOCATION}
  makeDir "$TS6_LOCATION"

  # Create ts6 user
  TS6_USER="ts6"
  if ! id "$TS6_USER" >/dev/null 2>&1; then
    groupadd "$TS6_USER" || true
    useradd -r -m -d "$TS6_LOCATION" -s /bin/false -g "$TS6_USER" "$TS6_USER" || true
  fi

  # Download TS6 server archive
  greenMessage "Downloading TeamSpeak 6 server archive..."
  su -c "wget -q \"$TS6_SERVER_URL\" -O \"$TS6_LOCATION/$TS6_ARCHIVE_NAME\"" "$TS6_USER"

  if [[ ! -f "$TS6_LOCATION/$TS6_ARCHIVE_NAME" ]]; then
    redMessage "Warning: TeamSpeak 6 server archive not found at $TS6_LOCATION/$TS6_ARCHIVE_NAME"
    redMessage "Please verify TS6_SERVER_URL and try again."
  else
    # Extract TS6 archive (support tar.bz2 or tar.gz)
    greenMessage "Extracting TeamSpeak 6 server..."
    if su -c "tar -xjf \"$TS6_LOCATION/$TS6_ARCHIVE_NAME\" -C \"$TS6_LOCATION\"" "$TS6_USER" 2>/dev/null; then
      true
    elif su -c "tar -xzf \"$TS6_LOCATION/$TS6_ARCHIVE_NAME\" -C \"$TS6_LOCATION\"" "$TS6_USER" 2>/dev/null; then
      true
    else
      # try bunzip2 fallback
      TMP_TS6="/tmp/ts6_unbz_$$"
      if su -c "bunzip2 -c \"$TS6_LOCATION/$TS6_ARCHIVE_NAME\" > \"$TMP_TS6\"" "$TS6_USER" 2>/dev/null; then
        if file "$TMP_TS6" | grep -qi 'tar archive'; then
          su -c "tar -xf \"$TMP_TS6\" -C \"$TS6_LOCATION\"" "$TS6_USER" 2>/dev/null || true
        else
          # maybe single binary
          su -c "mv \"$TMP_TS6\" \"$TS6_LOCATION/ts6server\"" "$TS6_USER" 2>/dev/null || true
          su -c "chmod 755 \"$TS6_LOCATION/ts6server\"" "$TS6_USER" 2>/dev/null || true
        fi
        rm -f "$TMP_TS6"
      else
        redMessage "Failed to extract TeamSpeak 6 archive. Please check the archive format."
      fi
    fi

    # Remove archive
    rm -f "$TS6_LOCATION/$TS6_ARCHIVE_NAME" || true

    # Attempt to find server binary or start script
    TS6_BIN=""
    # common names to search for
    for candidate in "$TS6_LOCATION"/ts6* "$TS6_LOCATION"/*/ts6* "$TS6_LOCATION"/*/bin/*; do
      if [ -f "$candidate" ] && [ -x "$candidate" ]; then
        TS6_BIN="$candidate"
        break
      fi
    done
    # fallback: look for any file named 'ts6server' or 'tsserver' or 'teamspeak' and make executable
    if [ -z "$TS6_BIN" ]; then
      if [ -f "$TS6_LOCATION/ts6server" ]; then TS6_BIN="$TS6_LOCATION/ts6server"; fi
      if [ -z "$TS6_BIN" ] && [ -f "$TS6_LOCATION/tsserver" ]; then TS6_BIN="$TS6_LOCATION/tsserver"; fi
    fi
    if [ -z "$TS6_BIN" ]; then
      # try to find any executable under TS6_LOCATION
      TS6_BIN=$(find "$TS6_LOCATION" -type f -perm /111 -maxdepth 3 -print -quit || true)
    fi

    if [ -z "$TS6_BIN" ]; then
      redMessage "Could not locate TeamSpeak 6 server binary automatically. Please inspect $TS6_LOCATION and update the script."
    else
      greenMessage "Found TeamSpeak 6 server binary: $TS6_BIN"
      chown -R "$TS6_USER:$TS6_USER" "$TS6_LOCATION"
      chmod 750 "$TS6_BIN" || true

      # Create a simple systemd service for TS6 server that restarts always (24/7)
      SERVICE_PATH="/etc/systemd/system/ts6.service"
      cat > "$SERVICE_PATH" <<EOF
[Unit]
Description=TeamSpeak 6 Server
After=network.target

[Service]
Type=simple
User=$TS6_USER
Group=$TS6_USER
WorkingDirectory=$TS6_LOCATION
# If the server requires an env var to accept license, set it here. Adjust if needed.
Environment=TS6_ACCEPT_LICENSE=1
ExecStart=$TS6_BIN
Restart=always
RestartSec=5
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

      chmod 644 "$SERVICE_PATH"
      systemctl daemon-reload
      systemctl enable ts6.service

      greenMessage "Starting TeamSpeak 6 server (systemd service: ts6.service)..."
      systemctl start ts6.service

      # Wait for server to initialize and write logs; attempt to capture admin token
      greenMessage "Waiting for server to produce admin token in logs (this may take up to 60 seconds)..."
      sleep 3

      # Try to locate logs under TS6_LOCATION (common patterns)
      LOG_DIR_CANDIDATES=("$TS6_LOCATION" "$TS6_LOCATION/logs" "$TS6_LOCATION/log" "$TS6_LOCATION/*/logs")
      FOUND_LOG=""
      for d in "${LOG_DIR_CANDIDATES[@]}"; do
        for path in $(eval echo $d); do
          if [ -d "$path" ]; then
            FOUND_LOG="$path"
            break 2
          fi
        done
      done

      ADMIN_TOKEN=""
      if [ -n "$FOUND_LOG" ]; then
        # Wait and tail logs for token-like lines
        timeout=60
        elapsed=0
        while [ $elapsed -lt $timeout ] && [ -z "$ADMIN_TOKEN" ]; do
          # look for common token patterns: "token", "privilege key", "admin token", "token="
          ADMIN_TOKEN=$(grep -Eoi '([A-Za-z0-9\-_]{8,})' "$FOUND_LOG"/* 2>/dev/null | grep -E '^[A-Za-z0-9\-_]{8,}$' | head -n1 || true)
          # More targeted search for lines containing token words
          if [ -z "$ADMIN_TOKEN" ]; then
            ADMIN_TOKEN=$(grep -Ei 'token|privilege key|admin token|privilege_key' "$FOUND_LOG"/* 2>/dev/null | sed -E 's/.*(token[:= ]+|privilege key[:= ]+|privilege_key[:= ]+)//I' | grep -Eo '[A-Za-z0-9\-_]{8,}' | head -n1 || true)
          fi
          if [ -z "$ADMIN_TOKEN" ]; then
            sleep 2
            elapsed=$((elapsed+2))
          fi
        done
      else
        redMessage "Could not find a log directory under $TS6_LOCATION to parse for admin token."
      fi

      if [ -n "$ADMIN_TOKEN" ]; then
        greenMessage "Captured TeamSpeak 6 admin token: $ADMIN_TOKEN"
        # Save token to a file owned by ts6 user
        echo "$ADMIN_TOKEN" > "$TS6_LOCATION/ADMIN_TOKEN.txt"
        chown "$TS6_USER:$TS6_USER" "$TS6_LOCATION/ADMIN_TOKEN.txt"
        chmod 600 "$TS6_LOCATION/ADMIN_TOKEN.txt"
      else
        redMessage "Admin token not found automatically. Check server logs in $FOUND_LOG for the privilege key or admin token."
      fi
    fi
  fi
fi

# === Systemd service for SinusBot (if systemd available) ===
if [[ "$USE_SYSTEMD" == true && ( "$INSTALL" == "Inst" || "$INSTALL" == "Updt" ) ]]; then
  if [ -f "$LOCATIONEX" ]; then
    greenMessage "Installing systemd service for SinusBot..."
    SERVICE_PATH="/etc/systemd/system/sinusbot.service"
    cat > "$SERVICE_PATH" <<EOF
[Unit]
Description=SinusBot
After=network.target

[Service]
Type=simple
User=$SINUSBOTUSER
Group=$SINUSBOTUSER
WorkingDirectory=$LOCATION
ExecStart=$LOCATIONEX
Restart=on-failure
RestartSec=5
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF
    chmod 644 "$SERVICE_PATH"
    systemctl daemon-reload
    systemctl enable sinusbot.service
    greenMessage "SinusBot systemd service installed (sinusbot.service)."
  else
    redMessage "SinusBot binary not found at $LOCATIONEX; skipping systemd service creation."
  fi
fi

# === Final messages ===
greenMessage "Installer finished."

# If TS6 admin token was captured, print it at the end (user requested token pasted in last message)
if [[ "${INSTALL_TS6:-false}" == "true" ]]; then
  if [ -n "${ADMIN_TOKEN:-}" ]; then
    echo
    magentaMessage "=== TeamSpeak 6 admin token (captured) ==="
    echo "$ADMIN_TOKEN"
    magentaMessage "Saved to: $TS6_LOCATION/ADMIN_TOKEN.txt"
    echo
  else
    yellowMessage "TeamSpeak 6 admin token was not captured automatically. Check server logs under $FOUND_LOG or $TS6_LOCATION for the privilege key."
  fi
fi

greenMessage "If you installed SinusBot, start it with: systemctl start sinusbot"
if [[ "${INSTALL_TS6:-false}" == "true" ]]; then
  greenMessage "TeamSpeak 6 server service name: ts6.service (systemctl start ts6)"
fi

exit 0
