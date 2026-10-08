# PixelLab 도트 에셋 제작 가이드 (택배회사 키우기 기준, 다른 작업창 공유용)

이 문서는 "PixelLab으로 도트 에셋을 뽑아 게임에 붙이는 방법"을 처음 보는 Claude/사람이 바로 이어서 작업할 수 있게 정리한 것이다.
저장소: `boboboda/saessak_hub` (Flutter + Flame, Android 우선). 모든 작업은 `main`에 바로 푸시한다.

## 1. 역할 분담 (왜 이렇게 하나)
- Claude 작업 환경(클라우드 샌드박스)은 PixelLab API에 **접속할 수 없다** (shell 403). WebFetch/WebSearch만 된다.
- 그래서 **사용자가 자기 Mac에서 스크립트를 실행**해 PixelLab을 호출하고, 결과 PNG를 저장소에 `--push`로 올린다.
- Claude는 `git pull`로 받아서 **후보 미리보기 → 고르기 → 잘라내기 → 게임 코드에 붙이기**를 한다.
- 흐름: `manifest.json에 항목 추가` → (사용자) `python3 ... run 이름 --push` → (Claude) pull, 미리보기, 선택, 적용, 푸시.

## 2. 계정/요금
- 토큰: https://www.pixellab.ai/account 의 API token. 사용자 Mac의 `tools/pixellab/.env`에 `PIXELLAB_TOKEN=...` (gitignore됨, 절대 커밋 금지).
- 무료 체험은 40 generations이고 **오브젝트 1건이 약 20회씩** 먹어서 몇 번 만에 바닥난다. 현재는 **Tier 1 ($12/월, 2000 generations)** 구독 중. 구독 크레딧이 API에도 적용되는 것 확인됨.
- 잔량 확인: `python3 tools/pixellab/pixellab_gen.py balance`
- 상업 이용 조건은 제3자 리뷰 기준 "모든 플랜 포함"이지만 **공식 약관 원문은 미확인** → 출시 전 사용자가 직접 확인.

## 3. 스크립트 사용법 (tools/pixellab/pixellab_gen.py)
```
python3 tools/pixellab/pixellab_gen.py balance                     # 잔량
python3 tools/pixellab/pixellab_gen.py list                        # manifest 항목 목록
python3 tools/pixellab/pixellab_gen.py run 이름1 이름2 --push      # 생성 + 저장 + 커밋/푸시
python3 tools/pixellab/pixellab_gen.py run 이름 --dirs east,west   # (애니메이션) 방향 지정
python3 tools/pixellab/pixellab_gen.py run 이름 --dry-run          # 요청 내용만 출력
python3 tools/pixellab/pixellab_gen.py fetch 이름 --push           # (캐릭터 전용) 이미 만든 걸 다시 받기
```
- 항목은 `tools/pixellab/manifest.json`에 `{endpoint, note, body, ...}` 형태로 적는다.
- 결과는 `assets/raw/pixellab/<이름>/`에 저장(원본 보관용), 상태는 `assets/raw/pixellab/state.json`.
- **같은 이름을 다시 `run`하면 이미 있는 파일은 건너뛴다** → 다시 뽑고 싶으면 `이름2`처럼 **새 항목 이름**을 쓴다 (예: `obj_shelf2`).
- 한 건이 1~4분 걸린다. 다운로드 타임아웃은 3회 재시도, 실패해도 계속 진행한다.
- 한 번에 여러 개를 돌리는 건 괜찮지만, 크레딧이 걱정되면 하나 돌려서 `balance`로 소모량부터 본다.

## 4. 엔드포인트별 주의사항 (직접 겪은 것)
Base URL `https://api.pixellab.ai/v2`, 헤더 `Authorization: Bearer <token>`. 스펙: `/openapi.json`.

| 용도 | 엔드포인트 | 핵심 |
|---|---|---|
| 캐릭터(8방향) | `POST /create-character-v3` | `description, image_size{width,height}, view, outline, detail`. **`shading` 필드는 422(허용 안 됨)**. 결과 `character_id`가 state.json에 저장됨 |
| 걷기 등 애니메이션 | `POST /animate-character` | mode v3. `directions` 배열을 줘도 **서버가 한 요청에 한 방향만 처리** → **방향별로 따로 요청**(`--dirs`). 프레임은 6 요청해도 **7장** 나옴 |
| 오브젝트/소품 | `POST /create-1-direction-object` | **`size`는 정수 하나(정사각형)**. `image_size{...}`를 보내면 422. 비정사각은 못 만든다 |
| 작업 조회 | `GET /background-jobs/{id}` | `status`: processing/completed/failed |
| 캐릭터 조회/내보내기 | `GET /characters/{id}`, `/characters/{id}/zip` | 회전/애니메이션 이미지, zip |

### 오브젝트 후보 개수 = size에 따라 다름
- size 32 → **후보 64장**, 64 → **16장**, 96/128 → **4장**.
- 즉 한 번 생성하면 후보 여럿이 오므로 **전부 미리보기 시트로 펼쳐 놓고 하나 고른다**(스타일 일관성 위해 비슷한 계열로).
- 생성 1건당 약 20 generations (박스 기준 확인). 후보가 많아도 요금은 건당.

