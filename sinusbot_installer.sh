#!/bin/bash
# SinusBot installer by Philipp Eßwein - DAThosting.eu philipp.esswein@dathosting.eu
# Modified: Removed NTP/chrony/timedatectl related code per request
# Modified: Uses custom SinusBot release from GitHub (tkrlot/Tkrtest sinusbot1.1.bz2)
# Modified: Updated TeamSpeak3 client to 3.6.2 and added TeamSpeak 6 server install/auto-accept license
# Version of installer modifications: 1.5-custom-ts6

# Vars

MACHINE=$(uname -m)
Instversion="1.5-custom-ts6"

USE_SYSTEMD=true

# Functions

function greenMessage() {
  echo -e "\\033[32;1m${*}\\033[0m"
}

function magentaMessage() {
  echo -e "\\033[35;1m${*}\\033[0m"
}

function cyanMessage() {
  echo -e "\\033[36;1m${*}\\033[0m"
}

function redMessage() {
  echo -e "\\033[31;1m${*}\\033[0m"
}

function yellowMessage() {
  echo -e "\\033[33;1m${*}\\033[0m"
}

function errorQuit() {
  errorExit 'Exit now!'
}

function errorExit() {
  redMessage "${@}"
  exit 1
}

function errorContinue() {
  redMessage "Invalid option."
  return
}

function makeDir() {
  if [ -n "$1" ] && [ ! -d "$1" ]; then
    mkdir -p "$1"
  fi
}

err_report() {
  FAILED_COMMAND=$(wget -q -O - https://raw.githubusercontent.com/Sinusbot/installer-linux/master/sinusbot_installer.sh | sed -e "$1q;d")
  FAILED_COMMAND=${FAILED_COMMAND/ -qq}
  FAILED_COMMAND=${FAILED_COMMAND/ -q}
  FAILED_COMMAND=${FAILED_COMMAND/ -s}
  FAILED_COMMAND=${FAILED_COMMAND/ 2\>\/dev\/null\/}
  FAILED_COMMAND=${FAILED_COMMAND/ 2\>&1}
  FAILED_COMMAND=${FAILED_COMMAND/ \>\/dev\/null}
  if [[ "$FAILED_COMMAND" == "" ]]; then
    redMessage "Failed command: https://github.com/Sinusbot/installer-linux/blob/master/sinusbot_installer.sh#L""$1"
  else
    redMessage "Command which failed was: \"${FAILED_COMMAND}\". Please try to execute it manually and attach the output to the bug report in the forum thread."
    redMessage "If it still doesn't work report this to the author at https://forum.sinusbot.com/threads/sinusbot-installer-script.1200/ only. Not a PN or a bad review, cause this is an error of your system not of the installer script. Line $1."
  fi
  exit 1
}

trap 'err_report $LINENO' ERR

# Check if the script was run as root user. Otherwise exit the script
if [ "$(id -u)" != "0" ]; then
  errorExit "Change to root account required!"
fi

# Update notify

cyanMessage "Checking for the latest installer version"
if [[ -f /etc/centos-release ]]; then
  yum update
  yum -y -q install wget
else
  apt-get update -qq
  apt-get -qq install wget -y
fi

# Detect if systemctl is available then use systemd as start script. Otherwise use init.d
if [[ $(command -v systemctl) == "" ]]; then
  USE_SYSTEMD=false
fi

# If kernel to old, quit
if [ $(uname -r | cut -c1-1) < 3 ]; then
  errorExit "Linux kernel unsupportet. Update kernel before. Or change hardware."
fi

# If the linux distribution is not debian and centos, then exit
if [ ! -f /etc/debian_version ] && [ ! -f /etc/centos-release ]; then
  errorExit "Not supported linux distribution. Only Debian and CentOS are currently supported"!
fi

greenMessage "This is the automatic installer for latest SinusBot. USE AT YOUR OWN RISK"!
sleep 1
cyanMessage "You can choose between installing, upgrading and removing the SinusBot."
sleep 1
redMessage "Installer by Philipp Esswein | DAThosting.eu - Your game-/voiceserver hoster (only german)."
sleep 1
magentaMessage "Please rate this script at: https://forum.sinusbot.com/resources/sinusbot-installer-script.58/"
sleep 1
yellowMessage "You're using installer $Instversion"

# selection menu if the installer should install, update, remove or pw reset the SinusBot
redMessage "What should the installer do?"
OPTIONS=("Install" "Update" "Remove" "PW Reset" "Quit")
select OPTION in "${OPTIONS[@]}"; do
  case "$REPLY" in
  1 | 2 | 3 | 4) break ;;
  5) errorQuit ;;
  *) errorContinue ;;
  esac
done

if [ "$OPTION" == "Install" ]; then
  INSTALL="Inst"
elif [ "$OPTION" == "Update" ]; then
  INSTALL="Updt"
elif [ "$OPTION" == "Remove" ]; then
  INSTALL="Rem"
elif [ "$OPTION" == "PW Reset" ]; then
  INSTALL="Res"
fi

# PW Reset

