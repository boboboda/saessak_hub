#!/usr/bin/env python3
"""허브 배경 디테일을 절차적으로 만든다 (PixelLab 크레딧 0).

  python tools/hubgen/gen_hub_detail.py

만드는 것 (assets/sprites/tiles/):
- wall_back.png : 창고 뒷벽 2칸 높이(32x64) 4종 가로 묶음 — 0 민벽 · 1 창문 · 2 환기창 · 3 배관
- wall_items.png: 벽에 거는 것 16x24 4종 — 0 시계 · 1 공지판 · 2 안전 포스터 · 3 소화전 함
- floor_var.png : 바닥 변형 32x32 4종 (투명 바탕 위 얼룩·금·패치·배수구) — 바닥 위에 드문드문 겹침
색은 lib/ui/structure_view.dart 의 Pal 과 같은 톤. 외곽선은 ink(#2A2438) 1px.
"""
import random
from PIL import Image, ImageDraw

INK = (0x2A, 0x24, 0x38, 255)
FACE = (0xCB, 0xB8, 0x98, 255)
LINE = (0xB4, 0xA0, 0x7E, 255)
DARK = (0x8C, 0x75, 0x56, 255)
CAP = (0x7A, 0x5C, 0x3A, 255)
CAPHI = (0x9C, 0x7A, 0x52, 255)
GLASS = (0x7F, 0xB6, 0xD9, 255)
GLASSHI = (0xCD, 0xE8, 0xF7, 255)
FRAME = (0x4E, 0x4A, 0x5C, 255)
METAL = (0x9A, 0xA3, 0xAE, 255)
METALDK = (0x6E, 0x76, 0x82, 255)
RED = (0xD9, 0x48, 0x3B, 255)
YEL = (0xF2, 0xC2, 0x30, 255)
GREEN = (0x3F, 0xA3, 0x4D, 255)
WHITE = (0xF4, 0xF1, 0xE8, 255)
CORK = (0xB9, 0x8A, 0x5A, 255)
OUT = 'assets/sprites/tiles/'


def shade(c, k):
    return tuple(max(0, min(255, int(v * k))) for v in c[:3]) + (c[3],)


def rect(d, x0, y0, x1, y1, fill, outline=INK):
    d.rectangle([x0, y0, x1, y1], fill=fill, outline=outline)


def wall_cell(kind, seed):
    """창고 뒷벽 한 칸 (32x64). 위 44px 골판(세로 골) · 아래 18px 걸레받이(진한 판) · 맨 아래 1px 그늘."""
    rnd = random.Random(seed)
    im = Image.new('RGBA', (32, 64), FACE)
    d = ImageDraw.Draw(im)
    # 골판: 4px 마다 밝은 골·어두운 골
    for x in range(0, 32, 4):
        d.line([(x, 0), (x, 44)], fill=LINE)
        d.line([(x + 1, 0), (x + 1, 44)], fill=shade(FACE, 1.06))
    # 가로 이음매
    d.line([(0, 22), (31, 22)], fill=DARK)
    # 걸레받이
    rect(d, -1, 45, 32, 63, shade(DARK, 1.05), None)
    d.line([(0, 45), (31, 45)], fill=INK)
    d.line([(0, 46), (31, 46)], fill=shade(DARK, 1.3))
    for x in range(0, 32, 16):
        d.line([(x, 47), (x, 62)], fill=shade(DARK, 0.85))  # 판 이음
    # 얼룩·때 (아래쪽에 조금)
    for _ in range(5):
        x, y = rnd.randrange(32), rnd.randrange(30, 44)
        im.putpixel((x, y), shade(FACE, 0.9))
    for _ in range(4):
        x, y = rnd.randrange(32), rnd.randrange(48, 62)
        im.putpixel((x, y), shade(DARK, 0.8))
    if kind == 1:  # 창문 (위쪽)
        rect(d, 5, 5, 26, 19, FRAME)
        d.rectangle([7, 7, 24, 17], fill=GLASS)
        d.line([(15, 7), (15, 17)], fill=FRAME)
        d.line([(16, 7), (16, 17)], fill=FRAME)
        d.line([(8, 15), (12, 9)], fill=GLASSHI)
        d.line([(9, 16), (13, 10)], fill=GLASSHI)
        d.line([(18, 15), (21, 10)], fill=GLASSHI)
        d.line([(5, 20), (26, 20)], fill=shade(DARK, 0.9))  # 창턱 그늘
    elif kind == 2:  # 환기창 (루버)
        rect(d, 8, 8, 23, 21, METAL)
        for y in range(10, 20, 3):
            d.line([(9, y), (22, y)], fill=METALDK)
            d.line([(9, y + 1), (22, y + 1)], fill=shade(METAL, 1.15))
    elif kind == 3:  # 배관 (세로 파이프 + 이음)
        d.rectangle([23, 0, 27, 63], fill=METAL, outline=INK)
        d.line([(24, 0), (24, 63)], fill=shade(METAL, 1.2))
        for y in (12, 40):
            rect(d, 22, y, 28, y + 3, METALDK)
    return im


