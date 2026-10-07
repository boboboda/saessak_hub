# PixelLab 에셋 생성 스크립트

1. https://www.pixellab.ai/account 에서 API 토큰을 복사한다.
2. `tools/pixellab/.env` 파일을 만들고 한 줄 저장:  `PIXELLAB_TOKEN=복사한토큰`
   (이 파일은 git에 올라가지 않는다)
3. 저장소 맨 위 폴더에서:
   ```
   python3 tools/pixellab/pixellab_gen.py balance                 # 연결·크레딧 확인
   python3 tools/pixellab/pixellab_gen.py run staff_base --dry-run # 보낼 내용만 확인
   python3 tools/pixellab/pixellab_gen.py run staff_base staff_walk --push
   ```
4. 결과는 `assets/raw/pixellab/<이름>/` 에 저장되고, `--push` 를 붙이면 자동으로 커밋·푸시한다.
5. 에러가 나면 화면에 나온 메시지를 그대로 알려 주면 된다. (`assets/raw/pixellab/_raw/` 에 서버 응답 원본이 남는다.)

크레딧이 쓰이므로 처음에는 `balance` → `run staff_base` 순서로 하나씩 해 본다.
에셋 설명·크기는 `manifest.json` 에서 고친다.