if [[ $INSTALL == "Res" ]]; then
  yellowMessage "Automatic usage or own directories?"

  OPTIONS=("Automatic" "Own path" "Quit")
  select OPTION in "${OPTIONS[@]}"; do
    case "$REPLY" in
    1 | 2) break ;;
    3) errorQuit ;;
    *) errorContinue ;;
    esac
  done

  if [ "$OPTION" == "Automatic" ]; then
    LOCATION=/opt/sinusbot
  elif [ "$OPTION" == "Own path" ]; then
    yellowMessage "Enter location where the bot should be installed/updated/removed. Like /opt/sinusbot. Include the / at first position and none at the end"!

    LOCATION=""
    while [[ ! -d $LOCATION ]]; do
      read -rp "Location [/opt/sinusbot]: " LOCATION
      if [[ $INSTALL != "Inst" && ! -d $LOCATION ]]; then
        redMessage "Directory not found, try again"!
      fi
    done

    greenMessage "Your directory is $LOCATION."

    OPTIONS=("Yes" "No, change it" "Quit")
    select OPTION in "${OPTIONS[@]}"; do
      case "$REPLY" in
      1 | 2) break ;;
      3) errorQuit ;;
      *) errorContinue ;;
      esac
    done

    if [ "$OPTION" == "No, change it" ]; then
      LOCATION=""
      while [[ ! -d $LOCATION ]]; do
        read -rp "Location [/opt/sinusbot]: " LOCATION
        if [[ $INSTALL != "Inst" && ! -d $LOCATION ]]; then
          redMessage "Directory not found, try again"!
        fi
      done

      greenMessage "Your directory is $LOCATION."
    fi
  fi

  LOCATIONex=$LOCATION/sinusbot

  if [[ ! -f $LOCATION/sinusbot ]]; then
    errorExit "SinusBot wasn't found at $LOCATION. Exiting script."
  fi

  PW=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 8 | head -n 1)
  SINUSBOTUSER=$(ls -ld $LOCATION | awk '{print $3}')

  greenMessage "Please login to your SinusBot webinterface as admin and '$PW'"
  yellowMessage "After that change your password under Settings->User Accounts->admin->Edit. The script restart the bot with init.d or systemd."

  if [[ -f /lib/systemd/system/sinusbot.service ]]; then
    if [[ $(systemctl is-active sinusbot >/dev/null && echo UP || echo DOWN) == "UP" ]]; then
      service sinusbot stop
    fi
  elif [[ -f /etc/init.d/sinusbot ]]; then
    if [ "$(/etc/init.d/sinusbot status | awk '{print $NF; exit}')" == "UP" ]; then
      /etc/init.d/sinusbot stop
    fi
  fi

  log="/tmp/sinusbot.log"
  match="USER-PATCH [admin] (admin) OK"

  su -c "$LOCATIONex --override-password $PW" $SINUSBOTUSER >"$log" 2>&1 &
  sleep 3

  while true; do
    echo -ne '(Waiting for password change!)\r'

    if grep -Fq "$match" "$log"; then
      pkill -INT -f $PW
      rm $log

      greenMessage "Successfully changed your admin password."

      if [[ -f /lib/systemd/system/sinusbot.service ]]; then
        service sinusbot start
        greenMessage "Started your bot with systemd."
      elif [[ -f /etc/init.d/sinusbot ]]; then
        /etc/init.d/sinusbot start
        greenMessage "Started your bot with initd."
      else
        redMessage "Please start your bot normally"!
      fi
      exit 0
    fi
  done

fi

# Check which OS

if [ "$INSTALL" != "Rem" ]; then

  if [[ -f /etc/centos-release ]]; then
    greenMessage "Installing redhat-lsb! Please wait."
    yum -y -q install redhat-lsb
    greenMessage "Done"!

    yellowMessage "You're running CentOS. Which firewallsystem are you using?"

    OPTIONS=("IPtables" "Firewalld")
    select OPTION in "${OPTIONS[@]}"; do
      case "$REPLY" in
      1 | 2) break ;;
      *) errorContinue ;;
      esac
    done

    if [ "$OPTION" == "IPtables" ]; then
      FIREWALL="ip"
    elif [ "$OPTION" == "Firewalld" ]; then
      FIREWALL="fd"
    fi
  fi

  if [[ -f /etc/debian_version ]]; then
    greenMessage "Check if lsb-release and debconf-utils is installed..."
    apt-get -qq update
    apt-get -qq install debconf-utils -y
    apt-get -qq install lsb-release -y
    greenMessage "Done"!
  fi

  # Functions from lsb_release

  OS=$(lsb_release -i 2>/dev/null | grep 'Distributor' | awk '{print tolower($3)}')
  OSBRANCH=$(lsb_release -c 2>/dev/null | grep 'Codename' | awk '{print $2}')
  OSRELEASE=$(lsb_release -r 2>/dev/null | grep 'Release' | awk '{print $2}')
  VIRTUALIZATION_TYPE=""

  # Extracted from the virt-what sourcecode: http://git.annexia.org/?p=virt-what.git;a=blob_plain;f=virt-what.in;hb=HEAD
  if [[ -f "/.dockerinit" ]]; then
    VIRTUALIZATION_TYPE="docker"
  fi
  if [ -d "/proc/vz" -a ! -d "/proc/bc" ]; then
    VIRTUALIZATION_TYPE="openvz"
  fi

  if [[ $VIRTUALIZATION_TYPE == "openvz" ]]; then
    redMessage "Warning, your server is running OpenVZ! This very old container system isn't well supported by newer packages."
  elif [[ $VIRTUALIZATION_TYPE == "docker" ]]; then
    redMessage "Warning, your server is running Docker! Maybe there are failures while installing."
  fi

fi

# Go on

if [ "$INSTALL" != "Rem" ]; then
  if [ -z "$OS" ]; then
    errorExit "Error: Could not detect OS. Currently only Debian, Ubuntu and CentOS are supported. Aborting"!
  elif [ -z "$OS" ] && ([ "$(cat /etc/debian_version | awk '{print $1}')" == "7" ] || [ $(cat /etc/debian_version | grep "7.") ]); then
    errorExit "Debian 7 isn't supported anymore"!
  fi

  if [ -z "$OSBRANCH" ] && [ -f /etc/centos-release ]; then
    errorExit "Error: Could not detect branch of OS. Aborting"
  fi

  if [ "$MACHINE" == "x86_64" ]; then
    ARCH="amd64"
  else
    errorExit "$MACHINE is not supported"!
  fi
fi

if [[ "$INSTALL" != "Rem" ]]; then
  if [[ "$USE_SYSTEMD" == true ]]; then
    yellowMessage "Automatically chosen system.d for your startscript"!
  else
    yellowMessage "Automatically chosen init.d for your startscript"!
  fi
fi

# Set path or continue with normal

yellowMessage "Automatic usage or own directories?"

