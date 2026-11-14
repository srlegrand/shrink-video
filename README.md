# Shrink Video

[![Build](https://github.com/srlegrand/shrink-video/actions/workflows/build.yml/badge.svg)](https://github.com/srlegrand/shrink-video/actions/workflows/build.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

Right-click a video, pick a target size, get `name_20MB.mp4` next to the original.
For Windows, macOS and Linux. Free, open source, and everything happens on your own computer.

**Website and downloads: <https://srlegrand.github.io/shrink-video/>**

## Install

| System | Download | Then |
| --- | --- | --- |
| **Windows** | [ShrinkVideo-Setup.exe](https://github.com/srlegrand/shrink-video/releases/latest/download/ShrinkVideo-Setup.exe) | Run it. No admin rights needed. |
| **macOS** | [ShrinkVideo-macOS.pkg](https://github.com/srlegrand/shrink-video/releases/latest/download/ShrinkVideo-macOS.pkg) | Right-click the file and choose **Open**. |
| **Linux** | [ShrinkVideo-x86_64.AppImage](https://github.com/srlegrand/shrink-video/releases/latest/download/ShrinkVideo-x86_64.AppImage) | Make it executable and double-click it. |

Or from a terminal, without downloading anything first:

    # macOS
    curl -fsSL https://raw.githubusercontent.com/srlegrand/shrink-video/main/macos/install.sh | bash

    # Linux (any architecture)
    curl -fsSL https://raw.githubusercontent.com/srlegrand/shrink-video/main/linux/install.sh | bash

Shrink Video needs [ffmpeg](https://ffmpeg.org). The Windows setup offers to install it;
on macOS use `brew install ffmpeg`, on Linux your package manager (`sudo apt install ffmpeg`).

The installers are not code-signed, so Windows SmartScreen ("More info" > "Run anyway")
and macOS Gatekeeper (right-click > Open, or System Settings > Privacy & Security >
"Open Anyway") ask for confirmation the first time.

## Use

Right-click a video file:

- **Windows** - *Shrink video* > 20 MB, 10 MB, 50 MB, 100 MB or Custom size...
  (on Windows 11 under **Show more options**, or Shift + right-click)
- **macOS** - *Quick Actions* > *Shrink Video*, then type the size
- **Linux** - *Shrink video* in Dolphin and Nemo, *Scripts > Shrink video* in Nautilus (GNOME Files)

A dialog then asks how the video may be shrunk. Tick any combination:

- **Resizing** - lower the resolution
- **Speeding it up** - play faster (up to 4x), so there is less video to store
- **Dropping the framerate** - e.g. 60 -> 30 fps
- **Compressing** - lower the picture quality

Shrink Video picks the mix of the ticked methods that hurts least while still fitting.
Without "Compressing" it keeps the picture clean and lets the other methods do the work;
if they cannot reach the size on their own it compresses anyway and says so.
The last choice is remembered. Output is H.264 + AAC in MP4 (two-pass).
The original is never modified.

From a terminal (Linux, macOS):

    shrink-video --size 20 --methods resize,fps,compress clip.mkv

## Uninstall

- **Windows** - *Settings > Apps > Installed apps > Shrink Video > Uninstall*
- **macOS** - `curl -fsSL https://raw.githubusercontent.com/srlegrand/shrink-video/main/macos/install.sh | bash -s -- --uninstall`
- **Linux** - double-click the AppImage again and choose **Remove**, or run it with `--uninstall`

## From source

    git clone https://github.com/srlegrand/shrink-video
    cd shrink-video
    linux/install.sh              # Linux    (--uninstall to remove)
    macos/install.sh              # macOS    (--uninstall to remove)
    windows\install.bat           # Windows  (install.bat -Uninstall to remove)

To change the preset sizes, edit the `SIZES` list at the top of `linux/install.sh` /
`$Sizes` in `windows/install.ps1` and re-run the installer. The first entry is the default.

| Path | What |
| --- | --- |
| `linux/shrink-video` | the script for Linux and macOS (bash) |
| `linux/install.sh`, `macos/install.sh` | add the right-click menus |
| `windows/shrink-video.ps1`, `windows/install.ps1` | the same for Windows (PowerShell) |
| `windows/setup.iss`, `packaging/` | installer definitions (Inno Setup, AppImage) |
| `tests/` | smoke tests run on all three systems by CI |
| `docs/` | the website (GitHub Pages) |

## Releasing

Push a tag and GitHub Actions builds, tests and publishes the three installers:

    git tag v1.2.3 && git push origin v1.2.3

## License

[MIT](LICENSE)
