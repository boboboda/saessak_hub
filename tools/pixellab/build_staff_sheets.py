"""직원 외형 변형 시트: staff_b..f_walk → assets/sprites/staff/staff_walk_1..5.png (배치는 staff_walk.png 와 동일)"""
from pathlib import Path
import numpy as np
from PIL import Image
from scipy import ndimage
import sys
os_letters = sys.argv[1] if len(sys.argv) > 1 else "bcd"
ROOT = Path(__file__).resolve().parents[2]
ORDER = ["south", "west", "east", "north"]
for n, k in enumerate(os_letters, start=1):
    base = ROOT / f"assets/raw/pixellab/staff_{k}_walk/export/Idle/animations/walking"
    frames = [[Image.open(base / d / f"frame_{i:03d}.png").convert("RGBA") for i in range(7)] for d in ORDER]
    w, h = frames[0][0].size
    sheet = Image.new("RGBA", (w * 7, h * 4))
    for r, row in enumerate(frames):
        for c, im in enumerate(row):
            sheet.paste(im, (c * w, r * h))
    a = np.array(sheet)
    for r in range(4):
        for c in range(7):
            sub = a[r*h:(r+1)*h, c*w:(c+1)*w]
            m = sub[..., 3] > 0
            lab, cnt = ndimage.label(m, structure=np.ones((3, 3)))
            if cnt > 1:
                sizes = ndimage.sum(m, lab, range(1, cnt + 1))
                keep = 1 + int(np.argmax(sizes))
                for j in range(1, cnt + 1):
                    if j != keep and sizes[j-1] < 40:
                        sub[lab == j] = 0
    out = ROOT / f"assets/sprites/staff/staff_walk_{n}.png"
    Image.fromarray(a).save(out)
    print(out.name, sheet.size)
