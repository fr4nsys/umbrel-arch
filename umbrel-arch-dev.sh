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

# Function to install dependencies using pacman and AUR helper
install_dependencies() {
  echo "Updating the system..."
  sudo pacman -Syu --noconfirm

  echo "Installing dependencies from official repositories..."
  sudo pacman -S --noconfirm docker docker-compose avahi nss-mdns jq rsync curl git base-devel python inetutils

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

# Function to update docker-compose.yml for Umbrel
update_docker_compose_file() {
  echo "Updating docker-compose.yml to use the new network syntax..."
  UMBREL_DOCKER_COMPOSE_FILE="$UMBREL_INSTALL_PATH/docker-compose.yml"
  if [[ -f "$UMBREL_DOCKER_COMPOSE_FILE" ]]; then
    # Backup original docker compose file
    cp "$UMBREL_DOCKER_COMPOSE_FILE" "${UMBREL_DOCKER_COMPOSE_FILE}.bak"
    
    # Use sed to update (fix) the actual docker compose configuration to fix this error: WARN[0000] network default: network.external.name is deprecated. Please set network.name with external: true
    sed -i 's/network.external.name/network.name/g' "$UMBREL_DOCKER_COMPOSE_FILE"
    sed -i '/network.name/a \    external: true' "$UMBREL_DOCKER_COMPOSE_FILE"
  else
    echo "docker-compose.yml not found, skipping update."
  fi
}

# Function to install and setup Umbrel
install_and_setup_umbrel() {
  if [[ "$INSTALL_UMBREL" == "true" ]]; then
    echo "Preparing Umbrel..."
    mkdir -p "$UMBREL_INSTALL_PATH"
    UMBREL_VERSION=$(curl --silent "https://api.github.com/repos/$UMBREL_REPO/releases/latest" | jq -r ".tag_name")
    curl -L "https://github.com/$UMBREL_REPO/archive/$UMBREL_VERSION.tar.gz" | tar -xz --strip-components=1 -C "$UMBREL_INSTALL_PATH"
    
    # Update docker-compose.yml before starting Umbrel
    update_docker_compose_file
    
    cd "$UMBREL_INSTALL_PATH"
    sudo ./scripts/configure
    echo "Executing Umbrel start script..."
    sudo ./scripts/start
  fi
}

# Main function to orchestrate the setup
main() {
  ensure_aur_helper
  install_dependencies
  install_and_setup_umbrel
  echo "Umbrel installation script has completed."
}

main "$@"
