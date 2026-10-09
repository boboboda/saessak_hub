"""손님 걷기 시트 조립: assets/raw/pixellab/cust_X_walk/export/.../walking/<방향>/frame_00N.png
→ assets/sprites/customer/cust_N.png  (가로 7프레임, 세로 0 남 / 1 서 / 2 동 / 3 북)"""
from pathlib import Path
from PIL import Image
ROOT = Path(__file__).resolve().parents[2]
ORDER = ["south", "west", "east", "north"]
for n, k in enumerate("abcdefghijk"):  # g~k = 숨은 손님 (cust_6..10)
    base = ROOT / f"assets/raw/pixellab/cust_{k}_walk/export/Idle/animations/walking"
    if not base.exists():
        continue
    frames = [[Image.open(base / d / f"frame_{i:03d}.png").convert("RGBA") for i in range(7)] for d in ORDER]
    w, h = frames[0][0].size
    sheet = Image.new("RGBA", (w * 7, h * 4))
    for r, row in enumerate(frames):
        for c, im in enumerate(row):
            sheet.paste(im, (c * w, r * h))
    out = ROOT / f"assets/sprites/customer/cust_{n}.png"
    sheet.save(out)
    print(out.name, sheet.size)
