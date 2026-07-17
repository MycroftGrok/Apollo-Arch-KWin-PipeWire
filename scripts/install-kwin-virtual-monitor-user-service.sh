#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SYSTEMD_SRC="${REPO_ROOT}/scripts/systemd-user"

mkdir -p \
  "${HOME}/.local/bin" \
  "${HOME}/.config/apollo" \
  "${HOME}/.config/systemd/user" \
  "${HOME}/.config/systemd/user/apollo.service.d" \
  "${HOME}/.cache/apollo"

chmod 700 "${HOME}/.config/apollo"

ENV_FILE="${HOME}/.config/apollo/kwin-virtual-monitor.env"

OLD_PASSWORD=""
OLD_DISABLE=""
if [ -f "$ENV_FILE" ]; then
  OLD_PASSWORD="$(grep -E "^APOLLO_KRFB_PASSWORD=" "$ENV_FILE" | head -n1 | cut -d= -f2- || true)"
  OLD_DISABLE="$(grep -E "^APOLLO_DISABLE_PHYSICAL_ON_STREAM=" "$ENV_FILE" | head -n1 | cut -d= -f2- || true)"
fi

PASSWORD="${APOLLO_KRFB_PASSWORD:-${OLD_PASSWORD:-change-me}}"
RESOLUTION="${APOLLO_VIRTUAL_RESOLUTION:-1920x1080}"
NAME="${APOLLO_VIRTUAL_NAME:-Apollo-Display}"
KWIN_OUTPUT="${APOLLO_KWIN_OUTPUT_NAME:-Virtual-${NAME}}"
PORT="${APOLLO_VIRTUAL_PORT:-5905}"
PRIMARY="${APOLLO_PRIMARY_OUTPUT:-HDMI-A-1}"
SECONDARY="${APOLLO_SECONDARY_OUTPUT:-HDMI-A-2}"
DISABLE_PHYSICAL="${APOLLO_DISABLE_PHYSICAL_ON_STREAM:-${OLD_DISABLE:-enabled}}"

install -m 755 "${SYSTEMD_SRC}/apollo-kwin-virtual-monitor-poststart" \
  "${HOME}/.local/bin/apollo-kwin-virtual-monitor-poststart"

install -m 755 "${SYSTEMD_SRC}/apollo-display-mode" \
  "${HOME}/.local/bin/apollo-display-mode"

install -m 644 "${SYSTEMD_SRC}/apollo-kwin-virtual-monitor.service" \
  "${HOME}/.config/systemd/user/apollo-kwin-virtual-monitor.service"

install -m 644 "${SYSTEMD_SRC}/apollo.service.d-10-kwin-virtual-monitor.conf" \
  "${HOME}/.config/systemd/user/apollo.service.d/10-kwin-virtual-monitor.conf"

cat > "$ENV_FILE" <<ENV
APOLLO_KRFB_PASSWORD=${PASSWORD}
APOLLO_VIRTUAL_RESOLUTION=${RESOLUTION}
APOLLO_VIRTUAL_NAME=${NAME}
APOLLO_KWIN_OUTPUT_NAME=${KWIN_OUTPUT}
APOLLO_VIRTUAL_PORT=${PORT}
APOLLO_PRIMARY_OUTPUT=${PRIMARY}
APOLLO_SECONDARY_OUTPUT=${SECONDARY}
APOLLO_DISABLE_PHYSICAL_ON_STREAM=${DISABLE_PHYSICAL}
APOLLO_CURSOR_STREAM_X=200
APOLLO_CURSOR_STREAM_Y=200
APOLLO_SECONDARY_POSITION=0,0
APOLLO_PRIMARY_POSITION=1920,0
APOLLO_VIRTUAL_POSITION=3840,0
ENV

chmod 600 "$ENV_FILE"

python3 - "$KWIN_OUTPUT" <<PY
from pathlib import Path
import sys

output_name = sys.argv[1]
p = Path.home() / ".config/sunshine/sunshine.conf"
s = p.read_text() if p.exists() else ""

def set_key(text, key, value):
    out = []
    found = False
    for line in text.splitlines():
        if line.strip().startswith(key + " ="):
            out.append(f"{key} = {value}")
            found = True
        else:
            out.append(line)
    if not found:
        out.append(f"{key} = {value}")
    return "\n".join(out) + "\n"

s = set_key(s, "capture", "kwin")
s = set_key(s, "output_name", output_name)
s = set_key(s, "preserve_physical_display", "enabled")
p.parent.mkdir(parents=True, exist_ok=True)
p.write_text(s)
PY

systemctl --user daemon-reload
systemctl --user reset-failed

echo "Installed KWin virtual monitor service."
echo "Installed Apollo display-mode helper."
echo "Apollo output_name set to: ${KWIN_OUTPUT}"
echo "Disable physical displays on stream: ${DISABLE_PHYSICAL}"
echo "Private env file: ${ENV_FILE}"
