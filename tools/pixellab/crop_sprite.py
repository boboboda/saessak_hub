#!/usr/bin/env python3
"""PixelLab 후보 이미지를 게임용으로 자른다.

  python tools/pixellab/crop_sprite.py <입력.png> <출력.png> [--pick top|bottom|left|right|big]

- 알파가 약한(40 이하) 잔여 픽셀을 지우고,
- 빈 열/빈 행으로 나뉜 덩어리 중 하나만 남긴다 (옆·위아래 후보 조각이 붙어 오는 경우).
  기본은 가장 넓은 덩어리(big). 같은 그림이 위아래로 둘 들어 있으면 top/bottom 으로 고른다.
- 마지막으로 투명 여백을 잘라낸다.
"""
import sys
from PIL import Image


def runs(filled):
    out, i = [], 0
    while i < len(filled):
        if filled[i]:
            s = i
            while i < len(filled) and filled[i]:
                i += 1
            out.append((s, i))
        else:
            i += 1
    return out


def main():
    src, dst = sys.argv[1], sys.argv[2]
    pick = sys.argv[sys.argv.index('--pick') + 1] if '--pick' in sys.argv else 'big'
    im = Image.open(src).convert('RGBA')
    a = im.getchannel('A').point(lambda v: 255 if v > 40 else 0)
    im.putalpha(a)
    w, h = im.size
    px = a.load()
    cols = runs([any(px[x, y] for y in range(h)) for x in range(w)])
    if pick == 'left':
        c = cols[0]
    elif pick == 'right':
        c = cols[-1]
    else:
        c = max(cols, key=lambda r: r[1] - r[0])
    im = im.crop((c[0], 0, c[1], h))
    a = im.getchannel('A')
    px = a.load()
    rows = runs([any(px[x, y] for x in range(im.width)) for y in range(im.height)])
    if pick == 'top':
        r = rows[0]
    elif pick == 'bottom':
        r = rows[-1]
    else:
        r = max(rows, key=lambda r: r[1] - r[0])
    im = im.crop((0, r[0], im.width, r[1]))
    im = im.crop(im.getchannel('A').getbbox())
    im.save(dst)
    print(dst, im.size)


if __name__ == '__main__':
    main()
