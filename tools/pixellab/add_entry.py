#!/usr/bin/env python3
"""manifest.json 에 오브젝트 에셋 항목을 추가한다 (스타일 참조 그림을 base64 로 넣음).

  python tools/pixellab/add_entry.py <이름> "<설명>" [--ref 그림.png] [--size 64] [--note 메모]

--ref 를 주면 그 그림을 정사각형(64 또는 128) 투명 캔버스 가운데에 놓아 style_images 로 넘긴다.
(PixelLab 은 참조 그림 크기를 출력 크기로 쓴다.)
"""
import argparse
import base64
import io
import json
from pathlib import Path

from PIL import Image

HERE = Path(__file__).resolve().parent


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('name')
    ap.add_argument('desc')
    ap.add_argument('--ref')
    ap.add_argument('--size', type=int, default=64)
    ap.add_argument('--note', default='')
    ap.add_argument('--view')
    a = ap.parse_args()
    body = {'description': a.desc}
    if a.ref:
        im = Image.open(a.ref).convert('RGBA')
        k = min(1.0, a.size / im.width, a.size / im.height)
        if k < 1:
            im = im.resize((int(im.width * k), int(im.height * k)), Image.NEAREST)
        cv = Image.new('RGBA', (a.size, a.size), (0, 0, 0, 0))
        cv.paste(im, ((a.size - im.width) // 2, (a.size - im.height) // 2))
        buf = io.BytesIO()
        cv.save(buf, 'PNG')
        body['style_images'] = [{'type': 'base64', 'base64': base64.b64encode(buf.getvalue()).decode()}]
    else:
        body['size'] = a.size
    if a.view:
        body['view'] = a.view
    p = HERE / 'manifest.json'
    m = json.loads(p.read_text(encoding='utf-8'))
    m[a.name] = {'endpoint': '/create-1-direction-object', 'note': a.note, 'body': body}
    p.write_text(json.dumps(m, ensure_ascii=False, indent=2), encoding='utf-8')
    print('added', a.name)


if __name__ == '__main__':
    main()