def wall_items():
    im = Image.new('RGBA', (16 * 4, 24), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    # 0 시계 (둥근 시계, 바늘)
    d.ellipse([1, 5, 14, 18], fill=WHITE, outline=INK)
    d.ellipse([2, 6, 13, 17], outline=FRAME)
    for (x, y) in ((7, 7), (12, 11), (7, 16), (3, 11)):
        im.putpixel((x, y), INK)
    d.line([(7, 11), (7, 8)], fill=INK)
    d.line([(7, 11), (10, 13)], fill=RED)
    # 1 공지판 (코르크 + 종이 2장)
    o = 16
    rect(d, o + 0, 4, o + 15, 19, CORK)
    d.rectangle([o + 1, 5, o + 14, 18], outline=shade(CORK, 0.75))
    d.rectangle([o + 2, 6, o + 7, 12], fill=WHITE)
    d.rectangle([o + 9, 8, o + 13, 15], fill=(0xFF, 0xE5, 0x8A, 255))
    for y in (8, 10):
        d.line([(o + 3, y), (o + 6, y)], fill=FRAME)
    im.putpixel((o + 4, 6), RED)
    im.putpixel((o + 11, 8), (0x3B, 0x82, 0xD9, 255))
    # 2 안전 포스터 (노란 바탕 + 초록 십자 + 글줄)
    o = 32
    rect(d, o + 2, 2, o + 13, 21, YEL)
    d.rectangle([o + 6, 5, o + 9, 12], fill=GREEN)
    d.rectangle([o + 4, 7, o + 11, 10], fill=GREEN)
    for y in (15, 17, 19):
        d.line([(o + 4, y), (o + 11, y)], fill=FRAME)
    # 3 소화전 함 (빨간 상자 + 유리창)
    o = 48
    rect(d, o + 1, 3, o + 14, 22, RED)
    d.rectangle([o + 3, 5, o + 12, 14], fill=shade(RED, 0.7), outline=INK)
    d.ellipse([o + 5, 7, o + 10, 12], outline=WHITE)
    d.line([(o + 3, 17), (o + 12, 17)], fill=shade(RED, 1.25))
    im.putpixel((o + 12, 19), YEL)
    return im


def floor_var():
    im = Image.new('RGBA', (32 * 4, 32), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    rnd = random.Random(7)
    # 0 얼룩 (반투명 어두운 점 무리)
    for _ in range(40):
        x, y = rnd.gauss(16, 4), rnd.gauss(16, 3)
        if 0 <= x < 32 and 0 <= y < 32:
            im.putpixel((int(x), int(y)), (0x2A, 0x24, 0x38, 34))
    # 1 금 (가는 선)
    o = 32
    pts = [(o + 6, 9), (o + 11, 13), (o + 14, 12), (o + 19, 18), (o + 24, 20)]
    d.line(pts, fill=(0x2A, 0x24, 0x38, 70))
    d.line([(o + 14, 12), (o + 15, 7)], fill=(0x2A, 0x24, 0x38, 55))
    # 2 패치 (덧댄 판)
    o = 64
    d.rectangle([o + 8, 9, o + 23, 22], fill=(0xFF, 0xFF, 0xFF, 26), outline=(0x2A, 0x24, 0x38, 50))
    for (x, y) in ((9, 10), (22, 10), (9, 21), (22, 21)):
        im.putpixel((o + x, y), (0x2A, 0x24, 0x38, 90))
    # 3 배수구 (격자 뚜껑)
    o = 96
    d.rectangle([o + 10, 11, o + 21, 20], fill=(0x6E, 0x76, 0x82, 230), outline=INK)
    for x in range(12, 21, 2):
        d.line([(o + x, 13), (o + x, 18)], fill=(0x2A, 0x24, 0x38, 255))
    return im


def main():
    walls = Image.new('RGBA', (32 * 4, 64))
    for k in range(4):
        walls.paste(wall_cell(k, 100 + k), (32 * k, 0))
    walls.save(OUT + 'wall_back.png')
    wall_items().save(OUT + 'wall_items.png')
    floor_var().save(OUT + 'floor_var.png')
    print('ok')


if __name__ == '__main__':
    main()
