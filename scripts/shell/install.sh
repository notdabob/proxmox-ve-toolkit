#!/bin/sh
# Cross-platform bootstrapper for AI Code Assist Boilerplate (POSIX shell)
# Installs PowerShell if missing, then runs PowerShell installer

set -e

confirm() {
  # Prompt for user confirmation
  printf "%s [y/N]: " "$1"
  read ans
  case "$ans" in
    [Yy]*) return 0 ;;
    *) return 1 ;;
  esac
}

# Check for pwsh (PowerShell Core)
if ! command -v pwsh >/dev/null 2>&1; then
  echo "PowerShell not found. Installing PowerShell..."
  # macOS
  if [ "$(uname)" = "Darwin" ]; then
    if ! command -v brew >/dev/null 2>&1; then
      echo "Homebrew not found. Would you like to install Homebrew automatically?"
      if confirm "Install Homebrew?"; then
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        echo "Homebrew installed."
        export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
      else
        echo "Please install Homebrew manually: https://brew.sh/"
        exit 1
      fi
    fi
    brew install --cask powershell
  # Linux
  elif [ -f /etc/debian_version ]; then
    . /etc/os-release
    if [ "$ID" = "debian" ]; then
      echo "Detected Debian. Installing PowerShell for Debian..."
      sudo apt-get update && sudo apt-get install -y wget apt-transport-https software-properties-common
      wget -q "https://packages.microsoft.com/config/debian/${VERSION_ID}/packages-microsoft-prod.deb"
      sudo dpkg -i packages-microsoft-prod.deb
      sudo apt-get update
      sudo apt-get install -y powershell
    elif [ "$ID" = "ubuntu" ]; then
      echo "Detected Ubuntu. Installing PowerShell for Ubuntu..."
      sudo apt-get update && sudo apt-get install -y wget apt-transport-https software-properties-common
      wget -q "https://packages.microsoft.com/config/ubuntu/${VERSION_ID}/packages-microsoft-prod.deb"
      sudo dpkg -i packages-microsoft-prod.deb
      sudo apt-get update
      sudo apt-get install -y powershell
    else
      echo "Detected $ID. Please install PowerShell manually: https://docs.microsoft.com/powershell/scripting/install/installing-powershell"
      exit 1
    fi
  else
    echo "Unsupported OS. Please install PowerShell manually: https://docs.microsoft.com/powershell/scripting/install/installing-powershell"
    exit 1
  fi
fi


# Assert that pwsh is now installed
if ! command -v pwsh >/dev/null 2>&1; then
  echo "❌ PowerShell installation failed. Please install PowerShell manually: https://docs.microsoft.com/powershell/scripting/install/installing-powershell"
  exit 1
fi

# Run the PowerShell installer
pwsh "$(dirname "$0")/../powershell/install.ps1"
