"""택배 허브 처리 능력 시뮬레이션 (게임 수치 정하기용, 0.5초 단위 이산 시뮬레이션)

단계: 손님 도착 → 접수 창구 → (운반) → 포장대 → (운반) → 선반 → (운반) → 도크 대형 트럭 → 지역센터 → 배달 차량
지금 게임 코드의 기본값을 옮겨 왔다 (config.dart): 접수 8초·포장 5초, 실수 확률, 트럭 40건, 오토바이 6건, 노선 15초 등.
"""
import random
import sys

DT = 0.5


def run(rate_pm, setup, secs=900, seed=1, deadline=240.0, truck_min=4, wait=15, verbose=False):
    rnd = random.Random(seed)
    lam = rate_pm / 60.0
    st = dict(setup)
    # 직원 능력(평균): 손속도 3 → workRate 1.2, 걸음 3 → 걸음 1.3*1.15 칸/초
    serve = st.get('serve', 12) / 1.2 / st.get('counter_mul', 1.0)  # Cfg.serveTime
    pack = 5 / 1.2 / st.get('pack_mul', 1.0)
    slip = 0.15
    # 통로(직접 설치) 위에서는 1.5배, 밖에서는 0.7배 → 구성마다 평균 걸음 배수 walk_mul
    walk = 1.3 * 1.15 * st.get('walk_mul', 1.0)
    # 운반 한 번 (빈손으로 가기 + 들고 가기) 걸리는 시간 (창고 크기에 따라 칸 수)
    leg = {'c2p': 9 / walk, 'p2s': 9 / walk, 's2d': 10 / walk}
    trip, back = st.get('trip', 15.0), st.get('trip', 15.0) * 0.8
    deliver = st.get('deliver', 8.0)
    truck_cap = st.get('truck_cap', 40)
    moto_cap = st.get('moto_cap', 6)
    outcap = st.get('outcap', 6) * st['counters']  # Cfg.outboxCap
    shelf_cap = 20 * st['shelves']

    t = 0.0
    queue = []  # 창구 앞 손님 (도착 시각)
    counters = [None] * st['counters']  # 접수 중 손님 남은 시간
    outbox = []  # 접수 완료(포장 대기) 택배: 접수 시각
    packs = [None] * st['packs']  # [남은시간, born] 또는 '예약'
    packed = []  # 포장 완료(선반 대기)
    shelf = []  # 선반 (born)
    carriers = [None] * st['carriers']  # [남은시간, 일종류, born]
    dock_truck = None  # {'load':[], 'idle':0}
    trucks = [{'state': 'home', 't': 0, 'cargo': []} for _ in range(st['trucks'])]
    center = []
    couriers = [{'state': 'home', 't': 0, 'cargo': []} for _ in range(st['couriers'])]
    lost = 0
    done = []  # (born, delivered)
    spawn = rnd.expovariate(lam) if lam > 0 else 1e9
    peak_shelf = 0
    shelf_samples = []
    while t < secs:
        t += DT
        # 손님 도착
        spawn -= DT
        while spawn <= 0:
            # 손님은 1~group 명씩 함께 온다 (평균 접수량은 같고 간격만 그만큼 길어짐)
            g = rnd.randint(1, st.get('group', 2))
            spawn += rnd.expovariate(lam / ((1 + st.get('group', 2)) / 2))
            for _ in range(g):
                if len(queue) < 4 + 3 * st['counters']:
                    queue.append(t)
                else:
                    lost += 1
        # 접수
        for i in range(len(counters)):
            if counters[i] is None and queue and len(outbox) < outcap:
                queue.pop(0)
                counters[i] = [serve, t]
            if counters[i] is not None:
                counters[i][0] -= DT
                if counters[i][0] <= 0:
                    outbox.append(counters[i][1])
                    counters[i] = None
        # 인내심 (Cfg.patience)
        while queue and t - queue[0] > st.get('patience', 60):
            queue.pop(0)
            lost += 1
        # 포장
        for i in range(len(packs)):
            p = packs[i]
            if isinstance(p, list):
                p[0] -= DT
                if p[0] <= 0:
                    if rnd.random() < slip:
                        p[0] = pack
                    else:
                        packed.append(p[1])
                        packs[i] = None
        # 운반: 적재 > 선반으로 > 포장대로
        for i in range(len(carriers)):
            c = carriers[i]
            if c is not None:
                c[0] -= DT
                if c[0] <= 0:
                    kind, born, extra = c[1], c[2], c[3]
                    if kind == 'c2p':
                        packs[extra] = [pack, born]
                    elif kind == 'p2s':
                        shelf.append(born)
                    elif kind == 's2d' and dock_truck is not None:
                        dock_truck['load'].append(born)
                        dock_truck['incoming'] -= 1
                    carriers[i] = None
                continue
            if dock_truck is not None and shelf and len(dock_truck['load']) + dock_truck['incoming'] < truck_cap:
                b = shelf.pop(0)
                dock_truck['incoming'] += 1
                carriers[i] = [leg['s2d'], 's2d', b, None]
            elif packed and len(shelf) + 1 <= shelf_cap + 5:
                carriers[i] = [leg['p2s'], 'p2s', packed.pop(0), None]
            elif outbox:
                free = [k for k in range(len(packs)) if packs[k] is None]
                if free:
                    packs[free[0]] = 'res'
                    carriers[i] = [leg['c2p'], 'c2p', outbox.pop(0), free[0]]
        # 도크: 선반에 truck_min 이상 쌓이면(또는 80% 차면) 놀고 있는 트럭을 부름
        if dock_truck is None:
            home = [k for k in trucks if k['state'] == 'home']
            crowded = len(shelf) >= shelf_cap * 0.8
            if home and len(shelf) >= (1 if crowded else truck_min):
                dock_truck = {'load': [], 'incoming': 0, 'idle': 0, 'unit': home[0]}
                home[0]['state'] = 'dock'
        else:
            no = not shelf and dock_truck['incoming'] == 0
            dock_truck['idle'] = dock_truck['idle'] + DT if no else 0
            if len(dock_truck['load']) >= truck_cap or (no and dock_truck['idle'] >= wait):
                u = dock_truck['unit']
                u['cargo'] = dock_truck['load']
                u['state'] = 'go'
                u['t'] = trip + 1.5
                dock_truck = None
        for u in trucks:
            if u['state'] in ('go', 'back'):
                u['t'] -= DT
                if u['t'] <= 0:
                    if u['state'] == 'go':
                        center.extend(u['cargo'])
                        u['cargo'] = []
                        u['state'] = 'back'
                        u['t'] = back
                    else:
                        u['state'] = 'home'
        for u in couriers:
            if u['state'] == 'home' and center:
                u['cargo'] = center[:moto_cap]
                del center[:moto_cap]
                u['state'] = 'go'
                u['t'] = deliver
            elif u['state'] in ('go', 'back'):
                u['t'] -= DT
                if u['t'] <= 0:
                    if u['state'] == 'go':
                        done.extend((b, t) for b in u['cargo'])
                        u['state'] = 'back'
                        u['t'] = deliver * 0.7
                    else:
                        u['state'] = 'home'
        peak_shelf = max(peak_shelf, len(shelf))
        if int(t) % 30 == 0 and t == int(t):
            shelf_samples.append(len(shelf) + len(packed) + len(outbox))
    late = sum(1 for b, d in done if d - b > deadline)
    lat = sorted(d - b for b, d in done)
    p90 = lat[int(len(lat) * 0.9)] if lat else 0
    backlog = len(queue) + len(outbox) + len(packed) + len(shelf) + len(center)
    first = sum(shelf_samples[: len(shelf_samples) // 3]) / max(1, len(shelf_samples) // 3)
    last = sum(shelf_samples[-len(shelf_samples) // 3:]) / max(1, len(shelf_samples) // 3)
    return dict(arrive=rate_pm * secs / 60, done=len(done), lost=lost, late=late, p90=round(p90),
                backlog=backlog, peak_shelf=peak_shelf, grow=round(last - first, 1))


START = dict(counters=1, packs=1, carriers=1, shelves=1, trucks=1, couriers=1)
MID = dict(counters=2, packs=2, carriers=2, shelves=2, trucks=1, couriers=2)
BIG = dict(counters=3, packs=3, carriers=4, shelves=4, trucks=2, couriers=3)

if __name__ == '__main__':
    rates = [float(x) for x in sys.argv[1:]] or [1.5, 2, 3, 4, 6, 8, 10, 14, 18]
    for name, su in (('시작(1/1/1)', START), ('중간(2/2/2)', MID), ('투자(3/3/4)', BIG)):
        print(f'== {name} ==')
        for r in rates:
            res = [run(r, su, seed=s) for s in range(4)]
            avg = {k: round(sum(x[k] for x in res) / len(res), 1) for k in res[0]}
            print(f'분당 {r:>4}: 처리 {avg["done"]:>5}/{avg["arrive"]:>5}  놓침 {avg["lost"]:>5}  '
                  f'지각 {avg["late"]:>5}  p90 {avg["p90"]:>5}초  남은물량 {avg["backlog"]:>5}  '
                  f'선반최대 {avg["peak_shelf"]:>5}  쌓임추세 {avg["grow"]:>5}')
