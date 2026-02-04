#!/bin/bash
# SinusBot installer by Philipp Eßwein - Modified by Copilot
# Version 1.5-custom-fixed
# Changes: Use custom SinusBot release and custom TeamSpeak client URL; various robustness and bug fixes.

set -o errexit
set -o pipefail
set -o nounset

# Vars
MACHINE=$(uname -m)
Instversion="1.5-custom-fixed"
USE_SYSTEMD=true
RETRY_WGET="--tries=3 --timeout=20 --waitretry=3 -q"

# Color helpers
greenMessage() { echo -e "\033[32;1m${*}\033[0m"; }
magentaMessage() { echo -e "\033[35;1m${*}\033[0m"; }
cyanMessage() { echo -e "\033[36;1m${*}\033[0m"; }
redMessage() { echo -e "\033[31;1m${*}\033[0m"; }
yellowMessage() { echo -e "\033[33;1m${*}\033[0m"; }

errorExit() {
  redMessage "${*}"
  exit 1
}

errorContinue() {
  redMessage "Invalid option."
  return
}

makeDir() {
  if [ -n "${1:-}" ] && [ ! -d "$1" ]; then
    mkdir -p "$1"
  fi
}

err_report() {
  local lineno="$1"
  redMessage "An error occurred on or near line ${lineno}. Please check the output above."
  exit 1
}
trap 'err_report $LINENO' ERR

# Ensure root
if [ "$(id -u)" != "0" ]; then
  errorExit "Change to root account required!"
fi

# Basic package tools present
if ! command -v wget >/dev/null 2>&1 && ! command -v curl >/dev/null 2>&1; then
  errorExit "wget or curl is required. Please install one of them and re-run."
fi

cyanMessage "Checking for the latest installer version"

if [[ -f /etc/centos-release ]]; then
  yum -y -q install wget || true
else
  apt-get update -qq || true
  apt-get -qq install wget -y || true
fi

# Detect systemd
if ! command -v systemctl >/dev/null 2>&1; then
  USE_SYSTEMD=false
fi

# Kernel check: require major kernel >= 3
KERNEL_MAJOR=$(uname -r | cut -d. -f1)
if ! [[ "$KERNEL_MAJOR" =~ ^[0-9]+$ ]] || [ "$KERNEL_MAJOR" -lt 3 ]; then
  errorExit "Linux kernel unsupported. Update kernel before. Or change hardware."
fi

# Supported distributions check
if [ ! -f /etc/debian_version ] && [ ! -f /etc/centos-release ]; then
  errorExit "Not supported linux distribution. Only Debian/Ubuntu and CentOS are supported."
fi

greenMessage "This is the automatic installer for latest SinusBot. USE AT YOUR OWN RISK"
sleep 1
cyanMessage "You can choose between installing, upgrading and removing the SinusBot."
sleep 1
redMessage "Installer by Philipp Esswein | DAThosting.eu"
sleep 1
magentaMessage "Please rate this script at: https://forum.sinusbot.com/resources/sinusbot-installer-script.58/"
sleep 1
yellowMessage "You're using installer $Instversion"

# selection menu
redMessage "What should the installer do?"
OPTIONS=("Install" "Update" "Remove" "PW Reset" "Quit")
select OPTION in "${OPTIONS[@]}"; do
  case "$REPLY" in
    1|2|3|4) break ;;
    5) errorExit "Exit now!" ;;
    *) errorContinue ;;
  esac
done

case "$OPTION" in
  "Install") INSTALL="Inst" ;;
  "Update")  INSTALL="Updt" ;;
  "Remove")  INSTALL="Rem" ;;
  "PW Reset") INSTALL="Res" ;;
  *) errorExit "Unknown option" ;;
esac