OPTIONS=("Automatic" "Own path" "Quit")
select OPTION in "${OPTIONS[@]}"; do
  case "$REPLY" in
  1 | 2) break ;;
  3) errorQuit ;;
  *) errorContinue ;;
  esac
done

if [ "$OPTION" == "Automatic" ]; then
  LOCATION=/opt/sinusbot
elif [ "$OPTION" == "Own path" ]; then
  yellowMessage "Enter location where the bot should be installed/updated/removed, e.g. /opt/sinusbot. Include the / at first position and none at the end"!
  LOCATION=""
  while [[ ! -d $LOCATION ]]; do
    read -rp "Location [/opt/sinusbot]: " LOCATION
    if [[ $INSTALL != "Inst" && ! -d $LOCATION ]]; then
      redMessage "Directory not found, try again"!
    fi
    if [ "$INSTALL" == "Inst" ]; then
      if [ "$LOCATION" == "" ]; then
        LOCATION=/opt/sinusbot
      fi
      makeDir $LOCATION
    fi
  done

  greenMessage "Your directory is $LOCATION."

  OPTIONS=("Yes" "No, change it" "Quit")
  select OPTION in "${OPTIONS[@]}"; do
    case "$REPLY" in
    1 | 2) break ;;
    3) errorQuit ;;
    *) errorContinue ;;
    esac
  done

  if [ "$OPTION" == "No, change it" ]; then
    LOCATION=""
    while [[ ! -d $LOCATION ]]; do
      read -rp "Location [/opt/sinusbot]: " LOCATION
      if [[ $INSTALL != "Inst" && ! -d $LOCATION ]]; then
        redMessage "Directory not found, try again"!
      fi
      if [ "$INSTALL" == "Inst" ]; then
        makeDir $LOCATION
      fi
    done

    greenMessage "Your directory is $LOCATION."
  fi
fi

makeDir $LOCATION

LOCATIONex=$LOCATION/sinusbot

# Check if SinusBot already installed and if update is possible

if [[ $INSTALL == "Inst" ]] || [[ $INSTALL == "Updt" ]]; then

yellowMessage "Should I install TeamSpeak or only Discord Mode?"

OPTIONS=("Both" "Only Discord" "Quit")
select OPTION in "${OPTIONS[@]}"; do
  case "$REPLY" in
  1 | 2) break ;;
  3) errorQuit ;;
  *) errorContinue ;;
  esac
done

if [ "$OPTION" == "Both" ]; then
  DISCORD="false"
else
  DISCORD="true"
fi
fi

if [[ $INSTALL == "Inst" ]]; then

  if [[ -f $LOCATION/sinusbot ]]; then
    redMessage "SinusBot already installed with automatic install option"!
    read -rp "Would you like to update the bot instead? [Y / N]: " OPTION

    if [ "$OPTION" == "Y" ] || [ "$OPTION" == "y" ] || [ "$OPTION" == "" ]; then
      INSTALL="Updt"
    elif [ "$OPTION" == "N" ] || [ "$OPTION" == "n" ]; then
      errorExit "Installer stops now"!
    fi
  else
    greenMessage "SinusBot isn't installed yet. Installer goes on."
  fi

elif [ "$INSTALL" == "Rem" ] || [ "$INSTALL" == "Updt" ]; then
  if [ ! -d $LOCATION ]; then
    errorExit "SinusBot isn't installed"!
  else
    greenMessage "SinusBot is installed. Installer goes on."
  fi
fi

# Remove SinusBot

if [ "$INSTALL" == "Rem" ]; then

  SINUSBOTUSER=$(ls -ld $LOCATION | awk '{print $3}')

  if [[ -f /usr/local/bin/youtube-dl ]]; then
    redMessage "Remove YoutubeDL?"

    OPTIONS=("Yes" "No")
    select OPTION in "${OPTIONS[@]}"; do
      case "$REPLY" in
      1 | 2) break ;;
      *) errorContinue ;;
      esac
    done

    if [ "$OPTION" == "Yes" ]; then
      if [[ -f /usr/local/bin/youtube-dl ]]; then
        rm /usr/local/bin/youtube-dl
      fi

      if [[ -f /etc/cron.d/ytdl ]]; then
        rm /etc/cron.d/ytdl
      fi

      greenMessage "Removed YT-DL successfully"!
    fi
  fi

  if [[ -z $SINUSBOTUSER ]]; then
    errorExit "No SinusBot found. Exiting now."
  fi

  redMessage "SinusBot will now be removed completely from your system"!

  greenMessage "Your SinusBot user is \"$SINUSBOTUSER\"? The directory which will be removed is \"$LOCATION\". After select Yes it could take a while."

  OPTIONS=("Yes" "No")
  select OPTION in "${OPTIONS[@]}"; do
    case "$REPLY" in
    1) break ;;
    2) errorQuit ;;
    *) errorContinue ;;
    esac
  done

  if [ "$(ps ax | grep sinusbot | grep SCREEN)" ]; then
    ps ax | grep sinusbot | grep SCREEN | awk '{print $1}' | while read PID; do
      kill $PID
    done
  fi

  if [ "$(ps ax | grep ts3bot | grep SCREEN)" ]; then
    ps ax | grep ts3bot | grep SCREEN | awk '{print $1}' | while read PID; do
      kill $PID
    done
  fi

  if [[ -f /lib/systemd/system/sinusbot.service ]]; then
    if [[ $(systemctl is-active sinusbot >/dev/null && echo UP || echo DOWN) == "UP" ]]; then
      service sinusbot stop
      systemctl disable sinusbot
    fi
    rm /lib/systemd/system/sinusbot.service
  elif [[ -f /etc/init.d/sinusbot ]]; then
    if [ "$(/etc/init.d/sinusbot status | awk '{print $NF; exit}')" == "UP" ]; then
      su -c "/etc/init.d/sinusbot stop" $SINUSBOTUSER
      su -c "screen -wipe" $SINUSBOTUSER
      update-rc.d -f sinusbot remove >/dev/null
    fi
    rm /etc/init.d/sinusbot
  fi

  if [[ -f /etc/cron.d/sinusbot ]]; then
    rm /etc/cron.d/sinusbot
  fi

  if [ "$LOCATION" ]; then
    rm -R $LOCATION >/dev/null
    greenMessage "Files removed successfully"!
  else
    redMessage "Error while removing files."
  fi

  if [[ $SINUSBOTUSER != "root" ]]; then
    redMessage "Remove user \"$SINUSBOTUSER\"? (User will be removed from your system)"

    OPTIONS=("Yes" "No")
    select OPTION in "${OPTIONS[@]}"; do
      case "$REPLY" in
      1 | 2) break ;;
      *) errorContinue ;;
      esac
    done

    if [ "$OPTION" == "Yes" ]; then
      userdel -r -f $SINUSBOTUSER >/dev/null

      if [ "$(id $SINUSBOTUSER 2>/dev/null)" == "" ]; then
        greenMessage "User removed successfully"!
      else
        redMessage "Error while removing user"!
      fi
    fi
  fi

  greenMessage "SinusBot removed completely including all directories."

  exit 0
