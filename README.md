# Apollo with Virtual Displays for Linux(Arch)

> **Fork of [Apollo](https://github.com/ClassicOldSong/Apollo) with Linux Virtual Display support**

Apollo is a self-hosted desktop stream host for [Artemis(Moonlight Noir)](https://github.com/ClassicOldSong/moonlight-android). Offering low latency, native client resolution, cloud gaming server capabilities with support for AMD, Intel, and Nvidia GPUs for hardware encoding. Software encoding is also available. A web UI is provided to allow configuration and client pairing from your favorite web browser. Pair from the local server or any mobile device. This version of Apollo has improvements over the base build. Some of the issues with the Linux version of Apollo have been fixed and new options have also been added.

Major features:

- [x] KWin virtual display automatically matches the client resolution and refresh rate on the tested KDE Wayland path
- [x] **Linux Virtual Display support using KWIN** *(new in this fork!)*
- [x] GUI Configuration page now directly reads/writes to Apollo configs.
- [x] Local monitors turn off when Artemis is connected.
- [x] Virtual monitor remains disabled when there is not sa connection. When connected all local monitors are disabled and the virtual display is enabled
- [x] Mouse cursor control - Mouse cursor now moves to virtual display when connected and back the it's original position when the connection is terminated

## Linux Virtual Display Support

This fork adds **real virtual display support for Linux** using [KWIN](https://github.com/KDE/kwin) (Now works with KDE just like in the windows release). 

### Features
- Creates isolated virtual displays that don't mirror your physical monitor
- Supports resolutions up to 4K (3840x2160)
- Dynamic loading of KWIN library (no hard dependency)
- Automatic KWIN module loading on boot
- Works with AMD, Intel, and Nvidia GPUs via VAAPI
- PipeWire DMA-BUF capture when supported by EGL/KWin

### Requirements (Required repositories, files, utilites and etc)
- 
- 

#### Protecting the custom Apollo package from CachyOS/Arch upgrades

This fork intentionally uses a protected Arch package version so a normal
CachyOS or Arch system update does not replace the custom KWin/PipeWire Apollo
build with the repository version of Apollo.

The `PKGBUILD` uses:

```text
epoch=1000
```

Pacman compares the package epoch before `pkgver` and `pkgrel`. Because normal
repository Apollo packages are epochless, this custom package remains newer
from Pacmans point of view even when the upstream Apollo version number
increases.

The `pkgver()` function also includes the Git revision in each locally built
package version. This makes it possible to identify exactly which revision of
this fork produced the installed package.

For example:

```text
1000:0.1.0.kwinpipewire.r1234.gabcdef12-1
```

Do not remove `epoch=1000` unless you intentionally want CachyOS or Arch to
replace this custom Apollo package with its repository build.

`IgnorePkg` is not required. Normal system updates can continue with:

```bash
sudo pacman -Syu
```

Apollo itself should be updated by pulling the latest version of this
repository, rebuilding it using the installation procedure below, and
installing the resulting package with `pacman -U`.

## Installation on CachyOS / Arch Linux with KDE Wayland

> [!IMPORTANT]
> This fork's tested Linux virtual-display path uses **KWin + PipeWire** on KDE
> Wayland. Do not install or configure EVDI for this path.

The tested host environment is CachyOS with KDE Plasma running a Wayland
session. Clone this fork, switch to the KWin/PipeWire branch, then run the
installer as your normal desktop user:

```bash
git clone https://github.com/MycroftGrok/Apollo-Arch-KWin-PipeWire.git
cd Apollo-Arch-KWin-PipeWire
git switch kwin-pipewire-capture-port

./scripts/install-cachyos-kwin-pipewire.sh
```

The installer performs a clean local build without deleting the source tree,
builds the Arch package, verifies that the package contains Apollo's runtime
web assets, and installs the package with `pacman -U`.

### KWin/PipeWire configuration installed by the script

The default persistent virtual monitor is:

```text
Apollo-Display
```

KWin exposes it to Apollo as:

```text
Virtual-Apollo-Display
```

Apollo is configured with:

```text
capture = kwin
output_name = Virtual-Apollo-Display
preserve_physical_display = enabled
fallback_mode = 1920x1080x60
kwin_virtual_display_client_override = enabled
```

When a client starts a stream, Apollo requests the client's resolution and
refresh rate from KWin. For example, a client requesting 1920x1080 at 120 Hz
selects the closest KWin mode (approximately 119.93 Hz on the tested system)
and forces scale 1 so the logical and physical stream resolutions match.

The virtual monitor is persistent across Apollo service restarts but normally
remains disabled while idle. The display lifecycle helper enables it for the
stream and restores the normal physical-display layout after disconnect.

### PipeWire DMA-BUF

On compatible EGL/Mesa/KWin configurations, this fork advertises supported
DMA-BUF formats and modifiers to PipeWire. When negotiation succeeds, Apollo
logs:

```text
[pipewire] using DMA-BUF buffers
```

This avoids the normal CPU memory-buffer copy in the KWin/PipeWire capture
path before VAAPI encoding.

### Package-owned web assets

Apollo is compiled to use:

```text
/usr/local/assets
```

Those files are owned and installed by the Arch package. The installer does
**not** delete or manually recopy `/usr/local/assets`; `pacman -U` manages
them.

### Updating this fork

Pull the latest branch, rerun the installer, and allow the newly built package
to replace the installed custom Apollo package:

```bash
cd Apollo-Arch-KWin-PipeWire
git switch kwin-pipewire-capture-port
git pull --ff-only

./scripts/install-cachyos-kwin-pipewire.sh
```

The package uses `epoch=1000`, so normal `sudo pacman -Syu` upgrades do not
replace this custom KWin/PipeWire build with the repository Apollo package.

## Usage

Refer to LizardByte's documentation hosted on [Read the Docs](https://docs.lizardbyte.dev/projects/sunshine) for now.

## About Permission System

Check out the [Wiki](https://github.com/ClassicOldSong/Apollo/wiki/Permission-System)

> [!NOTE]
> The **FIRST** client paired with Apollo will be granted with FULL permissions, then other newly paired clients will only be granted with `View Streams` and `List Apps` permission. If you encounter `Permission Denied` error when trying to launch any app, go check the permission for that device and grant `Launch Apps` permission. The same applies to the situation when you find that you can't move mouse or type with keyboard on newly paired clients, grant the corresponding client `Mouse Input` and `Keyboard Input` permissions.

## About Virtual Display

> [!WARNING]
> ***It is highly recommend to remove any other virtual display solutions from your system and Apollo/Sunshine config, to reduce confusions and compatibility issues.***

> [!NOTE]
> **TL;DR** Just treat your Artemis/Moonlight client like a dedicated PnP monitor with Apollo.

Apollo uses SudoVDA for virtual display. It features auto resolution and framerate matching for your Artemis/Moonlight clients. The virtual display is created upon the stream starts and removed once the app quits. **If you do not see a new virtual display added or removed when the stream starts or stops, there may be a driver misconfiguration, or another persistent virtual display might still be active.**

The virtual display works just like any physically attached monitors with SudoVDA, there's completely no need for a super complicated solution to "fix" resolution configurations for your devices. Unlike all other solutions that reuses one identity or generate a random one each time for any virtual display sessions, **Apollo assigns a fixed identity for each Artemis/Moonlight client, so your display configuration will be automatically remembered and managed by Windows natively.**

## Configuration for dual GPU laptops

Apollo supports dual GPUs seamlessly.

If you want to use your dGPU, just set the `Adapter Name` to your dGPU and enable `Headless mode` in `Audio/Video` tab, save and restart your computer. No dummy plug is needed any more, the image will be rendered and encoded directly from your dGPU.

## About HDR

HDR starts supporting from Windows 11 23H2 and generally supported on 24H2. Some systems might not have HDR toggle on 23H2 and you just need to upgrade to 24H2. Any system lower than 23H2/Windows 10 will not have HDR option available.

> [!NOTE]
> The below section is written for professional media workers. It doesn't stop you from enabling HDR if you know what you're doing and have deep understanding about how HDR works.
>
> Apollo and SudoVDA can handle HDR just fine like any other streaming solutions.
>
> If you have had good experience with HDR previously, you can safely ignore this section.
>
> If you're curious, read on, but don't blame Apollo for poor HDR support.

Whether HDR streaming looks good, it depends completely on your client.

In short, ICC color correction should be totally useless while streaming HDR. It's your client's job to get HDR content displayed right, not the host. But in fact, it does affect the captured video stream and reflect changes on devices that can handle HDR correctly. On other devices that can't, the info is not respected at all.

It's very complicated to explain why HDR is a total mess, and why enabling HDR makes the image appear dark/yellow. If it's your first time got HDR streaming working, and thinks HDR looks awful, you're right, but that's not Apollo's fault, it's your device that tone mapped SDR content to the maximum of the capability of its screen, there's no headroom for anything beyond that actual peak brightness for HDR. For details, please take a look [here](https://github.com/ClassicOldSong/Apollo/issues/164).

For client devices, usually Apple products that have HDR capability can be trusted to have good results, other than that, your luck depends.

<details>
<summary>DEPRECATION ALERT</summary>

Enabling HDR is **generally not recommended** with **ANY streaming solutions** at this moment, probably in the long term. The issue with **HDR itself** is huge, with loads of semi-incompatible standards, and massive variance between device configurations and capabilities. Game support for HDR is still choppy.

SDR actually provides much more stable color accuracy, and are widely supported throughout most devices you can imagine. For games, art style can easily overcome the shortcoming with no HDR, and SDR has pretty standard workflows to ensure their visual performance. So HDR isn't *that* important in most of the cases.

</details>

## How to run multiple instances of Apollo for multiple virtual displays

Follow the instructions in the [Wiki](https://github.com/ClassicOldSong/Apollo/wiki/How-to-start-multiple-instances-of-Apollo).

## FAQ
Moved to [WiKi](https://github.com/ClassicOldSong/Apollo/wiki/FAQ)

## Stuttering Clinic
Here're some common causes and solutions for stutters: [WiKi](https://github.com/ClassicOldSong/Apollo/wiki/Stuttering-Clinic).

## Device specific setups
- Pixel devices might not be able to use native resolution:
  - Change the device resolution to High: https://github.com/ClassicOldSong/Apollo/issues/700

## System Requirements

> **Warning**: This table is a work in progress. Do not purchase hardware based on this.

**Minimum Requirements**

| **Component** | **Description** |
|---------------|-----------------|
| GPU           | AMD: VCE 1.0 or higher, see: [obs-amd hardware support](https://github.com/obsproject/obs-amd-encoder/wiki/Hardware-Support) |
|               | Intel: VAAPI-compatible, see: [VAAPI hardware support](https://www.intel.com/content/www/us/en/developer/articles/technical/linuxmedia-vaapi.html) |
|               | Nvidia: NVENC enabled cards, see: [nvenc support matrix](https://developer.nvidia.com/video-encode-and-decode-gpu-support-matrix-new) |
| CPU           | AMD: Ryzen 3 or higher |
|               | Intel: Core i3 or higher |
| RAM           | 4GB or more |
| OS            | Windows: 10+ (Windows Server requires [manual installation](https://github.com/nefarius/ViGEmBus/issues/153) for gamepad support) |
|               | macOS: 12+ |
|               | Linux/Debian: 11 (bullseye) |
|               | Linux/Fedora: 39+ |
|               | Linux/Ubuntu: 22.04+ (jammy) |
| Network       | Host: 5GHz, 802.11ac |
|               | Client: 5GHz, 802.11ac |

**4k Suggestions**

| **Component** | **Description** |
|---------------|-----------------|
| GPU           | AMD: Video Coding Engine 3.1 or higher |
|               | Intel: HD Graphics 510 or higher |
|               | Nvidia: GeForce GTX 1080 or higher |
| CPU           | AMD: Ryzen 5 or higher |
|               | Intel: Core i5 or higher |
| Network       | Host: CAT5e ethernet or better |
|               | Client: CAT5e ethernet or better |

**HDR Suggestions**

| **Component** | **Description** |
|---------------|-----------------|
| GPU           | AMD: Video Coding Engine 3.4 or higher |
|               | Intel: UHD Graphics 730 or higher |
|               | Nvidia: Pascal-based GPU (GTX 10-series) or higher |
| CPU           | AMD: todo |
|               | Intel: todo |
| Network       | Host: CAT5e ethernet or better |
|               | Client: CAT5e ethernet or better |

## Integrations

SudoVDA: Virtual Display Adapter Driver used in Apollo

[Artemis](https://github.com/ClassicOldSong/moonlight-android): Integrated Virtual Display options control from client side

**NOTE**: Artemis currently supports Android only. Other platforms will come later.

## Support

Currently support is only provided via GitHub Issues/Discussions.

No real time chat support will ever be provided for Apollo and Artemis. Including but not limited to:

- Discord
- Telegram
- Whatsapp
- QQ
- WeChat 

> When there's a chat, there're dramas. -- Confucius

## Downloads

### Direct Download

**Recommended**

[Releases](https://github.com/ClassicOldSong/Apollo/releases)

### WinGet

**Note:** Community maintained

In an elevated PowerShell window, run

```pwsh
winget install ClassicOldSong.Apollo

```

You'll need WinGet installed first.

### Chocolatey

**Note:** Community maintained

You can also install the apollo streaming server with chocolatey.

Install Chocolatey if you don't have it, then run the following command in an elevated PowerShell/CMD window:

```pwsh
choco upgrade apollo -y 
```

Same command can be used to upgrade, add to a scheduled task to automate updates.

See more details on the chocolatey package [here](https://community.chocolatey.org/packages/apollo)

## Disclaimer

I got kicked from Moonlight and Sunshine's Discord server and banned from Sunshine's GitHub repo literally for helping people out.

This is what I got for finding a bug, opened an issue, getting no response, troubleshoot myself, fixed the issue myself, shared it by PR to the main repo hoping my efforts can help someone else during the maintenance gap.

Yes, I'm going away. [Apollo](https://github.com/ClassicOldSong/Apollo) and [Artemis(Moonlight Noir)](https://github.com/ClassicOldSong/moonlight-android) will no longer be compatible with OG Sunshine and OG Moonlight eventually, but they'll work even better with much more carefully designed features.

The Moonlight repo had stayed silent for 5 months, with nobody actually responding to issues, and people are getting totally no help besides the limited FAQ in their Discord server. I tried to answer issues and questions, solve problems within my ability but I got kicked out just for helping others.

**PRs for feature improvements are welcomed here unlike the main repo, your ideas are more likely to be appreciated and your efforts are actually being respected. We welcome people who can and willing to share their efforts, helping yourselves and other people in need.**

**Update**: They have contacted me and apologized for this incident, but the fact it **happened** still motivated me to start my own fork.

## License

GPLv3
