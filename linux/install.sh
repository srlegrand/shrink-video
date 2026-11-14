#!/usr/bin/env bash
# Installs shrink-video and adds a "Shrink video" right-click menu to
# Dolphin (KDE), Nautilus (GNOME Files) and Nemo (Cinnamon), whichever exist.
#
#   ./install.sh              install
#   ./install.sh --uninstall  remove everything again
#
# Also works without a checkout:
#   curl -fsSL https://raw.githubusercontent.com/srlegrand/shrink-video/main/linux/install.sh | bash
set -eu

SIZES=(20 10 50 100)   # first entry is labelled as the default
RAW="https://raw.githubusercontent.com/srlegrand/shrink-video/main"
HERE=""
[[ -n ${BASH_SOURCE[0]-} ]] && HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
BIN="$HOME/.local/bin/shrink-video"
DATA="${XDG_DATA_HOME:-$HOME/.local/share}"

DOLPHIN="$DATA/kio/servicemenus/shrink-video.desktop"
NAUTILUS="$DATA/nautilus/scripts/Shrink video"
NEMO="$DATA/nemo/actions"

if [[ ${1-} == --uninstall ]]; then
    rm -f "$BIN" "$DOLPHIN" "$NEMO"/shrink-video-*.nemo_action
    rm -rf "$NAUTILUS"
    echo "Removed."
    exit 0
fi

command -v ffmpeg >/dev/null || echo "Warning: ffmpeg not found - install it (e.g. sudo apt install ffmpeg)."
command -v zenity >/dev/null || echo "Note: install 'zenity' to get a progress bar with a Cancel button."

if [[ -n $HERE && -f $HERE/shrink-video ]]; then
    install -Dm755 "$HERE/shrink-video" "$BIN"
else
    mkdir -p "$(dirname "$BIN")"
    if command -v curl >/dev/null; then curl -fsSL "$RAW/linux/shrink-video" -o "$BIN"
    else wget -qO "$BIN" "$RAW/linux/shrink-video"; fi
    chmod 755 "$BIN"
fi
echo "Installed $BIN"

label() { if [[ $1 == "${SIZES[0]}" ]]; then echo "$1 MB (default)"; else echo "$1 MB"; fi; }

# --- Dolphin / KDE ---------------------------------------------------------
if command -v dolphin >/dev/null; then
    mkdir -p "$(dirname "$DOLPHIN")"
    {
        echo "[Desktop Entry]"
        echo "Type=Service"
        echo "X-KDE-ServiceTypes=KonqPopupMenu/Plugin"
        echo "MimeType=video/*;"
        echo "X-KDE-Submenu=Shrink video"
        echo "Icon=video-x-generic"
        printf 'Actions='; printf 'size%s;' "${SIZES[@]}"; echo "custom;"
        for s in "${SIZES[@]}"; do
            echo
            echo "[Desktop Action size$s]"
            echo "Name=$(label "$s")"
            echo "Icon=video-x-generic"
            echo "Exec=$BIN --size $s %F"
        done
        echo
        echo "[Desktop Action custom]"
        echo "Name=Custom size..."
        echo "Icon=configure"
        echo "Exec=$BIN --ask %F"
    } > "$DOLPHIN"
    chmod +x "$DOLPHIN"
    echo "Added Dolphin menu"
fi

# --- Nautilus / GNOME Files (Scripts > Shrink video) -----------------------
if command -v nautilus >/dev/null; then
    mkdir -p "$NAUTILUS"
    for s in "${SIZES[@]}"; do
        printf '#!/bin/sh\nexec "%s" --size %s "$@"\n' "$BIN" "$s" > "$NAUTILUS/$(label "$s")"
    done
    printf '#!/bin/sh\nexec "%s" --ask "$@"\n' "$BIN" > "$NAUTILUS/Custom size..."
    chmod +x "$NAUTILUS"/*
    echo "Added Nautilus scripts"
fi

# --- Nemo / Cinnamon -------------------------------------------------------
if command -v nemo >/dev/null; then
    mkdir -p "$NEMO"
    nemo_action() {  # file-suffix, label, args
        printf '[Nemo Action]\nName=Shrink video: %s\nExec=%s %s %%F\nIcon-Name=video-x-generic\nSelection=notnone\nMimetypes=video/*;\n' \
            "$2" "$BIN" "$3" > "$NEMO/shrink-video-$1.nemo_action"
    }
    for s in "${SIZES[@]}"; do nemo_action "$s" "$(label "$s")" "--size $s"; done
    nemo_action custom "Custom size..." "--ask"
    echo "Added Nemo actions"
fi

echo "Done. Right-click a video file and look for \"Shrink video\"."
