import random, sys, statistics as st
# ---- config (lib/game/config.dart와 같은 값) ----
SERVE=5; PACK=5; PAT=45; OUTBOX=4; SHELF_CAP=20
DRAIN=1.5; IDLE_REST=0.3; REST=1.5; LOUNGE_DRAIN=0.2; LOUNGE_MUL=3.0; REST_BELOW=.15; REST_UNTIL=.85
OVERNIGHT=.5; SLIP_BASE=.30; SLIP_CARE=.05; SLIP_TIRED=.10
DAY=300; PARCEL_PAY=100; FULL=1.2
VEH=[(40,30,3.0,1.5),(16,12,2.0,1.2),(6,4,1.0,1.0)]  # cap,min,load/s,mul
REG_UNLOCK=[0,8000,25000,60000,150000]; REG_PAY=[1,1.3,1.7,2.2,3.0]
FEVER_FIRST=180; FEVER_MIN=300; FEVER_MAX=420; FEVER_LEN=60
VEND_CALM=.15
DT=0.5

class S:
    def __init__(s,sp,wk,kd,stm,cr,wage,role):
        s.sp,s.wk,s.kd,s.stm,s.cr,s.wage,s.role=sp,wk,kd,stm,cr,wage,role
        s.maxE=60+20*stm; s.e=s.maxE; s.rest=False; s.working=False
    @property
    def pct(s): return min(1,s.e/s.maxE)
    @property
    def fat(s): return 1 if s.pct>=.3 else .5+.5*s.pct/.3
    @property
    def rate(s): return (.6+.2*s.sp)*s.fat
    @property
    def walkmul(s): return (.7+.15*s.wk)*s.fat

def hire(rnd):
    r=lambda: min(5,1+rnd.randrange(4)+(1 if rnd.random()<.3 else 0))
    v=[r() for _ in range(5)]; t=sum(v)
    return S(*v,40+t*11,None), 600+t*250

