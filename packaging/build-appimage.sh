#!/usr/bin/env bash
# Builds dist/ShrinkVideo-x86_64.AppImage.
# Uses `appimagetool` from PATH, or the one given in $APPIMAGETOOL.
set -eu
ROOT=$(cd "$(dirname "$0")/.." && pwd)
ARCH=${ARCH:-x86_64}
TOOL=${APPIMAGETOOL:-appimagetool}
APPDIR="$ROOT/build/ShrinkVideo.AppDir"

rm -rf "$APPDIR"
mkdir -p "$APPDIR/usr/bin" "$ROOT/dist"
install -m755 "$ROOT/linux/shrink-video" "$ROOT/linux/install.sh" "$APPDIR/usr/bin/"
install -m755 "$ROOT/packaging/appimage/AppRun" "$APPDIR/AppRun"
install -m644 "$ROOT/packaging/appimage/shrink-video.desktop" "$ROOT/packaging/shrink-video.svg" "$APPDIR/"
ln -s shrink-video.svg "$APPDIR/.DirIcon"

# --appimage-extract-and-run: lets appimagetool itself run without FUSE (CI).
ARCH=$ARCH "$TOOL" --appimage-extract-and-run "$APPDIR" "$ROOT/dist/ShrinkVideo-$ARCH.AppImage"
echo "Built $ROOT/dist/ShrinkVideo-$ARCH.AppImage"
