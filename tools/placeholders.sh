#!/bin/zsh
# Re-capture the transparent first-frame placeholders (Resources/placeholder-<phase>@2x.png, 640x400).
# Needs the web folder served on :8768:  (cd web && python3 -m http.server 8768 &)
set -e
cd "$(dirname "$0")/.."; mkdir -p tools/phout
CH="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
for ph in day evening sunset night; do for bg in black white; do
  "$CH" --headless=new --disable-gpu-sandbox --use-angle=metal --hide-scrollbars --window-size=320,200 --force-device-scale-factor=2 \
    --virtual-time-budget=6000 --timeout=60000 --screenshot=tools/phout/$ph-$bg.png \
    "http://localhost:8768/index.html?capture=1&phase=$ph&livery=blue&bg=$bg" >/dev/null 2>&1 &
done; done; wait
python3 - <<'PY'
import numpy as np
from PIL import Image
for ph in ['day','evening','sunset','night']:
    B=np.asarray(Image.open(f'tools/phout/{ph}-black.png').convert('RGB')).astype(np.float32)
    W=np.asarray(Image.open(f'tools/phout/{ph}-white.png').convert('RGB')).astype(np.float32)
    a=np.clip(1-((W-B)/np.maximum(W[2,2]-B[2,2],1e-3)).mean(axis=2),0,1)          # difference matte
    col=np.clip(np.where(a[...,None]>1e-3, B/np.maximum(a[...,None],1e-3), 0),0,255)
    im=Image.fromarray(np.dstack([col,a*255]).astype(np.uint8)).crop((0,0,640,400))
    im.save(f'Resources/placeholder-{ph}@2x.png'); print(ph, im.size)
PY