# PW Reset
if [[ $INSTALL == "Res" ]]; then
  yellowMessage "Automatic usage or own directories?"
  OPTIONS=("Automatic" "Own path" "Quit")
  select OPTION in "${OPTIONS[@]}"; do
    case "$REPLY" in
      1|2) break ;;
      3) errorExit "Exit now!" ;;
      *) errorContinue ;;
    esac
  done

  if [ "$OPTION" == "Automatic" ]; then
    LOCATION=/opt/sinusbot
  else
    LOCATION=""
    while [[ ! -d $LOCATION ]]; do
      read -rp "Location [/opt/sinusbot]: " LOCATION
      LOCATION=${LOCATION:-/opt/sinusbot}
      if [[ ! -d $LOCATION ]]; then
        redMessage "Directory not found, try again"
      fi
    done
  fi

  LOCATIONex=$LOCATION/sinusbot

  if [[ ! -f $LOCATION/sinusbot ]]; then
    errorExit "SinusBot wasn't found at $LOCATION. Exiting script."
  fi

  PW=$(tr -dc 'a-zA-Z0-9' </dev/urandom | fold -w 12 | head -n 1)
  SINUSBOTUSER=$(ls -ld "$LOCATION" | awk '{print $3}')

  greenMessage "Please login to your SinusBot webinterface as admin and use password: $PW"
  yellowMessage "After that change your password under Settings->User Accounts->admin->Edit."

  # Stop service if running
  if [[ -f /lib/systemd/system/sinusbot.service || -f /etc/systemd/system/sinusbot.service ]]; then
    if systemctl is-active --quiet sinusbot; then
      systemctl stop sinusbot || true
    fi
  elif [[ -f /etc/init.d/sinusbot ]]; then
    if /etc/init.d/sinusbot status >/dev/null 2>&1; then
      /etc/init.d/sinusbot stop || true
    fi
  fi

  log="/tmp/sinusbot.log.$$"
  match="USER-PATCH [admin] (admin) OK"

  su -s /bin/bash -c "\"$LOCATIONex\" --override-password \"$PW\" >\"$log\" 2>&1 &" "$SINUSBOTUSER" || true
  sleep 3

  while true; do
    echo -ne '(Waiting for password change!)\r'
    if [ -f "$log" ] && grep -Fq "$match" "$log"; then
      pkill -f "$LOCATIONex" || true
      rm -f "$log"
      greenMessage "Successfully changed your admin password."
      if systemctl list-unit-files | grep -q sinusbot; then
        systemctl start sinusbot || true
        greenMessage "Started your bot with systemd."
      elif [[ -f /etc/init.d/sinusbot ]]; then
        /etc/init.d/sinusbot start || true
        greenMessage "Started your bot with initd."
      else
        redMessage "Please start your bot manually."
      fi
      exit 0
    fi
    sleep 1
  done
fi

# OS specific preps
if [ "$INSTALL" != "Rem" ]; then
  if [[ -f /etc/centos-release ]]; then
    greenMessage "Installing redhat-lsb"
    yum -y -q install redhat-lsb || true
    greenMessage "Done"
    yellowMessage "You're running CentOS. Which firewall system are you using?"
    OPTIONS=("IPtables" "Firewalld")
    select OPTION in "${OPTIONS[@]}"; do
      case "$REPLY" in
        1|2) break ;;
        *) errorContinue ;;
      esac
    done
    FIREWALL=$([ "$OPTION" == "IPtables" ] && echo "ip" || echo "fd")
  fi

  if [[ -f /etc/debian_version ]]; then
    greenMessage "Check if lsb-release and debconf-utils are installed"
    apt-get -qq update || true
    apt-get -qq install debconf-utils lsb-release -y || true
    greenMessage "Done"
  fi

  # Functions from lsb_release
  OS=$(lsb_release -i 2>/dev/null | awk -F: '{print tolower($2)}' | xargs || true)
  OSBRANCH=$(lsb_release -c 2>/dev/null | awk -F: '{print $2}' | xargs || true)
  OSRELEASE=$(lsb_release -r 2>/dev/null | awk -F: '{print $2}' | xargs || true)
  VIRTUALIZATION_TYPE=""

  # detect docker/openvz
  if [[ -f "/.dockerenv" || -f "/.dockerinit" ]]; then
    VIRTUALIZATION_TYPE="docker"
  fi
  if [ -d "/proc/vz" ] && [ ! -d "/proc/bc" ]; then
    VIRTUALIZATION_TYPE="openvz"
  fi

  if [[ $VIRTUALIZATION_TYPE == "openvz" ]]; then
    redMessage "Warning, your server is running OpenVZ. Some packages may not be supported."
  elif [[ $VIRTUALIZATION_TYPE == "docker" ]]; then
    redMessage "Warning, your server is running Docker. There may be failures while installing."
  fi