fi

# Private usage only!

redMessage "This SinusBot version is only for private use! Accept?"

OPTIONS=("No" "Yes")
select OPTION in "${OPTIONS[@]}"; do
  case "$REPLY" in
  1) errorQuit ;;
  2) break ;;
  *) errorContinue ;;
  esac
done

# Ask for YT-DL

redMessage "Should YT-DL be installed/updated?"
OPTIONS=("Yes" "No")
select OPTION in "${OPTIONS[@]}"; do
  case "$REPLY" in
  1 | 2) break ;;
  *) errorContinue ;;
  esac
done

if [ "$OPTION" == "Yes" ]; then
  YT="Yes"
fi

# Update packages or not

redMessage 'Update the system packages to the latest version? (Recommended)'

OPTIONS=("Yes" "No")
select OPTION in "${OPTIONS[@]}"; do
  case "$REPLY" in
  1 | 2) break ;;
  *) errorContinue ;;
  esac
done

greenMessage "Starting the installer now"!
sleep 2

if [ "$OPTION" == "Yes" ]; then
  greenMessage "Updating the system in a few seconds"!
  sleep 1
  redMessage "This could take a while. Please wait up to 10 minutes"!
  sleep 3

  if [[ -f /etc/centos-release ]]; then
    yum -y -q update
    yum -y -q upgrade
  else
    apt-get -qq update
    apt-get -qq upgrade
  fi
fi

# TeamSpeak3-Client latest check
# Updated to the requested TeamSpeak 3.6.2 client URL

if [ "$DISCORD" == "false" ]; then

greenMessage "Using TS3-Client build for hardware type $MACHINE with arch $ARCH."

# User-provided TS3 client URL (updated to 3.6.2)
DOWNLOAD_URL="https://files.teamspeak-services.com/releases/client/3.6.2/TeamSpeak3-Client-linux_amd64-3.6.2.run"
VERSION="3.6.2"

# Quick check if URL is reachable
STATUS=$(wget --server-response -L --spider "$DOWNLOAD_URL" 2>&1 | awk '/^  HTTP/{print $2}' | tail -n1)
if [ "$STATUS" == "200" ]; then
  greenMessage "Detected TS3-Client version $VERSION available."
else
  yellowMessage "Warning: Could not verify TS3 client URL status (HTTP $STATUS). Will attempt download anyway."
fi

# Install necessary aptitudes for sinusbot.

magentaMessage "Installing necessary packages. Please wait..."

if [[ -f /etc/centos-release ]]; then
  yum -y -q install screen xvfb libxcursor1 ca-certificates bzip2 psmisc libglib2.0-0 less python3 iproute which dbus libnss3 libegl1-mesa x11-xkb-utils libasound2 libxcomposite-dev libxi6 libpci3 libxslt1.1 libxkbcommon0 libxss1 >/dev/null
  update-ca-trust extract >/dev/null
else
  apt-get install -y -qq --no-install-recommends libfontconfig libxtst6 screen xvfb libxcursor1 ca-certificates bzip2 psmisc libglib2.0-0 less python3 iproute2 dbus libnss3 libegl1-mesa x11-xkb-utils libasound2 libxcomposite-dev libxi6 libpci3 libxslt1.1 libxkbcommon0 libxss1
  update-ca-certificates >/dev/null
fi

else

magentaMessage "Installing necessary packages. Please wait..."

if [[ -f /etc/centos-release ]]; then
  yum -y -q install ca-certificates bzip2 python3 wget >/dev/null
  update-ca-trust extract >/dev/null
else
  apt-get -qq install ca-certificates bzip2 python3 wget -y >/dev/null
  update-ca-certificates >/dev/null
fi

fi

greenMessage "Packages installed"!

USERADD=$(which useradd)
GROUPADD=$(which groupadd)
ipaddress=$(ip route get 8.8.8.8 | awk {'print $7'} | tr -d '\n')

# Create/check user for sinusbot.

if [ "$INSTALL" == "Updt" ]; then
  SINUSBOTUSER=$(ls -ld $LOCATION | awk '{print $3}')
  if [ "$DISCORD" == "false" ]; then
    sed -i "s|TS3Path = \"\"|TS3Path = \"$LOCATION/teamspeak3-client/ts3client_linux_amd64\"|g" $LOCATION/config.ini && greenMessage "Added TS3 Path to config." || redMessage "Error while updating config"
  fi
