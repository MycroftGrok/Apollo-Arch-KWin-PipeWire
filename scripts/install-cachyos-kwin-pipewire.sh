#!/usr/bin/env bash
set -euo pipefail

# Apollo KWin/PipeWire virtual-display installer for CachyOS/Arch KDE Wayland.
# Run as a normal user from inside the patched Apollo-Linux repo.

APOLLO_CAPTURE_NAME="${APOLLO_CAPTURE_NAME:-Virtual-apollo-test}"
APOLLO_VIRTUAL_NAME="${APOLLO_VIRTUAL_NAME:-apollo-test}"
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
rm -rf cmake-build-debug pkg

cmake -S . -B cmake-build-debug -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DSUNSHINE_ENABLE_CUDA=OFF \
  -DCUDA_FAIL_ON_MISSING=OFF

ninja -C cmake-build-debug -j"$(nproc)"

latest_bin="$(find cmake-build-debug -maxdepth 1 -type f -name 'sunshine-*' -printf '%T@ %p\n' | sort -nr | head -n 1 | cut -d' ' -f2-)"
[ -n "$latest_bin" ] || fail "Could not find built sunshine binary in cmake-build-debug."
ln -sf "$(basename "$latest_bin")" cmake-build-debug/sunshine

say "Packaging Apollo"
makepkg -fs --noconfirm

pkg_file="$(find . -maxdepth 1 -type f -name 'apollo-*.pkg.tar.zst' -printf '%T@ %p\n' | sort -nr | head -n 1 | cut -d' ' -f2-)"
[ -n "$pkg_file" ] || fail "Could not find generated apollo package."

say "Installing Apollo package"
sudo pacman -U --noconfirm "$pkg_file"

if [ -d cmake-build-debug/assets ]; then
  say "Installing Apollo web assets"
  sudo rm -rf /usr/local/assets
  sudo mkdir -p /usr/local/assets
  sudo cp -a cmake-build-debug/assets/. /usr/local/assets/
fi

say "Writing Apollo capture config"
mkdir -p "$HOME/.config/sunshine"
touch "$HOME/.config/sunshine/sunshine.conf"
APOLLO_CAPTURE_NAME="$APOLLO_CAPTURE_NAME" python3 - <<'PY'
import os
from pathlib import Path
p = Path.home() / ".config/sunshine/sunshine.conf"
lines = p.read_text().splitlines()
remove = ("capture =", "output_name =", "preserve_physical_display =")
lines = [x for x in lines if not x.startswith(remove)]
lines.append("capture = kwin")
lines.append(f"output_name = {os.environ['APOLLO_CAPTURE_NAME']}")
lines.append("preserve_physical_display = enabled")
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
Description=KDE virtual monitor for Apollo KWin capture
PartOf=apollo.service
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

say "Reloading and enabling user services"
systemctl --user daemon-reload
systemctl --user enable apollo
systemctl --user set-environment KWIN_WAYLAND_NO_PERMISSION_CHECKS=1 || true
dbus-update-activation-environment --systemd KWIN_WAYLAND_NO_PERMISSION_CHECKS || true

say "Installer finished"
printf '%s\n' \
  "Important: log out of KDE and log back in once so KWin receives KWIN_WAYLAND_NO_PERMISSION_CHECKS=1." \
  "After logging back in, run:" \
  "  systemctl --user restart apollo" \
  "" \
  "Verify with:" \
  "  kscreen-doctor -o | grep -A12 -E 'Virtual-apollo|apollo-test|Output:'" \
  "  journalctl --user -u apollo -n 160 --no-pager | grep -E 'KWin capture output|Initial capture display requested|kwingrab|pipewire|Virtual-apollo|Streaming display'"

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

# Apollo must receive the built assets, not the source asset directory.
if [ -d "${APOLLO_INSTALL_REPO_ROOT}/cmake-build-debug/assets" ]; then
  sudo rm -rf /usr/local/assets
  sudo install -d /usr/local/assets
  sudo cp -a \
    "${APOLLO_INSTALL_REPO_ROOT}/cmake-build-debug/assets/." \
    /usr/local/assets/
fi

# Establish the safe idle state when KScreen is available.
if command -v kscreen-doctor >/dev/null 2>&1; then
  "${HOME}/.local/bin/apollo-display-mode" disconnect || true
fi
# END WORKING APOLLO DISPLAY LIFECYCLE
