#!/bin/zsh
# usage: shot.sh out.png "query" [w h]
W=${3:-1600}; H=${4:-1100}
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless=new --disable-gpu-sandbox --use-angle=metal --hide-scrollbars --window-size=$W,$H --force-device-scale-factor=1 --virtual-time-budget=8000 --timeout=60000 --screenshot=$1 "http://localhost:8767/arch.html?$2" >/dev/null 2>&1
