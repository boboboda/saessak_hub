#!/usr/bin/env python3
"""위에서 본 차량 그림의 앞유리에 운전자(머리·어깨·손)를 도트로 그려 넣는다.

  python tools/pixellab/add_driver.py <입력.png> <출력.png> <머리 가운데 x> <머리 위 y> [--hair 4a2f1e] [--shirt 2f6fb0]

차가 아래로 달리는 그림 기준(앞유리가 아래쪽). 머리 위 → 얼굴 → 어깨·손·핸들 순으로 아래로 그린다.
"""
import argparse

from PIL import Image


def hexc(s):
    return tuple(int(s[i:i + 2], 16) for i in (0, 2, 4)) + (255,)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('src')
    ap.add_argument('dst')
    ap.add_argument('cx', type=int)
    ap.add_argument('top', type=int)
    ap.add_argument('--hair', default='3b2618')
    ap.add_argument('--shirt', default='2f6fb0')
    ap.add_argument('--helmet', action='store_true', help='머리 대신 헬멧 (오토바이)')
    a = ap.parse_args()
    im = Image.open(a.src).convert('RGBA')
    px = im.load()
    out = (24, 18, 22, 255)
    skin, skin_d = (240, 196, 160, 255), (205, 150, 118, 255)
    hair = hexc(a.hair)
    shirt = hexc(a.shirt)
    wheel = (40, 40, 48, 255)
    cx, y = a.cx, a.top

    def put(x, yy, c):
        if 0 <= x < im.width and 0 <= yy < im.height:
            px[x, yy] = c

    # 머리 (위에서 내려다본 정수리 + 얼굴 아래쪽)
    rows = [
        (-1, 1, out),
        (-2, 2, hair),
        (-2, 2, hair),
        (-2, 2, skin),
        (-1, 1, skin),
    ]
    for i, (l, r, c) in enumerate(rows):
        for x in range(cx + l, cx + r + 1):
            put(x, y + i, c)
        put(cx + l - 1, y + i, out)
        put(cx + r + 1, y + i, out)
    if a.helmet:
        for i in range(3):
            for x in range(cx - 2, cx + 3):
                put(x, y + i, hair)
        put(cx - 1, y + 3, (60, 70, 90, 255))  # 고글
        put(cx + 1, y + 3, (60, 70, 90, 255))
    else:
        put(cx - 1, y + 3, (40, 30, 30, 255))  # 눈
        put(cx + 1, y + 3, (40, 30, 30, 255))
    # 어깨(옷)
    for x in range(cx - 3, cx + 4):
        put(x, y + 5, shirt)
    put(cx - 4, y + 5, out)
    put(cx + 4, y + 5, out)
    # 팔·손 + 핸들
    put(cx - 3, y + 6, shirt)
    put(cx + 3, y + 6, shirt)
    put(cx - 2, y + 7, skin_d)
    put(cx + 2, y + 7, skin_d)
    for x in range(cx - 2, cx + 3):
        put(x, y + 8, wheel)
    im.save(a.dst)
    print(a.dst, im.size)


if __name__ == '__main__':
    main()