fi

# More checks
if [ "$INSTALL" != "Rem" ]; then
  if [ -z "$OS" ]; then
    errorExit "Error: Could not detect OS. Currently only Debian/Ubuntu and CentOS are supported."
  fi

  if [ "$MACHINE" == "x86_64" ]; then
    ARCH="amd64"
  else
    errorExit "$MACHINE is not supported"
  fi
fi

if [[ "$INSTALL" != "Rem" ]]; then
  if [[ "$USE_SYSTEMD" == true ]]; then
    yellowMessage "Automatically chosen systemd for your startscript"
  else
    yellowMessage "Automatically chosen init.d for your startscript"
  fi
fi

# Choose installation path
yellowMessage "Automatic usage or own directories?"
OPTIONS=("Automatic" "Own path" "Quit")
select OPTION in "${OPTIONS[@]}"; do
  case "$REPLY" in
    1|2) break ;;
    3) errorExit "Exit now!" ;;
    *) errorContinue ;;
  esac
done

if [ "$OPTION" == "Automatic" ]; then
  LOCATION=/opt/sinusbot
else
  LOCATION=""
  while [[ ! -d $LOCATION ]]; do
    read -rp "Location [/opt/sinusbot]: " LOCATION
    LOCATION=${LOCATION:-/opt/sinusbot}
    if [[ $INSTALL != "Inst" && ! -d $LOCATION ]]; then
      redMessage "Directory not found, try again"
    fi
    if [ "$INSTALL" == "Inst" ]; then
      makeDir "$LOCATION"
    fi
  done
fi

makeDir "$LOCATION"
LOCATIONex="$LOCATION/sinusbot"

# If installing or updating, ask for Discord/TS mode
if [[ $INSTALL == "Inst" || $INSTALL == "Updt" ]]; then
  yellowMessage "Should I install TeamSpeak or only Discord Mode?"
  OPTIONS=("Both" "Only Discord" "Quit")
  select OPTION in "${OPTIONS[@]}"; do
    case "$REPLY" in
      1|2) break ;;
      3) errorExit "Exit now!" ;;
      *) errorContinue ;;
    esac
  done
  DISCORD=$([ "$OPTION" == "Both" ] && echo "false" || echo "true")
fi

# If install and already present
if [[ $INSTALL == "Inst" ]]; then
  if [[ -f $LOCATION/sinusbot ]]; then
    redMessage "SinusBot already installed at $LOCATION"
    read -rp "Would you like to update the bot instead? [Y / N]: " OPTION
    OPTION=${OPTION:-Y}
    if [[ "$OPTION" =~ ^[Yy]$ ]]; then
      INSTALL="Updt"
    else
      errorExit "Installer stops now"
    fi
  else
    greenMessage "SinusBot isn't installed yet. Installer goes on."
  fi
elif [[ $INSTALL == "Rem" || $INSTALL == "Updt" ]]; then
  if [ ! -d "$LOCATION" ]; then
    errorExit "SinusBot isn't installed at $LOCATION"
  else
    greenMessage "SinusBot is installed. Installer goes on."
  fi
fi

