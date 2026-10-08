#!/usr/bin/env python3
"""PixelLab REST v2로 도트 에셋을 만들어 assets/raw/pixellab/ 에 저장한다.

사용법 (저장소 맨 위 폴더에서):
  python tools/pixellab/pixellab_gen.py balance            # 토큰 확인, 남은 크레딧
  python tools/pixellab/pixellab_gen.py list               # 만들 수 있는 에셋 목록
  python tools/pixellab/pixellab_gen.py run staff_base     # 하나 만들기
  python tools/pixellab/pixellab_gen.py run staff_base staff_walk --push

토큰: https://www.pixellab.ai/account 에서 복사해
  tools/pixellab/.env 파일에  PIXELLAB_TOKEN=...  한 줄로 저장 (git에 올라가지 않음)
표준 라이브러리만 쓰므로 따로 설치할 것이 없다.
"""
import argparse, base64, io, json, os, re, subprocess, sys, time, urllib.request, urllib.error, zipfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
OUT = ROOT / "assets" / "raw" / "pixellab"
RAW = OUT / "_raw"
BASE = "https://api.pixellab.ai/v2"
POLL_SEC = 5
POLL_MAX = 15 * 60


def token():
    t = os.environ.get("PIXELLAB_TOKEN")
    env = HERE / ".env"
    if not t and env.exists():
        for line in env.read_text(encoding="utf-8").splitlines():
            if line.strip().startswith("PIXELLAB_TOKEN="):
                t = line.split("=", 1)[1].strip().strip('"').strip("'")
    if not t:
        sys.exit("토큰이 없어요. tools/pixellab/.env 에 PIXELLAB_TOKEN=... 을 넣어 주세요.")
    return t


def call(method, path, body=None, raw=False, ok409=False):
    url = path if path.startswith("http") else BASE + path
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, data=data, method=method)
    if not path.startswith("http") or "api.pixellab.ai" in path:
        req.add_header("Authorization", "Bearer " + token())
    req.add_header("Content-Type", "application/json")
    req.add_header("User-Agent", "saessak-hub-pixellab-script")
    last = None
    for attempt in range(3):
        try:
            with urllib.request.urlopen(req, timeout=120) as r:
                blob = r.read()
                return blob if raw else json.loads(blob.decode() or "{}")
        except urllib.error.HTTPError as e:
            msg = e.read().decode(errors="replace")
            if e.code == 409 and ok409:
                return {"_conflict": msg}
            if e.code >= 500 and method == "GET" and attempt < 2:
                # 파일 서버 일시 오류(520 등): 읽기 요청만 다시 시도
                last = f"HTTP {e.code}"
                print(f"  (서버 일시 오류 {e.code}, 다시 시도 {attempt + 1}/3)")
                time.sleep(4)
                continue
            sys.exit(f"[HTTP {e.code}] {method} {path}\n{msg[:2000]}")
        except (TimeoutError, urllib.error.URLError, ConnectionError, OSError) as e:
            last = e
            print(f"  (연결 문제, 다시 시도 {attempt + 1}/3: {e})")
            time.sleep(3)
    raise RuntimeError(f"요청 실패: {method} {path}: {last}")


def dump_raw(tag, obj):
    RAW.mkdir(parents=True, exist_ok=True)
    (RAW / f"{tag}.json").write_text(json.dumps(obj, ensure_ascii=False, indent=2), encoding="utf-8")


def load_state():
    p = OUT / "state.json"
    return json.loads(p.read_text(encoding="utf-8")) if p.exists() else {}


def save_state(st):
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / "state.json").write_text(json.dumps(st, ensure_ascii=False, indent=2), encoding="utf-8")


def fill(obj, st):
    """{이름.키} 를 앞 단계에서 저장한 값으로 바꾼다."""
    if isinstance(obj, str):
        def rep(m):
            name, key = m.group(1), m.group(2)
            if name not in st or key not in st[name]:
                sys.exit(f"먼저 '{name}' 을 만들어야 해요 ({key} 가 필요).")
            return st[name][key]
        return re.sub(r"\{([a-z0-9_]+)\.([a-z0-9_]+)\}", rep, obj)
    if isinstance(obj, list):
        return [fill(x, st) for x in obj]
    if isinstance(obj, dict):
        return {k: fill(v, st) for k, v in obj.items()}
    return obj


