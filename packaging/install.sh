#!/bin/sh
# Adds the notepads-arch pacman repository and installs Notepads.
# Read it first: curl -fsSL https://fresh600.github.io/notepads-arch/install.sh
set -eu

if ! command -v pacman >/dev/null 2>&1; then
  echo "Notepads needs Arch Linux (or Omarchy) with pacman." >&2
  exit 1
fi

if ! grep -q '^\[notepads-arch\]' /etc/pacman.conf; then
  echo "Adding the [notepads-arch] repository to /etc/pacman.conf"
  printf '\n[notepads-arch]\nSigLevel = Optional TrustAll\nServer = https://fresh600.github.io/notepads-arch/$arch\n' \
    | sudo tee -a /etc/pacman.conf >/dev/null
fi

sudo pacman -Sy --needed notepads-arch
echo "Installed. Open Notepads from the app launcher, or run: notepads"
