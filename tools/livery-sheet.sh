#!/bin/zsh
# Contact sheet of every train livery with the train frozen in frame (?t= seconds), for checking skins.
# Needs the web folder served on :8768:  (cd web && python3 -m http.server 8768 &)
set -e
cd "$(dirname "$0")/.."; mkdir -p tools/liv
CH="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
LV=($(sed -n '/^const LIVERIES = {/,/^};/p' web/index.html | grep -oE '^  [a-z]+:' | tr -d ' :'))
T=${1:-7.2}
for i in $(seq 0 8 $((${#LV[@]}-1))); do for lv in ${LV[@]:$i:8}; do
  "$CH" --headless=new --disable-gpu-sandbox --use-angle=metal --hide-scrollbars --window-size=960,600 --force-device-scale-factor=1 \
    --virtual-time-budget=5000 --timeout=60000 --screenshot=tools/liv/$lv.png "http://localhost:8768/index.html?phase=day&livery=$lv&t=$T" >/dev/null 2>&1 &
done; wait; done
python3 - "$T" <<'PY'
import sys, glob
from PIL import Image, ImageDraw
files=sorted(glob.glob('tools/liv/*.png')); tiles=[]
for f in files:
    im=Image.open(f).convert('RGB').crop((0,160,960,520)).resize((640,240)); d=ImageDraw.Draw(im)
    d.rectangle((0,0,150,18),fill=(0,0,0)); d.text((4,3),f.split('/')[-1][:-4],fill=(255,255,255)); tiles.append(im)
cols=3; rows=(len(tiles)+cols-1)//cols; sheet=Image.new('RGB',(cols*640,rows*240),(255,255,255))
for i,t in enumerate(tiles): sheet.paste(t,((i%cols)*640,(i//cols)*240))
sheet.save('tools/livery-sheet.png'); print('tools/livery-sheet.png', len(tiles), 'liveries at t=', sys.argv[1])
PY
