#!/usr/bin/env python3
"""PixelLab 타일셋(tileset.json)을 Wang 코너 순서 시트로 만든다.

사용: python tools/pixellab/tileset_sheet.py <에셋이름> <출력.png>
시트: 가로 16칸. 칸 번호 = NW*8 + NE*4 + SW*2 + SE*1 (upper=1, lower=0).
"""
import base64, io, json, sys
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent.parent
name, out = sys.argv[1], sys.argv[2]
ts = json.loads((ROOT / "assets/raw/pixellab" / name / "tileset.json").read_text(encoding="utf-8"))["tileset"]
w, h = ts["tile_size"]["width"], ts["tile_size"]["height"]
sheet = Image.new("RGBA", (w * 16, h))
seen = set()
for t in ts["tiles"]:
    c = t["corners"]
    idx = sum(b for k, b in (("NW", 8), ("NE", 4), ("SW", 2), ("SE", 1)) if c[k] == "upper")
    im = Image.open(io.BytesIO(base64.b64decode(t["image"]["base64"]))).convert("RGBA")
    sheet.paste(im, (idx * w, 0))
    seen.add(idx)
missing = sorted(set(range(16)) - seen)
if missing:
    sys.exit(f"빠진 코너 조합: {missing}")
sheet.save(out)
print("저장:", out, sheet.size)
