import numpy as np, sys, json, os
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'Resources')
from PIL import Image
# difference matting: same scene on black and on white backgrounds
out = {}
bbox_all = None
imgs = {}
for ph in ['day','evening','sunset','night']:
    B = np.asarray(Image.open(f'archout/{ph}-black.png').convert('RGB')).astype(np.float32)
    W = np.asarray(Image.open(f'archout/{ph}-white.png').convert('RGB')).astype(np.float32)
    # the canvas is shorter than the screenshot: drop the body-coloured strip below it
    valid = np.where(W[:, 4, 0] > 60)[0]; H = valid.max() + 1
    B = B[:H]; W = W[:H]
    bbg = B[4,4]; wbg = W[4,4]
    alpha = 1 - ((W - B) / np.maximum(wbg - bbg, 1e-3)).mean(axis=2)
    alpha = np.clip(alpha, 0, 1)
    # straight colour from the black render (premultiplied over black)
    col = np.where(alpha[..., None] > 1e-3, B / np.maximum(alpha[..., None], 1e-3), 0)
    col = np.clip(col, 0, 255)
    rgba = np.dstack([col, alpha * 255]).astype(np.uint8)
    imgs[ph] = rgba
    ys, xs = np.where(alpha > 0.02)
    bb = (xs.min(), ys.min(), xs.max() + 1, ys.max() + 1)
    bbox_all = bb if bbox_all is None else (min(bbox_all[0], bb[0]), min(bbox_all[1], bb[1]), max(bbox_all[2], bb[2]), max(bbox_all[3], bb[3]))
x0, y0, x1, y1 = bbox_all
# symmetric crop about the image centre so the arch stays centred
cx = imgs['day'].shape[1] / 2
half = max(cx - x0, x1 - cx)
x0, x1 = int(cx - half), int(cx + half)
print('bbox', x0, y0, x1, y1, 'size', x1 - x0, y1 - y0, 'aspect', (x1 - x0) / (y1 - y0))
for ph, rgba in imgs.items():
    im = Image.fromarray(rgba[y0:y1, x0:x1])
    # premultiply-aware downsample: resize RGBA with LANCZOS on premultiplied data then un-premultiply
    w = 1056; h = round(im.height * w / im.width)
    a = np.asarray(im).astype(np.float32); pm = a.copy(); pm[..., :3] *= a[..., 3:4] / 255
    small = np.asarray(Image.fromarray(pm.astype(np.uint8)).resize((w, h), Image.LANCZOS)).astype(np.float32)
    al = small[..., 3:4]; rgb = np.where(al > 0, small[..., :3] * 255 / np.maximum(al, 1), 0)
    res = Image.fromarray(np.dstack([np.clip(rgb, 0, 255), al[..., 0]]).astype(np.uint8))
    res.save(f'{OUT}/arch-{ph}@3x.png')
    print(ph, res.size)
