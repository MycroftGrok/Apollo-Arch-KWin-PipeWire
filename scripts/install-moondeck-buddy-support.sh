#!/usr/bin/env bash
set -euo pipefail

RESTART_APOLLO=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --restart-apollo)
      RESTART_APOLLO=1
      ;;
    --no-restart)
      RESTART_APOLLO=0
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

say "Installing MoonDeck Buddy"

if ! command -v MoonDeckBuddy >/dev/null 2>&1 \
  || ! command -v MoonDeckStream >/dev/null 2>&1
then
  if command -v paru >/dev/null 2>&1; then
    paru -S --needed --noconfirm moondeckbuddy-appimage
  elif command -v yay >/dev/null 2>&1; then
    yay -S --needed --noconfirm moondeckbuddy-appimage
  else
    fail "MoonDeck Buddy requires the AUR package moondeckbuddy-appimage. Install paru or yay first."
  fi
fi

command -v MoonDeckBuddy >/dev/null 2>&1 \
  || fail "MoonDeckBuddy was not found after installation."
command -v MoonDeckStream >/dev/null 2>&1 \
  || fail "MoonDeckStream was not found after installation."

say "Disabling MoonDeck Buddy's independent autostart units"

systemctl --user disable --now \
  moondeckbuddy.service \
  moondeckbuddy-gui-session.service \
  >/dev/null 2>&1 || true

say "Installing Apollo-managed MoonDeck Buddy service"

install -Dm755 \
  "${REPO_ROOT}/scripts/systemd-user/apollo-moondeck-buddy" \
  "${HOME}/.local/bin/apollo-moondeck-buddy"

install -Dm644 \
  "${REPO_ROOT}/scripts/systemd-user/apollo-moondeck-buddy.service" \
  "${HOME}/.config/systemd/user/apollo-moondeck-buddy.service"

install -Dm644 \
  "${REPO_ROOT}/scripts/systemd-user/20-moondeck-buddy.conf" \
  "${HOME}/.config/systemd/user/apollo.service.d/20-moondeck-buddy.conf"

say "Enabling MoonDeck Buddy by default in Apollo configuration"

mkdir -p "${HOME}/.config/sunshine"
touch "${HOME}/.config/sunshine/sunshine.conf"

python3 - <<'PY'
from pathlib import Path
import re

path = Path.home() / ".config/sunshine/sunshine.conf"
text = path.read_text(errors="replace")

if not re.search(r"^\s*moondeck_buddy\s*=", text, flags=re.MULTILINE):
    if text and not text.endswith("\n"):
        text += "\n"
    text += "moondeck_buddy = enabled\n"
    path.write_text(text)
    print(f"Added default setting to {path}")
else:
    print(f"Preserved existing MoonDeck Buddy setting in {path}")
PY

say "Adding or repairing the MoonDeckStream application"

APOLLO_REPO_ROOT="${REPO_ROOT}" python3 - <<'PY'
from __future__ import annotations

import json
import os
import re
import shutil
from datetime import datetime
from pathlib import Path

repo_root = Path(os.environ["APOLLO_REPO_ROOT"])
config_dir = Path.home() / ".config/sunshine"
config_path = config_dir / "sunshine.conf"

file_apps = ""
for line in config_path.read_text(errors="replace").splitlines():
    match = re.match(r"^\s*file_apps\s*=\s*(.*?)\s*$", line)
    if match:
        file_apps = match.group(1).split("#", 1)[0].strip().strip('"')
        break

if file_apps:
    apps_path = Path(file_apps).expanduser()
    if not apps_path.is_absolute():
        apps_path = config_dir / apps_path
else:
    apps_path = config_dir / "apps.json"

apps_path.parent.mkdir(parents=True, exist_ok=True)

if not apps_path.exists():
    source = repo_root / "src_assets/linux/assets/apps.json"
    shutil.copy2(source, apps_path)

stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
backup = apps_path.with_name(f"{apps_path.name}.before-moondeck-{stamp}")
shutil.copy2(apps_path, backup)

data = json.loads(apps_path.read_text())
apps = data.setdefault("apps", [])

entry = None
for candidate in apps:
    if str(candidate.get("name", "")).casefold() == "moondeckstream":
        entry = candidate
        break

if entry is None:
    entry = {}
    apps.append(entry)

entry.update(
    {
        "name": "MoonDeckStream",
        "cmd": "MoonDeckStream",
        "image-path": "steam.png",
        "auto-detach": False,
        "wait-all": False,
        "allow-client-commands": False,
    }
)

apps_path.write_text(json.dumps(data, indent=2) + "\n")

print(f"Configured: {apps_path}")
print(f"Backup:     {backup}")
PY

say "Reloading user services"

systemctl --user daemon-reload

if [ "$RESTART_APOLLO" -eq 1 ]; then
  say "Restarting Apollo"
  systemctl --user restart apollo.service
elif systemctl --user is-active --quiet apollo.service; then
  # Apply the new companion immediately without restarting Apollo or touching
  # the proven KWin virtual-monitor lifecycle.
  systemctl --user start apollo-moondeck-buddy.service || true
fi

say "MoonDeck Buddy integration installed"

printf '%s\n' \
  "Buddy command:      $(command -v MoonDeckBuddy)" \
  "Stream command:     $(command -v MoonDeckStream)" \
  "Apollo service:     ~/.config/systemd/user/apollo-moondeck-buddy.service" \
  "Apollo drop-in:     ~/.config/systemd/user/apollo.service.d/20-moondeck-buddy.conf" \
  "" \
  "Verify with:" \
  "  systemctl --user status apollo-moondeck-buddy.service --no-pager" \
  "  ~/.local/bin/apollo-moondeck-buddy status"
