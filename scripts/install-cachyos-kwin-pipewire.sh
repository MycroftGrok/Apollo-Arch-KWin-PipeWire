#!/usr/bin/env bash
set -euo pipefail

# Apollo KWin/PipeWire virtual-display installer for CachyOS/Arch KDE Wayland.
# Run as a normal user from inside the patched Apollo-Linux repo.

APOLLO_VIRTUAL_NAME="${APOLLO_VIRTUAL_NAME:-Apollo-Display}"
APOLLO_CAPTURE_NAME="${APOLLO_CAPTURE_NAME:-Virtual-${APOLLO_VIRTUAL_NAME}}"
APOLLO_VIRTUAL_RESOLUTION="${APOLLO_VIRTUAL_RESOLUTION:-1920x1080}"
APOLLO_VIRTUAL_PORT="${APOLLO_VIRTUAL_PORT:-5905}"
APOLLO_VIRTUAL_PASSWORD="${APOLLO_VIRTUAL_PASSWORD:-apollotest}"

say() {
  printf '\n==> %s\n' "$*"
}

fail() {
  printf '\nERROR: %s\n' "$*" >&2
  exit 1
}

if [ "$(id -u)" -eq 0 ]; then
  fail "Do not run this script as root. Run it as your normal user."
fi

if ! command -v pacman >/dev/null 2>&1; then
  fail "pacman not found. This installer is for CachyOS/Arch-based systems."
fi

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/../PKGBUILD" ]; then
  REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
elif [ -f "$SCRIPT_DIR/PKGBUILD" ]; then
  REPO_ROOT="$SCRIPT_DIR"
elif [ -f "$PWD/PKGBUILD" ]; then
  REPO_ROOT="$PWD"
else
  fail "Could not find Apollo repo root. Run this from inside the Apollo-Linux repo."
fi

cd "$REPO_ROOT"

say "Apollo KWin/PipeWire virtual-display installer"
printf 'Repo root: %s\n' "$REPO_ROOT"
printf 'Virtual output: %s\n' "$APOLLO_CAPTURE_NAME"
printf 'Virtual monitor name: %s\n' "$APOLLO_VIRTUAL_NAME"
printf 'Virtual monitor resolution: %s\n' "$APOLLO_VIRTUAL_RESOLUTION"

say "Installing required system packages"
packages=(
  base-devel
  git
  cmake
  ninja
  pkgconf
  python
  nodejs
  npm
  pipewire
  wireplumber
  krfb
  kscreen
  ydotool
  qt6-wayland
  wayland-protocols
  mesa
  libva-utils
  libva-mesa-driver
)
sudo pacman -S --needed --noconfirm "${packages[@]}"

command -v krfb-virtualmonitor >/dev/null 2>&1 || fail "krfb-virtualmonitor was not found after installing krfb."
command -v kscreen-doctor >/dev/null 2>&1 || fail "kscreen-doctor was not found after installing kscreen."

if ! command -v kdotool >/dev/null 2>&1; then
  say "Installing kdotool for KDE/Wayland cursor position restore"
  if command -v paru >/dev/null 2>&1; then
    paru -S --needed --noconfirm kdotool
  elif command -v yay >/dev/null 2>&1; then
    yay -S --needed --noconfirm kdotool
  else
    fail "kdotool is required for cursor save/restore. Install paru or yay, then run: paru -S --needed kdotool"
  fi
fi

command -v ydotool >/dev/null 2>&1 || fail "ydotool was not found after package install."
command -v ydotoold >/dev/null 2>&1 || fail "ydotoold was not found after package install."
command -v kdotool >/dev/null 2>&1 || fail "kdotool was not found after install."

say "Building Apollo"
rm -rf cmake-build-debug pkg src_assets/common/assets/web/node_modules/.vite
[ -d src ] || fail "Safety check failed: src directory is missing after build cleanup."

cmake -S . -B cmake-build-debug -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DSUNSHINE_ENABLE_CUDA=OFF \
  -DCUDA_FAIL_ON_MISSING=OFF \
  -DUSE_UHID=ON

ninja -C cmake-build-debug -j"$(nproc)"

latest_bin="$(find cmake-build-debug -maxdepth 1 -type f -name 'sunshine-*' -printf '%T@ %p\n' | sort -nr | head -n 1 | cut -d' ' -f2-)"
[ -n "$latest_bin" ] || fail "Could not find built sunshine binary in cmake-build-debug."
ln -sf "$(basename "$latest_bin")" cmake-build-debug/sunshine

say "Packaging Apollo"
makepkg -fs --noconfirm

pkg_file="$(find . -maxdepth 1 -type f -name 'apollo-*.pkg.tar.zst' -printf '%T@ %p\n' | sort -nr | head -n 1 | cut -d' ' -f2-)"
[ -n "$pkg_file" ] || fail "Could not find generated apollo package."

say "Verifying packaged Apollo web assets"
if ! bsdtar -tf "$pkg_file" | grep -qx 'usr/local/assets/web/index.html'; then
  fail "Generated package is missing usr/local/assets/web/index.html."
fi

say "Installing Apollo package"
sudo pacman -U --noconfirm "$pkg_file"

[ -f /usr/local/assets/web/index.html ] || \
  fail "Apollo package installed, but /usr/local/assets/web/index.html is missing."