# Remove SinusBot
if [ "$INSTALL" == "Rem" ]; then
  SINUSBOTUSER=$(ls -ld "$LOCATION" | awk '{print $3}')
  if [[ -f /usr/local/bin/youtube-dl || -f /usr/local/bin/yt-dlp ]]; then
    redMessage "Remove YoutubeDL/yt-dlp?"
    OPTIONS=("Yes" "No")
    select OPTION in "${OPTIONS[@]}"; do
      case "$REPLY" in
        1|2) break ;;
        *) errorContinue ;;
      esac
    done
    if [ "$OPTION" == "Yes" ]; then
      rm -f /usr/local/bin/youtube-dl /usr/local/bin/yt-dlp || true
      rm -f /etc/cron.d/ytdl || true
      greenMessage "Removed YT-DL/yt-dlp successfully"
    fi
  fi

  if [[ -z "$SINUSBOTUSER" ]]; then
    errorExit "No SinusBot found. Exiting now."
  fi

  redMessage "SinusBot will now be removed completely from your system"
  greenMessage "Your SinusBot user is \"$SINUSBOTUSER\". The directory which will be removed is \"$LOCATION\"."

  OPTIONS=("Yes" "No")
  select OPTION in "${OPTIONS[@]}"; do
    case "$REPLY" in
      1) break ;;
      2) errorExit "Aborted by user" ;;
      *) errorContinue ;;
    esac
  done

  # Kill running processes
  pkill -f sinusbot || true
  pkill -f ts3client || true

  # Remove service files
  if systemctl list-unit-files | grep -q sinusbot; then
    systemctl stop sinusbot || true
    systemctl disable sinusbot || true
    rm -f /etc/systemd/system/sinusbot.service /lib/systemd/system/sinusbot.service || true
    systemctl daemon-reload || true
  elif [[ -f /etc/init.d/sinusbot ]]; then
    /etc/init.d/sinusbot stop || true
    update-rc.d -f sinusbot remove >/dev/null 2>&1 || true
    rm -f /etc/init.d/sinusbot || true
  fi

  rm -f /etc/cron.d/sinusbot || true
  rm -rf "$LOCATION" || true
  greenMessage "Files removed successfully"

  if [[ "$SINUSBOTUSER" != "root" ]]; then
    redMessage "Remove user \"$SINUSBOTUSER\"? (User will be removed from your system)"
    OPTIONS=("Yes" "No")
    select OPTION in "${OPTIONS[@]}"; do
      case "$REPLY" in
        1|2) break ;;
        *) errorContinue ;;
      esac
    done
    if [ "$OPTION" == "Yes" ]; then
      userdel -r -f "$SINUSBOTUSER" >/dev/null 2>&1 || true
      if ! id "$SINUSBOTUSER" >/dev/null 2>&1; then
        greenMessage "User removed successfully"
      else
        redMessage "Error while removing user"
      fi
    fi
  fi

  greenMessage "SinusBot removed completely including all directories."
  exit 0
fi

# Private usage acceptance
redMessage "This SinusBot version is only for private use. Accept?"
OPTIONS=("No" "Yes")
select OPTION in "${OPTIONS[@]}"; do
  case "$REPLY" in
    1) errorExit "Exit now!" ;;
    2) break ;;
    *) errorContinue ;;
  esac
done

# Ask for YT-DL
redMessage "Should YT-DL/yt-dlp be installed/updated?"
OPTIONS=("Yes" "No")
select OPTION in "${OPTIONS[@]}"; do
  case "$REPLY" in
    1|2) break ;;
    *) errorContinue ;;
  esac
done
YT=$([ "$OPTION" == "Yes" ] && echo "Yes" || echo "No")

# Update packages prompt
redMessage "Update the system packages to the latest version? (Recommended)"
OPTIONS=("Yes" "No")
select OPTION in "${OPTIONS[@]}"; do
  case "$REPLY" in
    1|2) break ;;
    *) errorContinue ;;
  esac
done
UPDATE_SYS=$([ "$OPTION" == "Yes" ] && echo "Yes" || echo "No")

greenMessage "Starting the installer now"
sleep 2

if [ "$UPDATE_SYS" == "Yes" ]; then
  greenMessage "Updating the system in a few seconds"
  sleep 1
  redMessage "This could take a while. Please wait up to 10 minutes"
  sleep 3
  if [[ -f /etc/centos-release ]]; then
    yum -y -q update || true
    yum -y -q upgrade || true
  else
    apt-get -qq update || true
    apt-get -qq upgrade -y || true
  fi
fi

