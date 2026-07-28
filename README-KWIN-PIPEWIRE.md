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
## Cursor routing for KWin virtual streams

When Apollo captures `Virtual-Apollo-Display`, KWin only embeds the cursor if the host cursor is inside that virtual output. This branch uses `apollo-display-mode` to handle that automatically.

On stream connect, the helper:

1. Saves the current host cursor position with `kdotool`.
2. Optionally disables the configured physical HDMI outputs.
3. Moves the cursor into `Virtual-Apollo-Display` using `ydotool` relative movement.

On stream disconnect, the helper:

1. Restores the configured physical display layout.
2. Waits for KWin/KScreen to settle.
3. Moves the cursor back to the saved position.

Required cursor-routing tools:

    sudo pacman -S --needed ydotool
    paru -S --needed kdotool

Useful test commands:

    ~/.local/bin/apollo-display-mode status
    cat /tmp/apollo-cursor-park.log
    kdotool getmouselocation --shell

The helper auto-starts `ydotoold` if it is not already running. If cursor movement fails, check:

    cat /tmp/ydotoold.log

For custom layouts, edit:

    ~/.config/apollo/kwin-virtual-monitor.env

Common values used during testing:

    APOLLO_KWIN_OUTPUT_NAME=Virtual-Apollo-Display
    APOLLO_PRIMARY_OUTPUT=HDMI-A-1
    APOLLO_SECONDARY_OUTPUT=HDMI-A-2
    APOLLO_DISABLE_PHYSICAL_ON_STREAM=enabled
    APOLLO_CURSOR_STREAM_X=200
    APOLLO_CURSOR_STREAM_Y=200
    APOLLO_SECONDARY_POSITION=0,0
    APOLLO_PRIMARY_POSITION=1920,0
    APOLLO_VIRTUAL_POSITION=3840,0

## Working display lifecycle

This restore point uses the proven archived KScreen state manager.

### Connected state

When an Artemis/Odin stream connects:

1. Apollo passes the selected streaming output to `apollo-display-mode`.
2. `apollo-display-mode` calls:

   ```text
   /usr/local/bin/apollo-kscreen-stream-monitors apply <selected-output>
   ```

3. The helper saves the complete pre-stream KScreen layout.
4. The selected streaming output is enabled.
5. Every other connected display is disabled.

The selected streaming output is therefore the only active display.

### Disconnected state

When the stream disconnects:

1. `apollo-display-mode` calls the staged `post-disconnect` recovery.
2. The helper waits for Apollo and PipeWire teardown.
3. The saved physical outputs and their priorities are restored.
4. The restored primary output is verified.
5. The virtual streaming output is disabled.

The idle state therefore has all physical displays enabled and the Apollo virtual display disabled.

### Important safety warning

Do not manually run `krfb-virtualmonitor` and do not manually restart
`apollo-kwin-virtual-monitor.service` merely to test display switching.
A previous manual virtual-monitor test disabled the primary physical display
and required a reboot.

### Clean rebuild requirements

Never delete the repository `src` directory.

Before configuring a fresh build, remove only:

```text
cmake-build-debug
pkg
src_assets/common/assets/web/node_modules/.vite
```

Build using all CPU cores. After building, install `/usr/local/assets` from:

```text
cmake-build-debug/assets/.
```

Do not populate `/usr/local/assets` from `src_assets/common/assets`; that source
directory does not contain the generated shader assets required by the installed
Apollo build.

### Restore-point layout

The exact working display helpers are stored in:

```text
scripts/systemd-user/apollo-display-mode
scripts/systemd-user/apollo-kscreen-stream-monitors
```

The annotated `working-apollo-*` Git tag records the complete known-good Apollo
tree, including the exact Inputtino submodule commit.


## MoonDeck Buddy integration

Apollo can install and manage MoonDeck Buddy as a user service. The **Advanced**
configuration page contains **Keep MoonDeck Buddy running with Apollo**, enabled
by default.

When enabled, starting Apollo pulls in `apollo-moondeck-buddy.service`. The
service launches `MoonDeckBuddy` with `NO_GUI=auto`, restarts it if it exits,
and stops it when Apollo stops. Applying a changed checkbox value restarts
Apollo, so the service state is reevaluated immediately.

The installer uses the Arch AUR package `moondeckbuddy-appimage`, disables
Buddy's independent autostart units to prevent duplicate processes, and adds a
`MoonDeckStream` application whose command is `MoonDeckStream`. **Continue
streaming if the application exits quickly** is disabled, as required by
MoonDeck Buddy's Sunshine setup.

To install or repair only the MoonDeck integration:

```fish
cd ~/Apollo-Linux
scripts/install-moondeck-buddy-support.sh
```

This installs:

```text
~/.local/bin/apollo-moondeck-buddy
~/.config/systemd/user/apollo-moondeck-buddy.service
~/.config/systemd/user/apollo.service.d/20-moondeck-buddy.conf
```

Verify with:

```fish
command -v MoonDeckBuddy
command -v MoonDeckStream
~/.local/bin/apollo-moondeck-buddy status
systemctl --user status apollo-moondeck-buddy.service --no-pager
```

MoonDeck Buddy stores its Linux settings under `~/.config/moondeckbuddy`.
Initial pairing should be completed while a KDE desktop session is available.

## Start Apollo with OS

The **General** configuration page contains **Start Apollo with OS**. The option
is enabled by default.

Apollo depends on the KDE graphical session, KWin, PipeWire, and the user D-Bus
session. Therefore, "with OS" means that Apollo starts automatically when the
KDE graphical session is ready after boot. On an auto-login CachyOS system this
occurs automatically during boot.

The implementation installs and enables:

```text
~/.config/systemd/user/apollo-start-on-boot.service
```

That policy service runs:

```text
~/.local/bin/apollo-start-on-boot
```

The helper reads `start_on_boot` from:

```text
~/.config/sunshine/sunshine.conf
```

A missing setting is treated as enabled, matching the checked-by-default web
configuration. When enabled, the policy starts `apollo.service`. When disabled,
it exits without starting Apollo.

The direct `apollo.service` autostart symlink is disabled intentionally. This
prevents stale systemd enablement from bypassing an unchecked checkbox. Apollo
can still be started manually:

```fish
systemctl --user start apollo.service
```

### Install or repair automatic startup only

```fish
cd ~/Apollo-Linux

scripts/install-apollo-start-on-boot-support.sh \
    --no-start
```

This installs and enables the startup policy without stopping or restarting the
currently running Apollo process and without touching the KWin virtual-monitor
service.

### Verification

```fish
~/.local/bin/apollo-start-on-boot status

systemctl --user is-enabled \
    apollo-start-on-boot.service
```

Changing the checkbox controls the next KDE graphical-session startup. It does
not stop the current Apollo process.