## 5. 프롬프트 요령 (우리 게임 기준으로 효과 있었던 것)
- 프롬프트 앞에 스타일 고정 문구를 붙인다: `pixel art, black outline, front view, flat orthographic, no perspective, ...`
- **"top-down"이라고 써도 3/4 쿼터뷰(비스듬)로 나온다.** 정면이 필요하면 `front view, straight on, symmetrical`을 명시 (선반이 대각선으로 나와서 정면으로 다시 뽑음).
- 한 가지만 그리도록 구체적으로: `empty ... nothing on the shelves`, `single closed cardboard box` 등.
- **바닥 타일(seamless tile)은 이 엔드포인트로 안 된다** (조각난 타일이 나옴). 바닥/잔디/아스팔트는 **직접 코드(PIL)로 절차 생성**했다 (`assets/sprites/tiles/*.png`).
- 이음매 있는 땅 타일은 **`POST /create-tileset`** 으로 만든다 (Wang 코너 16장, 1건 약 2~4회로 저렴). `lower_description`/`upper_description`, `tile_size{32,32}`, `view: high top-down`, `outline/shading/detail`은 정해진 문자열(openapi 참고). 결과 이미지는 작업 응답이 아니라 `GET /tilesets/{tileset_id}`에 있다 → 스크립트가 `tileset.json`으로 저장, `tools/pixellab/tileset_sheet.py`로 코너 번호(NW*8+NE*4+SW*2+SE) 순 시트로 변환. 색이 튀면 `lower_reference_image`/`upper_reference_image`에 기존 타일을 넣으면 톤이 맞는다.
- 64 크기 오브젝트 후보 중 일부는 **옆 후보 조각이 캔버스 가장자리에 붙어** 온다 → 빈 열로 나뉜 덩어리 중 가장 넓은 것만 남기고 자른다.
- 배경이 투명 PNG로 오며, 후보 이미지는 캔버스에 여백이 있다 → **bbox로 잘라서(`im.crop(im.getbbox())`) 저장**.
- 캐릭터는 한 번 만든 `character_id`를 기준으로 애니메이션을 붙여야 외형이 일관된다.

## 6. 이 프로젝트의 스타일 기준
- **타일 크기 32px** (`Cfg.tile = 32`). 도트를 **원본 크기 1:1(정수배)**로 그린다 (`FilterQuality.none`).
- 캐릭터: 48x48 베이스, 걷기 프레임 56x56. 주황 안전조끼 + 남색 모자, 얇은 검은 외곽선, 중간 디테일. 방향은 남/서/동/북 4방향 x 7프레임.
- 오브젝트: 검은 외곽선, 정면~약간 위에서 본 3/4 시점. 건물 크기: 창구 2x1칸(64x32), 포장대 2x2(64x64), 선반 2x3(64x96).
- 색: 주황(접수), 초록(포장), 파랑(보관·출고), 갈색 골판지 박스.

## 7. 게임에 붙이는 방법 (코드)
- 최종 이미지는 `assets/sprites/{staff,props,tiles,decor}/`에 두고 `pubspec.yaml`의 `assets:`에 폴더가 등록돼 있다. (원본 후보는 `assets/raw/`에만.)
- 로더: `lib/game/sprites.dart` (`Sprites.load()` — 이미지가 없거나 읽기 실패하면 `null` → 기존 도형으로 그려지는 **폴백**).
- 그리기: `lib/ui/world_view.dart` (직원 `_person`, 건물 `_drawBuildings`, 장식 `_drawDecor`, 도로/마당 `_drawRoadAndYard`).
- 배경 장식 배치: `lib/game/scenery.dart` (고정 시드, 도로/마당 피함, 현재 창고와 겹치면 숨김). 새 장식은 `Sprites.decorNames`에 이름 추가 + `assets/sprites/decor/<이름>.png`.
- 방향 판단: 직원의 이동량(dx,dy)으로 남/서/동/북 선택, 움직일 때만 걷기 프레임. 가만히 서 있으면 정면 대기.
- 책상 뒤에 서 있는 연출: 직원을 그린 뒤 책상 스프라이트 앞면을 다시 덮어 그린다.

## 8. 지금까지 만든 것 / 남은 것
- 완료: 직원 8방향 + 걷기 4방향, 택배 박스, 접수 창구, 포장대, 선반(정면), 트럭, 장식(나무·덤불·꽃·벤치·가로등·신호등·라바콘·표지판·팔레트·가게/집 3종).
- 후보 풀은 `assets/raw/pixellab/<이름>/job/`에 그대로 남아 있어 다른 후보로 교체 가능.
- 남은 후보: 손님 캐릭터, 작업 동작 애니메이션(접수/포장), 오토바이/소형 트럭 구분, 자판기·휴게실, 이펙트 등.

## 9. 흔한 실수 체크리스트
1. 오브젝트에 `image_size`를 쓰면 422 → `size`(정수).
2. 캐릭터에 `shading`을 쓰면 422.
3. 애니메이션 방향을 한 번에 여러 개 주면 한 방향만 옴 → `--dirs`로 나눠 호출.
4. 같은 이름을 다시 `run`하면 건너뜀 → 새 이름으로.
5. 타일/바닥은 PixelLab 말고 코드로.
6. 크레딧이 한 번에 크게 빠질 수 있다 → 하나씩 돌려 `balance` 확인.
7. 토큰(`.env`)은 절대 커밋하지 않는다.
8. Claude 환경에서는 PixelLab 호출 불가 → 사용자 Mac에서 실행.