# TeamSpeak3-Client latest check and download
if [ "${DISCORD:-false}" == "false" ]; then
  greenMessage "Preparing TeamSpeak client for hardware type $MACHINE with arch $ARCH."

  # Use the user-provided TeamSpeak client URL (requested)
  TS_DOWNLOAD_URL="https://github.com/tkrlot/Tkrtest/releases/download/sinus/TeamSpeak3-Client-linux_amd64-3.5.6.run"
  TS_RUNFILE="TeamSpeak3-Client-linux_${ARCH}-3.5.6.run"

  makeDir "$LOCATION/teamspeak3-client"
  chmod 750 -R "$LOCATION"
  chown -R "${SINUSBOTUSER:-root}:${SINUSBOTUSER:-root}" "$LOCATION" || true
  cd "$LOCATION/teamspeak3-client" || true

  greenMessage "Downloading TeamSpeak client files."
  if command -v wget >/dev/null 2>&1; then
    su -s /bin/bash -c "wget $RETRY_WGET -O \"$TS_RUNFILE\" \"$TS_DOWNLOAD_URL\"" "${SINUSBOTUSER:-root}"
  else
    su -s /bin/bash -c "curl -fsSL \"$TS_DOWNLOAD_URL\" -o \"$TS_RUNFILE\"" "${SINUSBOTUSER:-root}"
  fi

  if [[ ! -f "$TS_RUNFILE" ]]; then
    errorExit "TeamSpeak client download failed! Exiting now"
  fi

  # Make executable and run installer non-interactively if possible
  chmod +x "$TS_RUNFILE"
  greenMessage "Installing the TS3 client. You may be prompted to accept the EULA interactively."
  su -s /bin/bash -c "./$TS_RUNFILE" "${SINUSBOTUSER:-root}" || true

  # Move extracted files into place if installer created a directory
  if [ -d TeamSpeak3-Client-linux_${ARCH} ]; then
    cp -R TeamSpeak3-Client-linux_${ARCH}/* . || true
    rm -f ts3client_runscript.sh || true
    rm -f "$TS_RUNFILE" || true
    rm -rf TeamSpeak3-Client-linux_${ARCH} || true
  fi
  greenMessage "TS3 client install done."
fi

# Install necessary packages for sinusbot
magentaMessage "Installing necessary packages. Please wait..."
if [[ -f /etc/centos-release ]]; then
  yum -y -q install screen xvfb libxcursor libX11 ca-certificates bzip2 psmisc glibc less python3 iproute which dbus nss libegl mesa-libEGL alsa-lib libXcomposite libXi libpciaccess libxslt libxkbcommon libXScrnSaver >/dev/null || true
  update-ca-trust extract >/dev/null || true
else
  apt-get install -y -qq --no-install-recommends libfontconfig libxtst6 screen xvfb libxcursor1 ca-certificates bzip2 psmisc libglib2.0-0 less python3 iproute2 dbus libnss3 libegl1-mesa x11-xkb-utils libasound2 libxcomposite1 libxi6 libpci3 libxslt1.1 libxkbcommon0 libxss1 >/dev/null || true
  update-ca-certificates >/dev/null || true
fi
greenMessage "Packages installed"

USERADD=$(command -v useradd || true)
GROUPADD=$(command -v groupadd || true)
ipaddress=$(ip route get 8.8.8.8 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="src"){print $(i+1); exit}}' || true)

# Create/check user for sinusbot
if [ "$INSTALL" == "Updt" ]; then
  SINUSBOTUSER=$(ls -ld "$LOCATION" | awk '{print $3}')
  if [ "${DISCORD:-false}" == "false" ] && [ -f "$LOCATION/config.ini" ]; then
    sed -i "s|TS3Path = \"\"|TS3Path = \"$LOCATION/teamspeak3-client/ts3client_linux_amd64\"|g" "$LOCATION/config.ini" && greenMessage "Added TS3 Path to config." || redMessage "Error while updating config"
  fi
else
  cyanMessage 'Please enter the name of the sinusbot user. Typically "sinusbot". If it does not exist, the installer will create it.'
  SINUSBOTUSER=""
  while [[ -z "$SINUSBOTUSER" ]]; do
    read -rp "Username [sinusbot]: " SINUSBOTUSER
    SINUSBOTUSER=${SINUSBOTUSER:-sinusbot}
    if [ "$SINUSBOTUSER" == "root" ]; then
      redMessage "Error. Your username is invalid. Don't use root"
      SINUSBOTUSER=""
    else
      greenMessage "Your sinusbot user is: $SINUSBOTUSER"
    fi
  done

  if ! id "$SINUSBOTUSER" >/dev/null 2>&1; then
    if [ -d "/home/$SINUSBOTUSER" ]; then
      $GROUPADD "$SINUSBOTUSER" || true
      $USERADD -d "/home/$SINUSBOTUSER" -s /bin/bash -g "$SINUSBOTUSER" "$SINUSBOTUSER" || true
    else
      $GROUPADD "$SINUSBOTUSER" || true
      $USERADD -m -b /home -s /bin/bash -g "$SINUSBOTUSER" "$SINUSBOTUSER" || true
    fi
  else
    greenMessage "User \"$SINUSBOTUSER\" already exists."
  fi

  chmod 750 -R "$LOCATION" || true
  chown -R "$SINUSBOTUSER:$SINUSBOTUSER" "$LOCATION" || true
fi

# Stop any running ts3client processes for the user
if id "${SINUSBOTUSER:-}" >/dev/null 2>&1; then
  pkill -u "$SINUSBOTUSER" -f ts3client || true
fi

# Clean previous runscript if present
if [[ -f "$LOCATION/ts3client_startscript.run" ]]; then
  rm -rf "$LOCATION"/* || true
fi

# Prepare teamspeak plugin dir
if [ "${DISCORD:-false}" == "false" ]; then
  makeDir "$LOCATION/teamspeak3-client/plugins"
  chmod 750 -R "$LOCATION" || true
  chown -R "${SINUSBOTUSER:-root}:${SINUSBOTUSER:-root}" "$LOCATION" || true
fi

# Downloading latest SinusBot
cd "$LOCATION" || true
greenMessage "Downloading custom SinusBot release."

SINUSBOT_DOWNLOAD_URL="https://github.com/tkrlot/Tkrtest/releases/download/sinus/sinusbot1.1.bz2"
SINUSBOT_ARCHIVE="sinusbot1.1.bz2"

if command -v wget >/dev/null 2>&1; then
  su -s /bin/bash -c "wget $RETRY_WGET -O \"$SINUSBOT_ARCHIVE\" \"$SINUSBOT_DOWNLOAD_URL\"" "${SINUSBOTUSER:-root}"
else
  su -s /bin/bash -c "curl -fsSL \"$SINUSBOT_DOWNLOAD_URL\" -o \"$SINUSBOT_ARCHIVE\"" "${SINUSBOTUSER:-root}"
fi

if [[ ! -f "$SINUSBOT_ARCHIVE" && ! -f sinusbot ]]; then
  errorExit "Download failed! Exiting now"
fi

greenMessage "Extracting SinusBot files."

EXTRACT_OK=false

# Try tar extraction
if su -s /bin/bash -c "tar -xjf \"$SINUSBOT_ARCHIVE\" -C \"$LOCATION\"" "${SINUSBOTUSER:-root}" 2>/dev/null; then
  EXTRACT_OK=true
fi

if [ "$EXTRACT_OK" != "true" ]; then
  TMP_UNBZ="/tmp/sinusbot_unbz_$$"
  if su -s /bin/bash -c "bunzip2 -c \"$SINUSBOT_ARCHIVE\" > \"$TMP_UNBZ\"" "${SINUSBOTUSER:-root}" 2>/dev/null; then
    if file "$TMP_UNBZ" | grep -qi 'tar archive'; then
      if su -s /bin/bash -c "tar -xf \"$TMP_UNBZ\" -C \"$LOCATION\"" "${SINUSBOTUSER:-root}" 2>/dev/null; then
        EXTRACT_OK=true
        rm -f "$TMP_UNBZ"
      else
        rm -f "$TMP_UNBZ"
      fi
    else
      # treat as single binary
      mv "$TMP_UNBZ" "$LOCATION/sinusbot" 2>/dev/null || su -s /bin/bash -c "mv \"$TMP_UNBZ\" \"$LOCATION/sinusbot\"" "${SINUSBOTUSER:-root}" 2>/dev/null
      chmod 755 "$LOCATION/sinusbot" 2>/dev/null || su -s /bin/bash -c "chmod 755 \"$LOCATION/sinusbot\"" "${SINUSBOTUSER:-root}" 2>/dev/null
      EXTRACT_OK=true
    fi
  fi
fi

if [ "$EXTRACT_OK" != "true" ]; then
  errorExit "Extraction failed! Exiting now"
fi

rm -f "$SINUSBOT_ARCHIVE" || true

# Copy plugin into teamspeak client plugin dir if present
if [ "${DISCORD:-false}" == "false" ]; then
  if [[ -f "$LOCATION/plugin/libsoundbot_plugin.so" ]]; then
    cp -f "$LOCATION/plugin/libsoundbot_plugin.so" "$LOCATION/teamspeak3-client/plugins/" || true
  fi
  if [[ -f "$LOCATION/teamspeak3-client/xcbglintegrations/libqxcb-glx-integration.so" ]]; then
    rm -f "$LOCATION/teamspeak3-client/xcbglintegrations/libqxcb-glx-integration.so" || true
  fi
fi

# Ensure main binary is executable
if [[ -f "$LOCATION/sinusbot" ]]; then
  chmod 755 "$LOCATION/sinusbot" || true
fi

if [ "$INSTALL" == "Inst" ]; then
  greenMessage "SinusBot installation done."
elif [ "$INSTALL" == "Updt" ]; then
  greenMessage "SinusBot update done."
fi

# Install start script
if [[ "$USE_SYSTEMD" == true ]]; then
  greenMessage "Starting systemd installation"
  # prefer /etc/systemd/system for local admin edits
  SD_PATH="/etc/systemd/system/sinusbot.service"
  if systemctl list-unit-files | grep -q sinusbot; then
    systemctl stop sinusbot || true
    systemctl disable sinusbot || true
    rm -f "$SD_PATH" || true
  fi

  cd /etc/systemd/system || true
  if command -v wget >/dev/null 2>&1; then
    wget $RETRY_WGET -O sinusbot.service "https://raw.githubusercontent.com/Sinusbot/linux-startscript/master/sinusbot.service"
  else
    curl -fsSL "https://raw.githubusercontent.com/Sinusbot/linux-startscript/master/sinusbot.service" -o sinusbot.service
  fi

  if [ ! -f sinusbot.service ]; then
    errorExit "Download failed! Exiting now"
  fi

  sed -i "s/User=YOUR_USER/User=${SINUSBOTUSER}/g" sinusbot.service
  sed -i "s!ExecStart=YOURPATH_TO_THE_BOT_BINARY!ExecStart=${LOCATIONex}!g" sinusbot.service
  sed -i "s!WorkingDirectory=YOURPATH_TO_THE_BOT_DIRECTORY!WorkingDirectory=${LOCATION}!g" sinusbot.service

  systemctl daemon-reload || true
  systemctl enable sinusbot || true

  greenMessage 'Installed systemd file to start the SinusBot with "service sinusbot {start|stop|status|restart}"'
else
  greenMessage "Starting init.d installation"
  cd /etc/init.d || true
  if command -v wget >/dev/null 2>&1; then
    wget $RETRY_WGET -O sinusbot "https://raw.githubusercontent.com/Sinusbot/linux-startscript/obsolete-init.d/sinusbot"
  else
    curl -fsSL "https://raw.githubusercontent.com/Sinusbot/linux-startscript/obsolete-init.d/sinusbot" -o sinusbot
  fi

  if [ ! -f sinusbot ]; then
    errorExit "Download failed! Exiting now"
  fi

  sed -i "s/USER=\"mybotuser\"/USER=\"${SINUSBOTUSER}\"/g" /etc/init.d/sinusbot
  sed -i "s!DIR_ROOT=\"/opt/ts3soundboard/\"!DIR_ROOT=\"${LOCATION}/\"!g" /etc/init.d/sinusbot

  chmod +x /etc/init.d/sinusbot
  if [[ -f /etc/centos-release ]]; then
    chkconfig sinusbot on >/dev/null 2>&1 || true
  else
    update-rc.d sinusbot defaults >/dev/null 2>&1 || true
  fi

  greenMessage 'Installed init.d file to start the SinusBot with "/etc/init.d/sinusbot {start|stop|status|restart|console|update|backup}"'
fi

cd "$LOCATION" || true

# Create config.ini if missing
if [ "$INSTALL" == "Inst" ]; then
  if [ "${DISCORD:-false}" == "false" ]; then
    if [ ! -f "$LOCATION/config.ini" ]; then
      cat > "$LOCATION/config.ini" <<EOF
ListenPort = 8087
ListenHost = "0.0.0.0"
TS3Path = "${LOCATION}/teamspeak3-client/ts3client_linux_amd64"
YoutubeDLPath = ""
EOF
      greenMessage "config.ini created successfully."
    else
      redMessage "config.ini already exists or creation error"
    fi
  else
    if [ ! -f "$LOCATION/config.ini" ]; then
      cat > "$LOCATION/config.ini" <<EOF
ListenPort = 8087
ListenHost = "0.0.0.0"
TS3Path = ""
YoutubeDLPath = ""
EOF
      greenMessage "config.ini created successfully."
    else
      redMessage "config.ini already exists or creation error"
    fi
  fi
fi

# Installing YT-DL / yt-dlp
if [ "$YT" == "Yes" ]; then
  greenMessage "Installing yt-dlp now"
  if [ -f /etc/cron.d/ytdl ] && grep -q 'youtube' /etc/cron.d/ytdl; then
    redMessage "Cronjob already set for YT-DL updater"
  else
    greenMessage "Installing Cronjob for automatic yt-dlp update..."
    echo "0 0 * * * ${SINUSBOTUSER} PATH=\$PATH:/usr/local/bin; yt-dlp -U --restrict-filenames >/dev/null 2>&1" > /etc/cron.d/ytdl
    greenMessage "Installing Cronjob successful."
  fi

  sed -i 's|YoutubeDLPath = ""|YoutubeDLPath = "/usr/local/bin/yt-dlp"|g' "$LOCATION/config.ini" || true

  rm -f /usr/local/bin/yt-dlp /usr/local/bin/youtube-dl || true
  greenMessage "Downloading yt-dlp now..."
  if command -v wget >/dev/null 2>&1; then
    wget $RETRY_WGET -O /usr/local/bin/yt-dlp "https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp"
  else
    curl -fsSL "https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp" -o /usr/local/bin/yt-dlp
  fi

  if [ ! -f /usr/local/bin/yt-dlp ]; then
    errorExit "Download failed! Exiting now"
  fi

  chmod a+rx /usr/local/bin/yt-dlp
  /usr/local/bin/yt-dlp -U --restrict-filenames || true
  greenMessage "yt-dlp installed and updated"
fi

# Creating Readme
if [ ! -e "$LOCATION/README_installer.txt" ]; then
  if [[ "$USE_SYSTEMD" == true ]]; then
    cat > "$LOCATION/README_installer.txt" <<'EOF'
##################################################################################
#
# Usage: service sinusbot {start|stop|status|restart}
# - start: start the bot
# - stop: stop the bot
# - status: display the status of the bot (down or up)
# - restart: restart the bot
#
##################################################################################
EOF
  else
    cat > "$LOCATION/README_installer.txt" <<'EOF'
##################################################################################
#
# Usage: /etc/init.d/sinusbot {start|stop|status|restart|console|update|backup}
# - start: start the bot
# - stop: stop the bot
# - status: display the status of the bot (down or up)
# - restart: restart the bot
# - console: display the bot console
# - update: runs the bot updater (with start & stop)
# - backup: archives your bot root directory
# To exit the console without stopping the server, press CTRL + A then D.
#
##################################################################################
EOF
  fi
fi

greenMessage "Installation finished. Start the bot with: service sinusbot start"