else

  cyanMessage 'Please enter the name of the sinusbot user. Typically "sinusbot". If it does not exists, the installer will create it.'

  SINUSBOTUSER=""
  while [[ ! $SINUSBOTUSER ]]; do
    read -rp "Username [sinusbot]: " SINUSBOTUSER
    if [ -z "$SINUSBOTUSER" ]; then
      SINUSBOTUSER=sinusbot
    fi
    if [ $SINUSBOTUSER == "root" ]; then
      redMessage "Error. Your username is invalid. Don't use root"!
      SINUSBOTUSER=""
    fi
    if [ -n "$SINUSBOTUSER" ]; then
      greenMessage "Your sinusbot user is: $SINUSBOTUSER"
    fi
  done

  if [ "$(id $SINUSBOTUSER 2>/dev/null)" == "" ]; then
    if [ -d /home/$SINUSBOTUSER ]; then
      $GROUPADD $SINUSBOTUSER
      $USERADD -d /home/$SINUSBOTUSER -s /bin/bash -g $SINUSBOTUSER $SINUSBOTUSER
    else
      $GROUPADD $SINUSBOTUSER
      $USERADD -m -b /home -s /bin/bash -g $SINUSBOTUSER $SINUSBOTUSER
    fi
  else
    greenMessage "User \"$SINUSBOTUSER\" already exists."
  fi

chmod 750 -R $LOCATION
chown -R $SINUSBOTUSER:$SINUSBOTUSER $LOCATION

fi

# Create dirs or remove them.

ps -u $SINUSBOTUSER | grep ts3client | awk '{print $1}' | while read PID; do
  kill $PID
