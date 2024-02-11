#!/usr/bin/env bash
set -euo pipefail

# Arch Linux setup for Umbrel installation script

# Default options
PRINT_DOCKER_WARNING="true"
INSTALL_PARU="true"
INSTALL_YAY_DEPS="true"
INSTALL_AVAHI="true"
INSTALL_YQ="true"
INSTALL_FSWATCH="true"
INSTALL_DOCKER="true"
INSTALL_DOCKER_COMPOSE="true"
INSTALL_START_SCRIPT="true"
INSTALL_UMBREL="true"
AUTO_START_UMBREL="true"
UMBREL_VERSION="release"
UMBREL_REPO="getumbrel/umbrel"
UMBREL_INSTALL_PATH="$HOME/umbrel"

# Parse arguments
for arg in "$@"; do
  case $arg in
    --no-docker-warning)
      PRINT_DOCKER_WARNING="false"
      shift
      ;;
    --no-install-avahi)
      INSTALL_AVAHI="false"
      shift
      ;;
    --no-install-yq)
      INSTALL_YQ="false"
      shift
      ;;
    --no-install-fswatch)
      INSTALL_FSWATCH="false"
      shift
      ;;
    --no-install-docker)
      INSTALL_DOCKER="false"
      shift
      ;;
    --no-install-compose)
      INSTALL_DOCKER_COMPOSE="false"
      shift
      ;;
    --no-install-start-script)
      INSTALL_START_SCRIPT="false"
      shift
      ;;
    --no-install-umbrel)
      INSTALL_UMBREL="false"
      shift
      ;;
    --no-auto-start-umbrel)
      AUTO_START_UMBREL="false"
      shift
      ;;
    --no-install-deps)
      INSTALL_PARU="false"
      INSTALL_YAY_DEPS="false"
      INSTALL_AVAHI="false"
      INSTALL_YQ="false"
      INSTALL_FSWATCH="false"
      INSTALL_DOCKER="false"
      INSTALL_DOCKER_COMPOSE="false"
      INSTALL_UMBREL="true"
      shift
      ;;
    --version=*)
      UMBREL_VERSION="${arg#*=}"
      shift
      ;;
    --install-path=*)
      UMBREL_INSTALL_PATH="${arg#*=}"
      shift
      ;;
    *)
      ;;
  esac
done

# Function to detect AUR helper (yay or paru)
detect_aur_helper() {
  if command -v paru > /dev/null; then
    echo "paru"
  elif command -v yay > /dev/null; then
    echo "yay"
  else
    echo ""
  fi
}

# Install Paru if neither yay nor paru is installed
ensure_aur_helper() {
  AUR_HELPER=$(detect_aur_helper)
  if [[ -z "$AUR_HELPER" && "$INSTALL_PARU" == "true" ]]; then
    read -p "Neither yay nor paru is installed. Would you like to install paru? [Y/n] " response
    if [[ "$response" =~ ^([yY][eE][sS]|[yY]|"")$ ]]; then
      install_paru
      AUR_HELPER="paru"
    else
      echo "Error: AUR helper (yay or paru) is required."
      exit 1
    fi
  elif [[ -z "$AUR_HELPER" ]]; then
    echo "Error: AUR helper (yay or paru) is not installed and automatic installation is disabled."
    exit 1
  fi
}

install_paru() {
  echo "Installing paru..."
  sudo pacman -Sy --needed base-devel git
  git clone https://aur.archlinux.org/paru.git
  cd paru
  makepkg -si --noconfirm
  cd ..
  rm -rf paru
  AUR_HELPER="paru"
}