def save_png(blob, path):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(blob)
    print("  저장:", path.relative_to(ROOT))


def harvest(obj, folder, prefix="img", counter=None):
    """응답 안의 base64 이미지·png/gif/zip 주소를 모두 찾아 저장한다."""
    counter = counter if counter is not None else [0]
    if isinstance(obj, dict):
        for k, v in obj.items():
            harvest(v, folder, f"{prefix}_{k}" if isinstance(v, (dict, list)) else prefix + "_" + str(k), counter)
    elif isinstance(obj, list):
        for i, v in enumerate(obj):
            harvest(v, folder, f"{prefix}{i}", counter)
    elif isinstance(obj, str):
        s = obj
        if s.startswith("data:image"):
            save_png(base64.b64decode(s.split(",", 1)[1]), folder / f"{prefix}.png")
        elif re.fullmatch(r"[A-Za-z0-9+/=\s]{200,}", s) and s.strip().startswith("iVBOR"):
            save_png(base64.b64decode(s), folder / f"{prefix}.png")
        elif s.startswith("http") and re.search(r"\.(png|gif|zip)(\?|$)", s.lower()):
            ext = re.search(r"\.(png|gif|zip)", s.lower()).group(1)
            fn = folder / f"{prefix}.{ext}"
            if fn.exists():
                return
            try:
                blob = call("GET", s, raw=True)
            except Exception as e:
                print(f"  다운로드 실패(건너뜀): {fn.name}: {e}")
                return
            save_png(blob, fn)
            if ext == "zip":
                try:
                    zipfile.ZipFile(io.BytesIO(blob)).extractall(folder / (prefix + "_unzipped"))
                except Exception as e:
                    print("  zip 풀기 실패:", e)


def job_ids(resp):
    ids = []
    for k in ("background_job_id", "job_id"):
        if resp.get(k):
            ids.append(resp[k])
    for k in ("background_job_ids", "job_ids"):
        if isinstance(resp.get(k), list):
            ids += [x for x in resp[k] if isinstance(x, str)]
    return ids


def wait_job(jid):
    t0 = time.time()
    while True:
        j = call("GET", f"/background-jobs/{jid}")
        status = j.get("status")
        if status == "completed":
            return j
        if status == "failed":
            dump_raw(f"job_{jid}_failed", j)
            sys.exit(f"작업 실패: {jid}\n{json.dumps(j, ensure_ascii=False)[:1500]}")
        if time.time() - t0 > POLL_MAX:
            sys.exit(f"시간 초과: {jid}")
        print(f"  ... {status} ({int(time.time() - t0)}초)")
        time.sleep(POLL_SEC)


def push(names):
    subprocess.run(["git", "add", "assets/raw/pixellab"], cwd=ROOT, check=True)
    subprocess.run(["git", "commit", "-m", "PixelLab 에셋 추가: " + ", ".join(names)], cwd=ROOT, check=True)
    subprocess.run(["git", "push"], cwd=ROOT, check=True)


def fetch_character(name, cid):
    """캐릭터의 최종 정보·이미지·전체 내보내기(zip)를 받는다."""
    folder = OUT / name
    info = call("GET", f"/characters/{cid}")
    dump_raw(f"{name}_character", info)
    harvest(info, folder, "char")
    try:
        blob = call("GET", f"/characters/{cid}/zip", raw=True)
        folder.mkdir(parents=True, exist_ok=True)
        (folder / "export.zip").write_bytes(blob)
        zipfile.ZipFile(io.BytesIO(blob)).extractall(folder / "export")
        print("  전체 내보내기 저장:", (folder / "export").relative_to(ROOT))
    except (SystemExit, RuntimeError):
        print("  (zip 내보내기는 건너뜀)")


