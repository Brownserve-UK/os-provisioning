#!/bin/bash -e -o pipefail
# Adapted from GitHub's script: https://raw.githubusercontent.com/actions/virtual-environments/main/images/macos/provision/core/homebrew.sh

echo "Installing Homebrew..."
HOMEBREW_INSTALL_URL="https://raw.githubusercontent.com/Homebrew/install/master/install.sh"
/bin/bash -c "$(curl -fsSL ${HOMEBREW_INSTALL_URL})"

echo "Disabling Homebrew analytics..."
/usr/local/bin/brew analytics off

echo "Installing curl..."
/usr/local/bin/brew install curl

# init brew bundle feature
/usr/local/bin/brew tap Homebrew/bundle