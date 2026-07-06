# Apollo Linux KWin/PipeWire Virtual Display Setup

This branch adds KDE/KWin PipeWire capture support for Apollo on KDE Plasma Wayland and configures Apollo to stream from a KDE virtual monitor instead of a physical display.

## Tested target

This setup is intended for:

- CachyOS / Arch Linux
- KDE Plasma Wayland
- PipeWire + WirePlumber
- Apollo built from this branch
- AMD/VAAPI encoding tested

It is not meant for upstream Apollo packages that do not include this branch's KWin/PipeWire patches.

## What this setup does

The installer script:

1. Installs required Arch/CachyOS packages.
2. Builds Apollo from this repo.
3. Installs the generated Apollo package.
4. Configures Apollo to use KWin capture.
5. Creates a KDE virtual monitor using `krfb-virtualmonitor`.
6. Adds a user systemd service so the virtual monitor starts before Apollo.
7. Sets the KWin ScreenCast permission bypass environment variable.

The expected streaming path is:

```text
Apollo starts
→ systemd starts krfb-virtualmonitor
→ KDE creates Virtual-apollo-test
→ Apollo captures it through KWin ScreenCast / PipeWire
→ Moonlight streams Virtual-apollo-test
```

## Quick install

On a fresh CachyOS/Arch KDE Wayland PC:

```fish
git clone -b kwin-pipewire-capture-port https://github.com/MycroftGrok/Apollo-Linux-KWin-PipeWire.git
cd Apollo-Linux-KWin-PipeWire
scripts/install-cachyos-kwin-pipewire.sh
```

After the installer finishes, log out of KDE and log back in once.

Then start or restart Apollo:

```fish
systemctl --user restart apollo
```

## Verify the setup

Check that the virtual monitor service is running:

```fish
systemctl --user status apollo apollo-kwin-virtual-monitor.service --no-pager
```

Check that KDE sees the virtual monitor:

```fish
kscreen-doctor -o | grep -A12 -E "Virtual-apollo|apollo-test|Output:"
```

Check Apollo capture logs:

```fish
journalctl --user -u apollo -n 160 --no-pager | grep -E "KWin capture output|Initial capture display requested|kwingrab|pipewire|Virtual-apollo|VIRTUAL-|Streaming display"
```

Expected success lines:

```text
KWin capture output [Virtual-apollo-test] configured; skipping Apollo virtual display creation
Initial capture display requested [Virtual-apollo-test]
[kwingrab] Screencasting output name Virtual-apollo-test
[pipewire] Streaming display 'Virtual-apollo-test'
```

You should not see Apollo creating the old EVDI virtual display in this path:

```text
[VDISPLAY] Creating virtual display: VIRTUAL-
```

It is okay if Apollo logs that it initialized the Linux virtual display driver. The important distinction is that it should not create a `VIRTUAL-*` display for this KWin path.

## Installed user services

The installer creates:

```text
~/.config/systemd/user/apollo-kwin-virtual-monitor.service
~/.config/systemd/user/apollo.service.d/10-kwin-virtual-monitor.conf
~/.config/systemd/user/apollo.service.d/kwin-env.conf
~/.config/environment.d/99-apollo-kwin.conf
```

The virtual monitor service runs:

```text
krfb-virtualmonitor --resolution 1920x1080 --name apollo-test --password apollotest --port 5905
```

Apollo is configured to capture:

```text
capture = kwin
output_name = Virtual-apollo-test
preserve_physical_display = enabled
```

## Notes

- `apollo-kwin-virtual-monitor.service` may show as `disabled`. That is normal. It is pulled in by `apollo.service` through `Wants=` and `After=`.
- KWin needs the environment variable `KWIN_WAYLAND_NO_PERMISSION_CHECKS=1`. Logging out and back in after installation is required so the KDE session receives it.
- NVENC/CUDA errors are harmless on AMD systems during encoder probing. VAAPI is the expected encoder path on AMD.

## Troubleshooting

If Apollo captures a physical HDMI monitor instead of the virtual monitor, check whether `Virtual-apollo-test` exists before Apollo starts:

```fish
systemctl --user stop apollo
systemctl --user restart apollo-kwin-virtual-monitor.service
sleep 3
kscreen-doctor -o | grep -A12 -E "Virtual-apollo|apollo-test|Output:"
systemctl --user restart apollo
```

If `Virtual-apollo-test` is missing, check the virtual monitor service:

```fish
systemctl --user status apollo-kwin-virtual-monitor.service --no-pager
journalctl --user -u apollo-kwin-virtual-monitor.service -n 80 --no-pager
```

If KWin ScreenCast is not available, confirm the environment is present:

```fish
systemctl --user show apollo -p Environment
cat ~/.config/environment.d/99-apollo-kwin.conf
```

Then log out of KDE and log back in.

## Uninstall automation only

This removes only the KWin virtual monitor automation and environment drop-ins. It does not uninstall Apollo.

```fish
systemctl --user stop apollo
systemctl --user stop apollo-kwin-virtual-monitor.service

rm -f ~/.config/systemd/user/apollo-kwin-virtual-monitor.service
rm -f ~/.config/systemd/user/apollo.service.d/10-kwin-virtual-monitor.conf
rm -f ~/.config/systemd/user/apollo.service.d/kwin-env.conf
rm -f ~/.config/environment.d/99-apollo-kwin.conf

systemctl --user daemon-reload
```

## Current branch

```text
kwin-pipewire-capture-port
```

Important commits in this branch:

```text
Add CachyOS KWin PipeWire installer script
Skip Apollo virtual display when KWin output capture is configured
Fix preserved KWin capture display selection
Add Apollo display selection and preserve physical display controls
Port KWin PipeWire capture backend to Apollo
```
