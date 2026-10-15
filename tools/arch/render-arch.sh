#!/bin/zsh
# Re-render the stone arch for all four phases and write Resources/arch-<phase>@3x.png.
# Needs: Google Chrome, python3 with numpy + Pillow, and tools/arch served on :8767:
#   (cd tools/arch && python3 -m http.server 8767 &)
set -e
cd "$(dirname "$0")"; mkdir -p archout
for ph in day evening sunset night; do for bg in black white; do
  ./shot.sh archout/$ph-$bg.png "phase=$ph&bg=$bg" 3200 2200 &
done; done; wait
python3 matte.py   # prints the asset size: update StationCard.archSize / plaqueCenterY if the height changed
