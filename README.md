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
3. **Run the script** with the following command:

```bash
./umbrel-arch.sh
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

## Umbrel Arch Script

```bash
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
```

## Contributions

Contributions are welcome! If you have any improvements or bug fixes, please feel free to fork this repository, make your changes, and submit a pull request.

## License

This script is provided under [MIT License](LICENSE). Umbrel and its logo are trademarks of their respective owners and are used here for informational purposes only.