done
if [[ -f $LOCATION/ts3client_startscript.run ]]; then
  rm -rf $LOCATION/*
fi

if [ "$DISCORD" == "false" ]; then

makeDir $LOCATION/teamspeak3-client

chmod 750 -R $LOCATION
chown -R $SINUSBOTUSER:$SINUSBOTUSER $LOCATION
cd $LOCATION/teamspeak3-client

# Downloading TS3-Client files.

if [[ -f CHANGELOG ]] && [ $(cat CHANGELOG | awk '/Client Release/{ print $4; exit }') == $VERSION ]; then
  greenMessage "TS3 already latest version."
else

  greenMessage "Downloading TS3 client files."
  su -c "wget -q $DOWNLOAD_URL -O TeamSpeak3-Client-linux_$ARCH-$VERSION.run" $SINUSBOTUSER

  if [[ ! -f TeamSpeak3-Client-linux_$ARCH-$VERSION.run && ! -f ts3client_linux_$ARCH ]]; then
    errorExit "Download failed! Exiting now"!
  fi
fi

# Installing TS3-Client.

if [[ -f TeamSpeak3-Client-linux_$ARCH-$VERSION.run ]]; then
  greenMessage "Installing the TS3 client."
  redMessage "Read the eula"!
  sleep 1
  yellowMessage 'Do the following: Press "ENTER" then press "q" after that press "y" and accept it with another "ENTER".'
  sleep 2

  chmod 777 ./TeamSpeak3-Client-linux_$ARCH-$VERSION.run

  su -c "./TeamSpeak3-Client-linux_$ARCH-$VERSION.run" $SINUSBOTUSER

  cp -R ./TeamSpeak3-Client-linux_$ARCH/* ./
  sleep 2
  rm ./ts3client_runscript.sh
  rm ./TeamSpeak3-Client-linux_$ARCH-$VERSION.run
  rm -R ./TeamSpeak3-Client-linux_$ARCH

  greenMessage "TS3 client install done."
fi
fi

# Downloading latest SinusBot.

cd $LOCATION

greenMessage "Downloading custom SinusBot release."

# Custom SinusBot release URL and filename (user requested)
SINUSBOT_DOWNLOAD_URL="https://github.com/tkrlot/Tkrtest/releases/download/sinus/sinusbot1.1.bz2"
SINUSBOT_ARCHIVE="sinusbot1.1.bz2"

# Download using the chosen sinusbot user to preserve permissions
su -c "wget -q \"$SINUSBOT_DOWNLOAD_URL\" -O \"$SINUSBOT_ARCHIVE\"" $SINUSBOTUSER

if [[ ! -f $SINUSBOT_ARCHIVE && ! -f sinusbot ]]; then
  errorExit "Download failed! Exiting now"!
fi

# Installing latest SinusBot.

greenMessage "Extracting SinusBot files."

# Try to extract as tar.bz2 first (common packaging). If that fails, attempt robust fallbacks:
# 1) If archive is a tar.bz2 -> tar -xjf
# 2) If archive is a plain bzip2-compressed single file (e.g., a binary compressed with bzip2),
#    then bunzip2 to produce the binary named 'sinusbot' and set executable bit.
# 3) If bunzip2 produced a tar, extract it.
EXTRACT_OK=false

# Attempt tar extraction (tar.bz2)
if su -c "tar -xjf \"$SINUSBOT_ARCHIVE\" -C \"$LOCATION\"" $SINUSBOTUSER 2>/dev/null; then
  EXTRACT_OK=true
fi

if [ "$EXTRACT_OK" != "true" ]; then
  # Try bunzip2 to temporary file
  TMP_UNBZ="/tmp/sinusbot_unbz_$$"
  if su -c "bunzip2 -c \"$SINUSBOT_ARCHIVE\" > \"$TMP_UNBZ\"" $SINUSBOTUSER 2>/dev/null; then
    # Check if tmp file is a tar archive
    if file "$TMP_UNBZ" | grep -qi 'tar archive'; then
      if su -c "tar -xf \"$TMP_UNBZ\" -C \"$LOCATION\"" $SINUSBOTUSER 2>/dev/null; then
        EXTRACT_OK=true
        rm -f "$TMP_UNBZ"
      else
        rm -f "$TMP_UNBZ"
      fi
    else
      # Treat as single binary: move to sinusbot executable
      mv "$TMP_UNBZ" "$LOCATION/sinusbot" 2>/dev/null || su -c "mv \"$TMP_UNBZ\" \"$LOCATION/sinusbot\"" $SINUSBOTUSER 2>/dev/null
      chmod 755 "$LOCATION/sinusbot" 2>/dev/null || su -c "chmod 755 \"$LOCATION/sinusbot\"" $SINUSBOTUSER 2>/dev/null
      EXTRACT_OK=true
    fi
  fi
fi

if [ "$EXTRACT_OK" != "true" ]; then
  errorExit "Extraction failed! Exiting now"!
fi

# Remove archive after successful extraction
rm -f "$SINUSBOT_ARCHIVE"

if [ "$DISCORD" == "false" ]; then

if [ ! -d teamspeak3-client/plugins/ ]; then
  mkdir -p teamspeak3-client/plugins/
fi

# Copy the SinusBot plugin into the teamspeak clients plugin directory if present
if [[ -f $LOCATION/plugin/libsoundbot_plugin.so ]]; then
  cp $LOCATION/plugin/libsoundbot_plugin.so $LOCATION/teamspeak3-client/plugins/
fi

if [[ -f teamspeak3-client/xcbglintegrations/libqxcb-glx-integration.so ]]; then
  rm teamspeak3-client/xcbglintegrations/libqxcb-glx-integration.so
fi
fi

# Ensure main binary is executable if present
if [[ -f $LOCATION/sinusbot ]]; then
  chmod 755 $LOCATION/sinusbot
fi

if [ "$INSTALL" == "Inst" ]; then
  greenMessage "SinusBot installation done."
elif [ "$INSTALL" == "Updt" ]; then
  greenMessage "SinusBot update done."
fi

#
# TeamSpeak 6 server installation (GitHub releases)
# - Downloads latest release asset for linux_amd64 from the repository (public)
# - Installs into $LOCATION/ts6-server
# - Creates a systemd service to run it 24/7
# - Attempts to auto-accept license by setting an environment variable and creating a license file
# - After start, extracts admin token from logs/journal and writes it to $LOCATION/TS6_ADMIN_TOKEN.txt and README
#

TS6_INSTALL_DIR="$LOCATION/ts6-server"
TS6_SERVICE_NAME="ts6server"
TS6_GITHUB_REPO="TeamSpeak-Systems/ts6-server"   # adjust if upstream repo differs

function install_ts6_server() {
  if [[ -d "$TS6_INSTALL_DIR" ]]; then
    greenMessage "TS6 server directory already exists at $TS6_INSTALL_DIR. Will attempt update."
  else
    makeDir "$TS6_INSTALL_DIR"
  fi

  greenMessage "Attempting to discover latest TeamSpeak 6 server release from GitHub: $TS6_GITHUB_REPO"

  # Try to fetch latest release asset URL for linux_amd64 (best-effort)
  API_JSON=$(curl -s "https://api.github.com/repos/$TS6_GITHUB_REPO/releases/latest")
  if [[ -z "$API_JSON" ]]; then
    yellowMessage "Warning: Could not query GitHub API for latest release. Will attempt common download paths."
  fi

  # Try to find an asset with linux and amd64 in the name
  TS6_ASSET_URL=$(echo "$API_JSON" | grep -Eo '"browser_download_url":\s*"[^"]+' | sed -E 's/.*"([^"]+)$/\1/' | grep -iE 'linux.*amd64|linux.*x86_64' | head -n1)

  # Fallback common filename patterns if not found
  if [[ -z "$TS6_ASSET_URL" ]]; then
    # Common fallback: releases/latest/download/ts6-server-linux_amd64.tar.bz2
    TS6_ASSET_URL="https://github.com/$TS6_GITHUB_REPO/releases/latest/download/ts6-server-linux_amd64.tar.bz2"
    yellowMessage "Using fallback TS6 asset URL: $TS6_ASSET_URL"
  else
    greenMessage "Found TS6 asset: $TS6_ASSET_URL"
  fi

  TMP_ARCHIVE="/tmp/ts6_server_$$.tar.bz2"
  rm -f "$TMP_ARCHIVE"
  greenMessage "Downloading TeamSpeak 6 server..."
  if ! curl -sL "$TS6_ASSET_URL" -o "$TMP_ARCHIVE"; then
    yellowMessage "Warning: download attempt failed. Will try wget fallback."
    if ! wget -q -O "$TMP_ARCHIVE" "$TS6_ASSET_URL"; then
      redMessage "Failed to download TeamSpeak 6 server from $TS6_ASSET_URL"
      return 1
    fi
  fi

  # Try to extract archive (support tar.bz2 and tar.gz)
  if file "$TMP_ARCHIVE" | grep -qi 'bzip2 compressed'; then
    tar -xjf "$TMP_ARCHIVE" -C "$TS6_INSTALL_DIR" || true
  elif file "$TMP_ARCHIVE" | grep -qi 'gzip compressed'; then
    tar -xzf "$TMP_ARCHIVE" -C "$TS6_INSTALL_DIR" || true
  else
    # If it's not an archive, try to move it as a binary
    mv "$TMP_ARCHIVE" "$TS6_INSTALL_DIR/ts6-server" || true
    chmod 755 "$TS6_INSTALL_DIR/ts6-server" || true
  fi

  # Clean up
  rm -f "$TMP_ARCHIVE"

  # Ensure executable bits
  find "$TS6_INSTALL_DIR" -type f -iname "ts6*" -exec chmod a+rx {} \; 2>/dev/null || true

  # Create a simple license acceptance marker and environment variable for the service
  echo "ACCEPT_TS6_LICENSE=1" > "$TS6_INSTALL_DIR/ts6_license_accept.conf" || true
  chmod 600 "$TS6_INSTALL_DIR/ts6_license_accept.conf" || true

  # Create systemd service to run TS6 server 24/7
  if [[ "$USE_SYSTEMD" == true ]]; then
    SERVICE_PATH="/lib/systemd/system/$TS6_SERVICE_NAME.service"
    cat > "$SERVICE_PATH" <<EOF
[Unit]
Description=TeamSpeak 6 Server
After=network.target

[Service]
Type=simple
User=$SINUSBOTUSER
Group=$SINUSBOTUSER
Environment=TS6_LICENSE_ACCEPT=1
EnvironmentFile=$TS6_INSTALL_DIR/ts6_license_accept.conf
WorkingDirectory=$TS6_INSTALL_DIR
# ExecStart should point to the server binary; try common names
ExecStart=$TS6_INSTALL_DIR/ts6-server
Restart=always
RestartSec=5
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

    chmod 644 "$SERVICE_PATH"
    systemctl daemon-reload
    systemctl enable "$TS6_SERVICE_NAME.service"
    greenMessage "Installed systemd service for TeamSpeak 6 server: $TS6_SERVICE_NAME.service"
  else
    # Fallback: create a simple nohup start script that keeps it running
    START_SCRIPT="$TS6_INSTALL_DIR/start-ts6.sh"
    cat > "$START_SCRIPT" <<'EOF'
#!/bin/bash
while true; do
  ./ts6-server
  sleep 5
done
EOF
    chmod +x "$START_SCRIPT"
    greenMessage "Created start script for TS6 server at $START_SCRIPT (init.d/systemd not available)."
  fi

  # Start the server now (attempt)
  if [[ "$USE_SYSTEMD" == true ]]; then
    systemctl restart "$TS6_SERVICE_NAME.service" || systemctl start "$TS6_SERVICE_NAME.service" || true
  else
    su -c "cd $TS6_INSTALL_DIR && nohup $TS6_INSTALL_DIR/start-ts6.sh >/dev/null 2>&1 &" $SINUSBOTUSER || true
  fi

  # Wait a bit for server to initialize and try to capture admin token
  sleep 8

  # Attempt to find admin token in journal or logs
  ADMIN_TOKEN_FILE="$LOCATION/TS6_ADMIN_TOKEN.txt"
  echo "" > "$ADMIN_TOKEN_FILE"

  # Check common log locations inside install dir
  if [[ -d "$TS6_INSTALL_DIR/logs" ]]; then
    grep -Eo 'token[: ]+[A-Za-z0-9_-]+' "$TS6_INSTALL_DIR/logs"/* 2>/dev/null | head -n1 | awk '{print $2}' > "$ADMIN_TOKEN_FILE" 2>/dev/null || true
  fi

  # If not found, check journalctl for the service
  if [[ -s "$ADMIN_TOKEN_FILE" ]]; then
    greenMessage "Admin token captured from server logs."
  else
    if [[ "$USE_SYSTEMD" == true ]]; then
      journalctl -u "$TS6_SERVICE_NAME.service" -n 200 --no-pager 2>/dev/null | grep -Eo 'token[: ]+[A-Za-z0-9_-]+' | head -n1 | awk '{print $2}' > "$ADMIN_TOKEN_FILE" 2>/dev/null || true
    fi
  fi

  # If still empty, try to grep running process stdout logs (best-effort)
  if [[ ! -s "$ADMIN_TOKEN_FILE" ]]; then
    # Try to find any file containing "token" in install dir
    grep -R --binary-files=text -Eo 'token[: ]+[A-Za-z0-9_-]+' "$TS6_INSTALL_DIR" 2>/dev/null | head -n1 | awk '{print $2}' > "$ADMIN_TOKEN_FILE" 2>/dev/null || true
  fi

  if [[ -s "$ADMIN_TOKEN_FILE" ]]; then
    greenMessage "TeamSpeak 6 admin token saved to $ADMIN_TOKEN_FILE"
    # Append to README_installer.txt for convenience
    echo -e "\nTeamSpeak 6 admin token (captured at install):" >> "$LOCATION/README_installer.txt" 2>/dev/null || true
    cat "$ADMIN_TOKEN_FILE" >> "$LOCATION/README_installer.txt" 2>/dev/null || true
  else
    yellowMessage "Could not automatically capture TeamSpeak 6 admin token. It may be printed to the server console or logs. Check journalctl -u $TS6_SERVICE_NAME.service or $TS6_INSTALL_DIR/logs"
  fi

  return 0
}

# Run TS6 install if user wants TeamSpeak (not Discord-only)
if [ "$DISCORD" == "false" ]; then
  install_ts6_server || yellowMessage "TeamSpeak 6 server installation encountered issues (non-fatal)."
fi

# Continue with SinusBot startscript installation

if [[ "$USE_SYSTEMD" == true ]]; then

  greenMessage "Starting systemd installation"

  if [[ -f /etc/systemd/system/sinusbot.service ]]; then
    service sinusbot stop
    systemctl disable sinusbot
    rm /etc/systemd/system/sinusbot.service
  fi

  cd /lib/systemd/system/ || errorExit "Cannot change to /lib/systemd/system/"

  wget -q https://raw.githubusercontent.com/Sinusbot/linux-startscript/master/sinusbot.service

  if [ ! -f sinusbot.service ]; then
    errorExit "Download failed! Exiting now"!
  fi

  sed -i 's/User=YOUR_USER/User='$SINUSBOTUSER'/g' /lib/systemd/system/sinusbot.service
  sed -i 's!ExecStart=YOURPATH_TO_THE_BOT_BINARY!ExecStart='$LOCATIONex'!g' /lib/systemd/system/sinusbot.service
  sed -i 's!WorkingDirectory=YOURPATH_TO_THE_BOT_DIRECTORY!WorkingDirectory='$LOCATION'!g' /lib/systemd/system/sinusbot.service

  systemctl daemon-reload
  systemctl enable sinusbot.service

  greenMessage 'Installed systemd file to start the SinusBot with "service sinusbot {start|stop|status|restart}"'

elif [[ "$USE_SYSTEMD" == false ]]; then

  greenMessage "Starting init.d installation"

  cd /etc/init.d/ || errorExit "Cannot change to /etc/init.d/"

  wget -q https://raw.githubusercontent.com/Sinusbot/linux-startscript/obsolete-init.d/sinusbot

  if [ ! -f sinusbot ]; then
    errorExit "Download failed! Exiting now"!
  fi

  sed -i 's/USER="mybotuser"/USER="'$SINUSBOTUSER'"/g' /etc/init.d/sinusbot
  sed -i 's!DIR_ROOT="/opt/ts3soundboard/"!DIR_ROOT="'$LOCATION'/"!g' /etc/init.d/sinusbot

  chmod +x /etc/init.d/sinusbot

  if [[ -f /etc/centos-release ]]; then
    chkconfig sinusbot on >/dev/null
  else
    update-rc.d sinusbot defaults >/dev/null
  fi

  greenMessage 'Installed init.d file to start the SinusBot with "/etc/init.d/sinusbot {start|stop|status|restart|console|update|backup}"'
fi

cd $LOCATION

if [ "$INSTALL" == "Inst" ]; then
  if [ "$DISCORD" == "false" ]; then
    if [[ ! -f $LOCATION/config.ini ]]; then
      echo 'ListenPort = 8087
      ListenHost = "0.0.0.0"
      TS3Path = "'$LOCATION'/teamspeak3-client/ts3client_linux_amd64"
      YoutubeDLPath = ""' >>$LOCATION/config.ini
      greenMessage "config.ini created successfully."
    else
      redMessage "config.ini already exists or creation error"!
    fi
  else
    if [[ ! -f $LOCATION/config.ini ]]; then
      echo 'ListenPort = 8087
      ListenHost = "0.0.0.0"
      TS3Path = ""
      YoutubeDLPath = ""' >>$LOCATION/config.ini
      greenMessage "config.ini created successfully."
    else
      redMessage "config.ini already exists or creation error"!
    fi
  fi
fi

# Installing YT-DL.

if [ "$YT" == "Yes" ]; then
  greenMessage "Installing YT-Downloader now"!
  if [ -f /etc/cron.d/ytdl ] && [ "$(cat /etc/cron.d/ytdl)" == "0 0 * * * $SINUSBOTUSER youtube-dl -U --restrict-filename >/dev/null" ]; then
        rm /etc/cron.d/ytdl
        yellowMessage "Deleted old YT-DL cronjob. Generating new one in a second."
  fi
  if [[ -f /etc/cron.d/ytdl ]] && [ "$(grep -c 'youtube' /etc/cron.d/ytdl)" -ge 1 ]; then
    redMessage "Cronjob already set for YT-DL updater"!
  else
    greenMessage "Installing Cronjob for automatic YT-DL update..."
    echo "0 0 * * * $SINUSBOTUSER PATH=$PATH:/usr/local/bin; youtube-dl -U --restrict-filename >/dev/null" >>/etc/cron.d/ytdl
    greenMessage "Installing Cronjob successful."
  fi

  sed -i 's/YoutubeDLPath = \"\"/YoutubeDLPath = \"\/usr\/local\/bin\/youtube-dl\"/g' $LOCATION/config.ini

  if [[ -f /usr/local/bin/youtube-dl ]]; then
    rm /usr/local/bin/youtube-dl
  fi

  greenMessage "Downloading YT-DL now..."
  wget -q https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp -O /usr/local/bin/youtube-dl

  if [ ! -f /usr/local/bin/youtube-dl ]; then
    errorExit "Download failed! Exiting now"!
  else
    greenMessage "Download successful"!
  fi

  chmod a+rx /usr/local/bin/youtube-dl

  youtube-dl -U --restrict-filename

fi

# Creating Readme

if [ ! -a "$LOCATION/README_installer.txt" ] && [ "$USE_SYSTEMD" == true ]; then
  echo '##################################################################################
# #
# Usage: service sinusbot {start|stop|status|restart} #
# - start: start the bot #
# - stop: stop the bot #
# - status: display the status of the bot (down or up) #
# - restart: restart the bot #
# #
##################################################################################' >>$LOCATION/README_installer.txt
elif [ ! -a "$LOCATION/README_installer.txt" ] && [ "$USE_SYSTEMD" == false ]; then
  echo '##################################################################################
  # #
  # Usage: /etc/init.d/sinusbot {start|stop|status|restart|console|update|backup} #
  # - start: start the bot #
  # - stop: stop the bot #
  # - status: display the status of the bot (down or up) #
  # - restart: restart the bot #
  # - console: display the bot console #
  # - update: runs the bot updater (with start & stop)
  # - backup: archives your bot root directory
  # To exit the console without stopping the server, press CTRL + A then D. #
  # #
  ##################################################################################' >>$LOCATION/README_installer.txt
fi

# If TS6 admin token was captured earlier, append it to the final message file
if [[ -f "$LOCATION/TS6_ADMIN_TOKEN.txt" ]] && [[ -s "$LOCATION/TS6_ADMIN_TOKEN.txt" ]]; then
  greenMessage "TeamSpeak 6 admin token is available at: $LOCATION/TS6_ADMIN_TOKEN.txt"
else
  yellowMessage "TeamSpeak 6 admin token was not captured automatically. Check server logs or journalctl -u $TS6_SERVICE_NAME.service"
fi

greenMessage "Installation script finished."

# Final helpful echo: show where things are and, if available, print the admin token (single-line)
echo "---- Summary ----"
echo "SinusBot location: $LOCATION"
if [ "$DISCORD" == "false" ]; then
  echo "TeamSpeak 3 client installed at: $LOCATION/teamspeak3-client (if requested)"
  echo "TeamSpeak 6 server installed at: $TS6_INSTALL_DIR (service: $TS6_SERVICE_NAME)"
fi
if [[ -f "$LOCATION/TS6_ADMIN_TOKEN.txt" ]] && [[ -s "$LOCATION/TS6_ADMIN_TOKEN.txt" ]]; then
  echo "TeamSpeak 6 admin token (captured):"
  sed -n '1p' "$LOCATION/TS6_ADMIN_TOKEN.txt"
else
  echo "TeamSpeak 6 admin token: NOT FOUND AUTOMATICALLY. Check logs: journalctl -u $TS6_SERVICE_NAME.service or $TS6_INSTALL_DIR/logs"
fi

exit 0
