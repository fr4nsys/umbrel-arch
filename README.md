# umbrel-arch

An unofficial Umbrel installer for Arch Linux &amp; derivatives. Umbrel team granted permission to review &amp; incorporate. Tested rigorously but carries no warranty. Proceed with caution &amp; test in a controlled environment.

# Umbrel Installer for Arch Linux

![Umbrel Logo](https://avatars.githubusercontent.com/u/59408891?s=200&v=4) ![Arch Linux Logo](https://raw.githubusercontent.com/archlinux/.github/main/profile/archlinux-logo-dark-scalable.svg)

This repository provides a script to install [Umbrel](https://umbrel.com/umbrelos), on Arch Linux systems, including derivatives. This script aims to simplify the process of getting Umbrel up and running on Arch Linux, which is not officially supported by the Umbrel team as of now.

![Umbrel Screen](https://camo.githubusercontent.com/997aad9ceccbc6f50bfaade3aced1f84184dfeb0568f35cbffe4b75a722ea9ba/68747470733a2f2f692e696d6775722e636f6d2f623849654772752e6a706567)

## Disclaimer

This script is **unofficial** and has been tested on Arch Linux and its derivatives. While it has been designed to work correctly out of the box, **I do not take any responsibility for any issues, data loss, or any other unwanted effects** that may occur from using this script. Always test it in a lab environment before running it on your primary system.

Umbrel and the Umbrel team have full permission to review, modify, and distribute this script to add official support for Arch Linux if they choose to do so.

## Prerequisites

- An Arch Linux system (or a derivative)
- `yay` or `paru` installed for managing AUR packages
- Basic knowledge of Linux terminal and commands

## Installation

1. **Clone this repository** or download the script to your local machine.

```bash
git clone https://github.com/fr4nsys/umbrel-arch
```
```bash
wget https://raw.githubusercontent.com/fr4nsys/umbrel-arch/main/umbrel-arch.sh
```
2. **Navigate** to the cloned directory.
3. **Run the script** with the following command (without sudo or being root):

```bash
./umbrel-arch.sh
```
4. **All in one** command:

```bash
wget https://raw.githubusercontent.com/fr4nsys/umbrel-arch/main/umbrel-arch.sh && chmod +x umbrel-arch.sh && ./umbrel-arch.sh
```
 
## What the Script Does

- **Updates your system:** Ensures that all your packages are up to date.
- **Installs necessary dependencies:** Includes Docker, Docker Compose, Avahi, nss-mdns, jq, rsync, curl, git, base-devel, python, and fswatch from AUR.
- **Enables and starts Docker and Avahi services:** Prepares your system for running Umbrel.
- **Downloads and installs Umbrel:** Fetches the latest version of Umbrel and installs it in your `$HOME/umbrel` directory.

## Links

- [Umbrel Website](https://umbrel.com/umbrelos)
- [Umbrel GitHub Repository](https://github.com/getumbrel/umbrel)
- [Umbrel OS](https://github.com/getumbrel/umbrel-os)

## Known Issues

- ~~Errors with docker network, and dns relosution. Working on the dev script and issue open.~~ (Fixed Replacing Docker Compose to version 1.x on the instalation script.)

	WARN[0000] network default: network.external.name is deprecated. Please set network.name with external: true Docker Compose version 2.23.3

- Error on Arch Linux ARM64 cause docker-comopose-v1 don´t support arm64
	:: The following packages are not compatible with your architecture:
    		docker-compose-v1-bin
	:: Would you like to try build them anyway?
	-bash: /usr/bin/docker-compose: cannot execute binary file: Exec format error

## Umbrel Arch Script

```bash
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
UMBREL_VERSION="v0.5.4"
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
    #UMBREL_VERSION=$(curl --silent "https://api.github.com/repos/$UMBREL_REPO/releases/$UMBREL_VERSION" | jq -r ".tag_name")
    curl -L "https://github.com/getumbrel/umbrel/archive/v0.5.4/v0.5.4.tar.gz" | tar -xz --strip-components=1 -C "$UMBREL_INSTALL_PATH"
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
```

## Contributions

Contributions are welcome! If you have any improvements or bug fixes, please feel free to fork this repository, make your changes, and submit a pull request.

## License

This script is provided under [MIT License](LICENSE). Umbrel, Arch Linux and its logos are trademarks of their respective owners and are used here for informational purposes only.
