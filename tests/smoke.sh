#!/usr/bin/env bash
# Smoke test (Linux + macOS): make a test clip, shrink it, check the result fits.
#   tests/smoke.sh [path/to/shrink-video]
set -eu
HERE=$(cd "$(dirname "$0")" && pwd)
SHRINK=${1:-$HERE/../linux/shrink-video}
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

size() { stat -c %s "$1" 2>/dev/null || stat -f %z "$1"; }

ffmpeg -hide_banner -loglevel error -y \
    -f lavfi -i "testsrc2=size=1280x720:rate=30:duration=12" \
    -f lavfi -i "sine=frequency=440:duration=12" \
    -c:v libx264 -preset ultrafast -crf 12 -pix_fmt yuv420p -c:a aac -shortest "$WORK/my clip.mp4"
echo "Test clip: $(size "$WORK/my clip.mp4") bytes"

check() {  # label, file, limit in bytes
    [[ -f $2 ]] || { echo "FAIL ($1): $2 was not created"; exit 1; }
    local s; s=$(size "$2")
    ((s <= $3)) || { echo "FAIL ($1): $s bytes is over the $3 limit"; exit 1; }
    ffprobe -v error -show_entries format=duration -of csv=p=0 "$2" >/dev/null
    echo "ok ($1): $s bytes"
}

"$SHRINK" --cli --size 1 "$WORK/my clip.mp4"
check "default methods" "$WORK/my clip_1MB.mp4" 1000000

"$SHRINK" --cli --size 0.5 --methods resize,fps,speed "$WORK/my clip.mp4"
check "resize,fps,speed" "$WORK/my clip_0.5MB.mp4" 500000

# Already small enough: must succeed without writing anything.
"$SHRINK" --cli --size 500 "$WORK/my clip.mp4"
[[ ! -e "$WORK/my clip_500MB.mp4" ]] || { echo "FAIL: wrote a file for an already-small video"; exit 1; }

echo "All good."