def run(seed,days=30,verbose=False):
    rnd=random.Random(seed)
    money=20000
    staff=[S(3,2,3,3,2,100,'counter0'),S(2,3,4,2,4,110,'pack0'),S(4,4,2,4,1,130,'carrier')]
    counters=[{'crew':[staff[0]],'q':[],'out':[]}]
    packs=[{'crew':[staff[1]],'slot':None,'prog':0,'res':False}]
    shelves=1; vend=0; lounge=0
    regions=1; area=0
    money-=1500+2000+1500+3000
    stock=[0]*5; veh=None
    carriers=[staff[2]]; cjob={}  # staff->job
    t=0; day=1; spawn=2.0; fever=0; fcd=FEVER_FIRST
    earn=0; lost=0; deliv=0; log=[]; buys=[]
    plan=[('pack2',2000),('hire→pack',None),('region1',8000),('hire→carrier',None),('vending',4000),('counter2',1500),('hire→counter',None),
          ('shelf2',1500),('lounge',8000),('region2',25000),('vending2',4000),('expand1',5000),('pack3',2000),('hire→pack',None),
          ('hire→carrier',None),('shelf3',1500),('counter3',1500),('hire→counter',None),('region3',60000),('expand2',15000),
          ('hire→carrier',None),('hire→pack',None),('region4',150000)]
    pi=0; buytimer=0; dayearn=0; dayhist=[]
    pend_hire=None
    def active(b): return [s for s in b['crew'] if not s.rest]
    total_cap=lambda: shelves*SHELF_CAP
    while t<days*DAY:
        t+=DT
        for s in staff: s.working=False
        # fever
        if fever>0:
            fever-=DT
        elif counters and any(active(c) for c in counters):
            fcd-=DT
            if fcd<=0: fever=FEVER_LEN; fcd=rnd.uniform(FEVER_MIN,FEVER_MAX)
        # spawn
        live=[c for c in counters if active(c)]
        if live:
            spawn-=DT
            if spawn<=0:
                spawn=(5+rnd.random()*4)*(0.5 if fever>0 else 1)
                ncust=sum(len(c['q']) for c in counters)
                if ncust<4+len(live)*3:
                    c=min(live,key=lambda c:len(c['q']))
                    c['q'].append({'pat':PAT,'serve':0,'walk':3.0,'reg':rnd.randrange(regions)})
        # customers
        vm=1-VEND_CALM*min(2,vend)
        for c in counters:
            act=active(c)
            calm=((1.25-.1*(sum(s.kd for s in act)/len(act))) if act else 1.0)*vm
            rem=[]
            for i,cu in enumerate(c['q']):
                if cu['walk']>0: cu['walk']-=DT; 
                served=False
                if i==0 and cu['walk']<=0 and act and len(c['out'])<OUTBOX:
                    for s in act: s.working=True
                    cu['serve']+=DT*sum(s.rate for s in act); served=True
                    if cu['serve']>=SERVE:
                        c['out'].append({'reg':cu['reg']}); continue
                if not served:
                    cu['pat']-=DT*calm
                    if cu['pat']<=0: lost+=1; continue
                rem.append(cu)
            c['q']=rem
        # packs
        for p in packs:
            act=active(p)
            if p['slot'] and p['slot']['st']==2 and act:
                for s in act: s.working=True
                p['prog']+=DT*sum(s.rate for s in act)
                if p['prog']>=PACK:
                    care=sum(s.cr for s in act)/len(act)
                    ch=SLIP_BASE-SLIP_CARE*care+(SLIP_TIRED if any(s.pct<.3 for s in act) else 0)
                    if rnd.random()<max(0,min(.9,ch)): p['prog']=0
                    else: p['slot']['st']=3
        # carriers
        stored=sum(stock)
        for s in carriers:
            if s.rest: continue
            j=cjob.get(s)
            if j is None:
                best=None
                for p in packs:
                    if p['slot'] and p['slot']['st']==3 and not p['slot'].get('res') and stored<total_cap():
                        best=('pk',p); break
                if not best:
                    for c in counters:
                        fp=[p for p in packs if p['slot'] is None and not p['res'] and active(p)]
                        if c['out'] and fp: best=('ct',c,fp[0]); break
                if best:
                    spd=3.0*s.walkmul
                    if best[0]=='pk': best[1]['slot']['res']=True; cjob[s]={'k':'pk','p':best[1],'t':13/spd}
                    else:
                        parcel=best[1]['out'].pop(0); best[2]['res']=True
                        cjob[s]={'k':'ct','parcel':parcel,'p':best[2],'t':15/spd}
            j=cjob.get(s)
            if j:
                s.working=True; j['t']-=DT
                if j['t']<=0:
                    if j['k']=='pk':
                        pr=j['p']['slot']; j['p']['slot']=None; stock[pr['reg']]+=1
                    else:
                        j['p']['slot']={'st':2,'reg':j['parcel']['reg']}; j['p']['prog']=0; j['p']['res']=False
                    del cjob[s]
        # dock
        if veh is None:
            best=-1;most=0
            for r in range(regions):
                if stock[r]>most: most=stock[r]; best=r
            if best>=0:
                for cap,mn,ld,mul in VEV if False else VEH:
                    if most>=mn: veh={'r':best,'cap':cap,'ld':ld,'mul':mul,'st':0,'t':0,'acc':0,'n':0,'idle':0}; break
        else:
            v=veh; v['t']+=DT
            if v['st']==0:
                if v['t']>=1.5: v['st']=1; v['t']=0
            elif v['st']==1:
                v['acc']+=DT*v['ld']
                while v['acc']>=1 and v['n']<v['cap']:
                    v['acc']-=1
                    if stock[v['r']]>0: stock[v['r']]-=1; v['n']+=1; v['idle']=0
                    else: v['acc']=0; break
                nos=stock[v['r']]==0
                if nos: v['idle']+=DT
                if v['n']>=v['cap'] or (nos and v['idle']>=5):
                    pay=round(v['n']*PARCEL_PAY*v['mul']*REG_PAY[v['r']]*(1.5 if fever>0 else 1)*(FULL if v['n']>=v['cap'] else 1))
                    money+=pay; dayearn+=pay; deliv+=v['n']; v['st']=2; v['t']=0
            else:
                if v['t']>=1.5: veh=None
        # energy
        drain=DRAIN*(1-LOUNGE_DRAIN*min(2,lounge))
        for s in staff:
            if s.rest:
                s.e+=REST*(LOUNGE_MUL if lounge else 1)*DT
                if s.pct>=REST_UNTIL: s.rest=False
            elif s.working: s.e-=drain*DT
            else: s.e+=IDLE_REST*DT
            s.e=max(0,min(s.maxE,s.e))
            if not s.rest and s.pct<=REST_BELOW and cjob.get(s) is None: s.rest=True
        # day end
        if t>=day*DAY:
            for s in staff: s.e=min(s.maxE,s.e+s.maxE*OVERNIGHT)
            w=sum(s.wage for s in staff); money-=w if money>=w else money
            dayhist.append((day,dayearn,w,money,lost,deliv,len(staff),regions))
            dayearn=0; day+=1
        # buy
        buytimer+=DT
        if buytimer>=10 and pi<len(plan):
            buytimer=0
            name,cost=plan[pi]
            wages=sum(s.wage for s in staff)
            if name.startswith('hire'):
                if pend_hire is None: pend_hire=hire(rnd)
                ns,cost=pend_hire
                if money>=cost+wages:
                    money-=cost; staff.append(ns); pend_hire=None
                    role=name.split('→')[1]
                    if role=='carrier': carriers.append(ns)
                    elif role=='counter':
                        c=[c for c in counters if len(c['crew'])<2]; (c[0] if c else counters[0])['crew'].append(ns)
                    else:
                        p=[p for p in packs if len(p['crew'])<2]; (p[0] if p else packs[0])['crew'].append(ns)
                    buys.append((round(t/DAY,2),name)); pi+=1
            elif money>=cost+wages:
                money-=cost
                if name.startswith('region'): regions=int(name[-1])+1
                elif name.startswith('vending'): vend+=1
                elif name=='lounge': lounge+=1
                elif name.startswith('expand'): area+=1
                elif name.startswith('counter'): counters.append({'crew':[],'q':[],'out':[]})
                elif name.startswith('pack'): packs.append({'crew':[],'slot':None,'prog':0,'res':False})
                elif name.startswith('shelf'): shelves+=1
                buys.append((round(t/DAY,2),name)); pi+=1
    return dayhist,buys

if __name__=='__main__':
    seeds=range(6)
    runs=[run(s) for s in seeds]
    print("일차 | 하루수익 | 월급 | 보유금 | 놓친손님(누적) | 배송(누적) | 직원 | 열린지역")
    for d in [1,2,3,5,7,10,14,20,25,30]:
        rows=[r[0][d-1] for r in runs]
        m=lambda i: round(st.mean(x[i] for x in rows))
        print(f"{d:>3}  | {m(1):>7} | {m(2):>4} | {m(3):>7} | {m(4):>6} | {m(5):>6} | {m(6):>3} | {m(7)}")
    print("\n구매 시점(일차, 6회 평균)")
    names=[b[1] for b in runs[0][1]]
    for i,n in enumerate(names):
        vals=[r[1][i][0] for r in runs if i<len(r[1])]
        print(f"  {n:<14} {st.mean(vals):.1f}일차" if vals else f"  {n} 미구매")
