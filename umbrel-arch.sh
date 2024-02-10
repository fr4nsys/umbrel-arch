#!/bin/bash

set -euo pipefail

# Initial configuration
UMBREL_REPO="getumbrel/umbrel"
UMBREL_PATH="$HOME/umbrel"
UMBREL_VERSION="release"

# Detect if yay is installed, otherwise, try with paru
if command -v yay &> /dev/null; then
    AUR_HELPER="yay"
elif command -v paru &> /dev/null; then
    AUR_HELPER="paru"
else
    echo "Error: yay or paru is not installed. Please install one of them to continue."
    exit 1
fi

# Updates the system
echo "Updating the system..."
sudo pacman -Syu --noconfirm

# Installs necessary dependencies
echo "Installing dependencies..."
sudo pacman -S --noconfirm docker docker-compose avahi nss-mdns jq rsync curl git base-devel python inetutils
$AUR_HELPER -S --needed --noconfirm fswatch
# Enables and starts Docker
echo "Enabling and starting Docker..."
sudo systemctl enable --now docker.service

# Enables and starts Avahi
echo "Enabling and starting Avahi..."
sudo systemctl enable --now avahi-daemon.service

# Installs yq from AUR
echo "Installing yq from AUR..."
$AUR_HELPER -S --noconfirm yq

# Downloads and installs Umbrel
install_umbrel() {
    echo "Installing Umbrel..."
    local version=$(get_umbrel_version)
    mkdir -p "$UMBREL_PATH"
    curl -L "https://github.com/$UMBREL_REPO/archive/$version.tar.gz" | tar -xz --strip-components=1 -C "$UMBREL_PATH"
    pushd "$UMBREL_PATH"
    sudo ./scripts/start
    popd
}

# Gets the latest version of Umbrel
get_umbrel_version() {
    if [[ "$UMBREL_VERSION" == "release" ]]; then
        version=$(curl --silent "https://api.github.com/repos/$UMBREL_REPO/releases/latest" | jq -r ".tag_name")
        if [[ "$version" == "null" ]]; then
            echo "Could not fetch the latest version of Umbrel." >&2
            exit 1
        fi
        echo "$version"
    else
        echo "$UMBREL_VERSION"
    fi
}

install_umbrel

echo "Installation completed."