say "Writing Apollo capture config"
mkdir -p "$HOME/.config/sunshine"
touch "$HOME/.config/sunshine/sunshine.conf"
APOLLO_CAPTURE_NAME="$APOLLO_CAPTURE_NAME" \
APOLLO_VIRTUAL_RESOLUTION="$APOLLO_VIRTUAL_RESOLUTION" \
python3 - <<'PY'
import os
from pathlib import Path

p = Path.home() / ".config/sunshine/sunshine.conf"
lines = p.read_text().splitlines()
remove = (
    "capture =",
    "output_name =",
    "preserve_physical_display =",
    "fallback_mode =",
    "kwin_virtual_display_client_override =",
)
lines = [x for x in lines if not x.startswith(remove)]

lines.append("capture = kwin")
lines.append(f"output_name = {os.environ['APOLLO_CAPTURE_NAME']}")
lines.append("preserve_physical_display = enabled")
lines.append(f"fallback_mode = {os.environ['APOLLO_VIRTUAL_RESOLUTION']}x60")
lines.append("kwin_virtual_display_client_override = enabled")

p.write_text("\n".join(lines) + "\n")
PY

say "Configuring KWin ScreenCast permission environment"
mkdir -p "$HOME/.config/environment.d"
printf 'KWIN_WAYLAND_NO_PERMISSION_CHECKS=1\n' > "$HOME/.config/environment.d/99-apollo-kwin.conf"

mkdir -p "$HOME/.config/systemd/user/apollo.service.d"
cat > "$HOME/.config/systemd/user/apollo.service.d/kwin-env.conf" <<'EOF2'
[Service]
Environment=KWIN_WAYLAND_NO_PERMISSION_CHECKS=1
EOF2

sudo tee /usr/share/applications/apollo-kwin-screencast.desktop >/dev/null <<'EOF2'
[Desktop Entry]
Name=Apollo KWin ScreenCast
Exec=/usr/bin/apollo
Type=Application
NoDisplay=true
X-KDE-Wayland-Interfaces=zkde_screencast_unstable_v1
EOF2

say "Creating automatic KDE virtual-monitor service"
krfb_bin="$(command -v krfb-virtualmonitor)"
cat > "$HOME/.config/systemd/user/apollo-kwin-virtual-monitor.service" <<EOF2
[Unit]
Description=Persistent KDE virtual monitor for Apollo KWin capture
After=graphical-session.target

[Service]
Type=simple
ExecStart=$krfb_bin --resolution $APOLLO_VIRTUAL_RESOLUTION --name $APOLLO_VIRTUAL_NAME --password $APOLLO_VIRTUAL_PASSWORD --port $APOLLO_VIRTUAL_PORT
Restart=on-failure
RestartSec=2

[Install]
WantedBy=default.target
EOF2

cat > "$HOME/.config/systemd/user/apollo.service.d/10-kwin-virtual-monitor.conf" <<'EOF2'
[Unit]
Wants=apollo-kwin-virtual-monitor.service
After=apollo-kwin-virtual-monitor.service

[Service]
ExecStartPre=/usr/bin/sleep 3
EOF2

say "Installing MoonDeck Buddy integration"
"$REPO_ROOT/scripts/install-moondeck-buddy-support.sh" --no-restart

say "Installing Apollo start-with-OS integration"
"$REPO_ROOT/scripts/install-apollo-start-on-boot-support.sh" --no-start

say "Reloading user services"
systemctl --user daemon-reload
systemctl --user set-environment KWIN_WAYLAND_NO_PERMISSION_CHECKS=1 || true
dbus-update-activation-environment --systemd KWIN_WAYLAND_NO_PERMISSION_CHECKS || true

say "Installer finished"
printf '%s\n' \
  "Important: log out of KDE and log back in once so KWin receives KWIN_WAYLAND_NO_PERMISSION_CHECKS=1." \
  "After logging back in, run:" \
  "  systemctl --user restart apollo" \
  "" \
  "Verify with:" \
  "  kscreen-doctor -o | grep -A12 -E 'Virtual-Apollo-Display|Apollo-Display|Output:'" \
  "  journalctl --user -u apollo -n 160 --no-pager | grep -E 'KWin capture output|Initial capture display requested|kwingrab|pipewire|Virtual-Apollo-Display|Streaming display'"

# BEGIN WORKING APOLLO DISPLAY LIFECYCLE
#
# Install the proven KScreen stream lifecycle:
#   connected    -> only the selected streaming output is enabled
#   disconnected -> physical outputs are restored, then the virtual output is disabled
#
APOLLO_INSTALL_SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
APOLLO_INSTALL_REPO_ROOT="$(CDPATH= cd -- "${APOLLO_INSTALL_SCRIPT_DIR}/.." && pwd)"

install -Dm755 \
  "${APOLLO_INSTALL_REPO_ROOT}/scripts/systemd-user/apollo-display-mode" \
  "${HOME}/.local/bin/apollo-display-mode"

sudo install -Dm755 \
  "${APOLLO_INSTALL_REPO_ROOT}/scripts/systemd-user/apollo-kscreen-stream-monitors" \
  /usr/local/bin/apollo-kscreen-stream-monitors

# /usr/local/assets is package-owned. pacman -U above installs/replaces it.
# Never delete or recopy it manually here.

# Establish the safe idle state when KScreen is available.
if command -v kscreen-doctor >/dev/null 2>&1; then
  "${HOME}/.local/bin/apollo-display-mode" disconnect || true
fi
# END WORKING APOLLO DISPLAY LIFECYCLE
