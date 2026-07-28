#!/usr/bin/env bash
set -euo pipefail

START_NOW=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --start-now)
      START_NOW=1
      ;;
    --no-start)
      START_NOW=0
      ;;
    *)
      printf 'Unknown option: %s\n' "$1" >&2
      exit 2
      ;;
  esac
  shift
done

say() {
  printf '\n==> %s\n' "$*"
}

fail() {
  printf '\nERROR: %s\n' "$*" >&2
  exit 1
}

if [ "$(id -u)" -eq 0 ]; then
  fail "Run this installer as the normal desktop user, not root."
fi

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

[ -f "${REPO_ROOT}/PKGBUILD" ] \
  || fail "Apollo repository root was not found."

say "Installing Apollo start-with-OS policy"

install -Dm755 \
  "${REPO_ROOT}/scripts/systemd-user/apollo-start-on-boot" \
  "${HOME}/.local/bin/apollo-start-on-boot"

install -Dm644 \
  "${REPO_ROOT}/scripts/systemd-user/apollo-start-on-boot.service" \
  "${HOME}/.config/systemd/user/apollo-start-on-boot.service"

mkdir -p "${HOME}/.config/sunshine"
touch "${HOME}/.config/sunshine/sunshine.conf"

systemctl --user daemon-reload

# The policy service is the single source of truth for automatic startup.
# Disabling the direct unit prevents a stale systemd symlink from bypassing
# the checkbox when start_on_boot is disabled.
systemctl --user disable apollo.service >/dev/null 2>&1 || true
systemctl --user enable apollo-start-on-boot.service

if [ "$START_NOW" -eq 1 ]; then
  systemctl --user start apollo-start-on-boot.service
fi

say "Apollo start-with-OS integration installed"

"${HOME}/.local/bin/apollo-start-on-boot" status

printf '%s\n' \
  "" \
  "The setting defaults to enabled." \
  "Apollo will start when the KDE graphical session begins after boot." \
  "Unchecking it prevents automatic startup on the next sign-in or reboot." \
  "The current Apollo process is not stopped or restarted by this installer."