# Function to check and replace docker-compose version if necessary
check_and_replace_docker_compose() {
  if ! command -v docker-compose > /dev/null || docker-compose --version | grep -q "docker-compose version 1"; then
    echo "docker-compose version 1.x not found, installing docker-compose-v1-bin..."
    $AUR_HELPER -S --needed --noconfirm docker-compose-v1-bin
  elif docker-compose --version | grep -q "docker-compose version 2"; then
    echo "Detected docker-compose version 2.x, which is not compatible with Umbrel."
    read -p "Would you like to replace it with docker-compose-v1-bin from AUR? [Y/n] " response
    if [[ "$response" =~ ^([yY][eE][sS]|[yY]|"")$ ]]; then
      echo "Replacing docker-compose with docker-compose-v1-bin..."
      $AUR_HELPER -Rns --noconfirm docker-compose
      $AUR_HELPER -S --needed --noconfirm docker-compose-v1-bin
    else
      echo "Umbrel requires docker-compose version 1.x to operate correctly. Please manually install it and try again."
      exit 1
    fi
  fi
}

# Function to install dependencies using pacman and AUR helper
install_dependencies() {
  echo "Updating the system..."
  sudo pacman -Syu --noconfirm

  echo "Installing dependencies from official repositories..."
  sudo pacman -S --noconfirm docker avahi nss-mdns jq rsync curl git base-devel python inetutils

  if [[ "$INSTALL_DOCKER_COMPOSE" == "true" ]]; then
    check_and_replace_docker_compose
  fi

  if [[ "$INSTALL_YQ" == "true" ]]; then
    echo "Installing yq using $AUR_HELPER..."
    $AUR_HELPER -S --needed --noconfirm yq
  fi

  if [[ "$INSTALL_FSWATCH" == "true" ]]; then
    echo "Installing fswatch using $AUR_HELPER..."
    $AUR_HELPER -S --needed --noconfirm fswatch
  fi

  if [[ "$INSTALL_AVAHI" == "true" ]]; then
    echo "Enabling and starting Avahi service..."
    sudo systemctl enable --now avahi-daemon.service
  fi

  echo "Enabling and starting Docker service..."
  sudo systemctl enable --now docker.service
}

# Function to install and setup Umbrel
install_and_setup_umbrel() {

  if [[ "$AUTO_START_UMBREL" == "true" ]]; then
  echo "Configuring Umbrel to start automatically on boot..."
  echo "
[Unit]
Wants=network-online.target
After=network-online.target
Wants=docker.service
After=docker.service

# This prevents us hitting restart rate limits and ensures we keep restarting indefinitely.
StartLimitInterval=0

[Service]
Type=forking
TimeoutStartSec=infinity
TimeoutStopSec=16min
ExecStart=${UMBREL_INSTALL_PATH}/scripts/start
ExecStop=${UMBREL_INSTALL_PATH}/scripts/stop
User=root
Group=root
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=umbrel startup
RemainAfterExit=yes
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target" | sudo tee "/etc/systemd/system/umbrel-startup.service"
  sudo chmod 644 "/etc/systemd/system/umbrel-startup.service"
  sudo systemctl daemon-reload
  sudo systemctl enable "umbrel-startup.service"

  fi

  if [[ "$INSTALL_UMBREL" == "true" ]]; then
    echo "Preparing Umbrel..."
    mkdir -p "$UMBREL_INSTALL_PATH"
    UMBREL_VERSION=$(curl --silent "https://api.github.com/repos/$UMBREL_REPO/releases/latest" | jq -r ".tag_name")
    curl -L "https://github.com/$UMBREL_REPO/archive/$UMBREL_VERSION.tar.gz" | tar -xz --strip-components=1 -C "$UMBREL_INSTALL_PATH"
    cd "$UMBREL_INSTALL_PATH"
    sudo ./scripts/configure
    echo "Executing Umbrel start script..."
    sudo ./scripts/start
  fi
}

# Main function to orchestrate the setup
main() {
  if [[ "$PRINT_DOCKER_WARNING" == "true" ]]; then
    echo "WARNING: This script will install Docker, which may conflict with other Docker installations."
  fi

  ensure_aur_helper
  install_dependencies
  install_and_setup_umbrel

  echo "Umbrel installation and setup complete."
}

main
