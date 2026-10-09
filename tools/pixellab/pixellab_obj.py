#!/usr/bin/env python3
"""PixelLab 오브젝트 후속 작업: 후보 고르기(select) / 같은 오브젝트의 다른 상태 만들기(state).

  python tools/pixellab/pixellab_obj.py select <에셋이름> <후보번호>
      run 으로 만든 오브젝트(검토 상태)에서 후보 하나를 완성 오브젝트로 올리고 id 를 state.json 에 저장
  python tools/pixellab/pixellab_obj.py state <원본에셋이름> <새이름> "<바꿀 내용>"
      원본(select 한 것)과 같은 모양을 유지한 채 설명대로 바꾼 상태를 만들어 assets/raw/pixellab/<새이름>/ 에 저장

요청 전마다 잔량을 확인한다. 토큰은 pixellab_gen.py 와 같은 .env 를 쓴다.
"""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import pixellab_gen as pg  # noqa: E402


def balance():
    b = pg.call("GET", "/balance")
    n = b.get("subscription", {}).get("generations")
    print(f"  잔량: {n}")
    return n


def main():
    pg.ARGS = type("A", (), {"dry_run": False, "dirs": None})()
    cmd = sys.argv[1]
    st = pg.load_state()
    if cmd == "select":
        name, idx = sys.argv[2], int(sys.argv[3])
        oid = st[name]["object_id"]
        balance()
        r = pg.call("POST", f"/objects/{oid}/select-frames", {"indices": [idx]})
        pg.dump_raw(f"{name}_select", r)
        ids = r.get("object_ids") or [o.get("id") for o in r.get("objects", []) if isinstance(o, dict)]
        if not ids:
            # 응답 모양이 다르면 문자열 id 를 아무거나 찾음
            ids = [v for v in json.dumps(r).split('"') if len(v) == 36 and v.count("-") == 4 and v != oid]
        st[name]["picked_id"] = ids[0]
        pg.save_state(st)
        print("  고른 오브젝트:", ids[0])
    elif cmd == "state":
        src, name, edit = sys.argv[2], sys.argv[3], sys.argv[4]
        oid = st[src]["picked_id"]
        before = balance()
        r = pg.call("POST", f"/objects/{oid}/states", {"edit_description": edit, "state_name": name[:20]})
        pg.dump_raw(f"{name}_create", r)
        entry = st.setdefault(name, {})
        if isinstance(r.get("object_id"), str):
            entry["object_id"] = r["object_id"]
        for jid in pg.job_ids(r):
            j = pg.wait_job(jid)
            pg.dump_raw(f"{name}_job_{jid}", j)
            pg.harvest(j, pg.OUT / name / "job", "job")
        pg.save_state(st)
        after = balance()
        print(f"  사용: {before - after}")
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main()