def run_asset(name, spec, st):
    print(f"\n== {name} ==")
    body = fill(spec["body"], st)
    if ARGS.dry_run:
        print(spec["endpoint"], json.dumps(body, ensure_ascii=False, indent=2)[:1500])
        return
    folder = OUT / name
    entry = st.setdefault(name, {})
    # 방향마다 따로 요청 (서버가 한 번에 한 방향만 만들어 줄 때를 대비)
    dirs = ARGS.dirs.split(",") if ARGS.dirs else (body.get("directions") if spec.get("per_direction") else None)
    bodies = []
    if dirs:
        for d in dirs:
            b = dict(body)
            b["directions"] = [d]
            bodies.append((d, b))
    else:
        bodies.append((None, body))
    for d, b in bodies:
        # 같은 캐릭터로 만든 애니메이션 그룹만 이어 쓴다 (기본 캐릭터를 새로 만들었으면 무시)
        if d and entry.get("animation_group_id") and entry.get("for_character") == b.get("character_id"):
            b["animation_group_id"] = entry["animation_group_id"]
        resp = call(spec.get("method", "POST"), spec["endpoint"], b, ok409=True)
        if "_conflict" in resp:
            # 이전 요청이 타임아웃 났지만 서버에선 이미 만들어졌거나 만드는 중인 방향 → 건너뜀
            print(f"  {d or ''}: 이미 있거나 생성 중이라 건너뜀. 잠시 기다립니다...")
            time.sleep(90)
            continue
        tag = f"{name}_{d}" if d else name
        dump_raw(f"{tag}_create", resp)
        print("  응답 항목:", ", ".join(f"{k}" for k in resp.keys()))
        for k in ("character_id", "object_id", "tileset_id", "animation_id", "animation_group_id", "id"):
            if isinstance(resp.get(k), str):
                entry[k] = resp[k]
        if b.get("character_id") and isinstance(resp.get("animation_group_id"), str):
            entry["for_character"] = b["character_id"]
        for jid in job_ids(resp):
            j = wait_job(jid)
            dump_raw(f"{tag}_job_{jid}", j)
            harvest(j, folder / (d or "job"), "job")
        save_state(st)
    # 타일셋이면 타일 16장과 코너 정보를 받아 둔다 (tileset_sheet.py 로 시트를 만든다)
    if spec["endpoint"] in ("/create-tileset", "/tilesets") and entry.get("tileset_id"):
        ts = call("GET", f"/tilesets/{entry['tileset_id']}")
        dump_raw(f"{name}_tileset", ts)
        folder.mkdir(parents=True, exist_ok=True)
        (folder / "tileset.json").write_text(json.dumps(ts, ensure_ascii=False, indent=2), encoding="utf-8")
        print("  타일셋 저장:", (folder / "tileset.json").relative_to(ROOT))
    # 캐릭터면 최종 정보와 전체 내보내기(zip)도 받는다
    cid = entry.get("character_id") or (st.get(spec.get("character_of", ""), {}) or {}).get("character_id")
    if cid and spec["endpoint"] in ("/create-character-v3", "/animate-character", "/characters/animations"):
        fetch_character(name, cid)
    save_state(st)


def main():
    global ARGS
    ap = argparse.ArgumentParser()
    ap.add_argument("cmd", choices=["balance", "list", "run", "fetch"])
    ap.add_argument("names", nargs="*")
    ap.add_argument("--dirs", help="방향만 골라 만들기 (예: east,north,west)")
    ap.add_argument("--dry-run", action="store_true", help="요청 내용만 보고 실제로는 보내지 않음")
    ap.add_argument("--push", action="store_true", help="끝나면 assets/raw/pixellab 을 git에 커밋·푸시")
    ARGS = ap.parse_args()
    manifest = json.loads((HERE / "manifest.json").read_text(encoding="utf-8"))

    if ARGS.cmd == "balance":
        print(json.dumps(call("GET", "/balance"), ensure_ascii=False, indent=2))
        return
    if ARGS.cmd == "list":
        for k, v in manifest.items():
            print(f"{k:16} {v['endpoint']:28} {v.get('note', '')}")
        return
    st = load_state()
    if ARGS.cmd == "fetch":
        for n in ARGS.names:
            spec = manifest.get(n, {})
            cid = (st.get(n, {}) or {}).get("character_id") or (st.get(spec.get("character_of", ""), {}) or {}).get("character_id")
            if not cid:
                sys.exit(f"{n}: 저장된 character_id 가 없어요.")
            fetch_character(n, cid)
        if ARGS.push:
            push(ARGS.names)
        return
    for n in ARGS.names:
        if n not in manifest:
            sys.exit(f"없는 에셋: {n} (list 로 확인)")
        run_asset(n, manifest[n], st)
    if ARGS.push and not ARGS.dry_run:
        push(ARGS.names)


if __name__ == "__main__":
    main()
