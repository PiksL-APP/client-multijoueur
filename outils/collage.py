"""Ce qui se touche SANS RAISON : deux meubles de familles différentes collés
l'un à l'autre se lisent comme un seul bloc — c'est le défaut du coffre, mais
il n'était pas le seul. Une file de cuisine, un lit et sa table de chevet, une
chaise sous sa table : ceux-là ont le droit de se toucher."""
import json, re, os
T='_transfert/vitrine'
cat=json.load(open(T+'/catalogue.json',encoding='utf-8'))
EMP=json.load(open(T+'/empreintes.json',encoding='utf-8'))
M=0.04; N=16
FAM=[('cuisine', r'^(kitchen(?!Bar)|hood|toaster)'),
     ('bar',     r'^(kitchenBar|stoolBar)'),
     ('lit',     r'^(bed|cabinetBed|pillow)'),
     ('repas',   r'^(table(?!Coffee)|chair(?!Desk)|bench)'),
     ('bureau',  r'^(desk|deskCorner|chairDesk|computer|laptop)'),
     ('salon',   r'^(lounge|tableCoffee|tableRound|sideTable|television|cabinetTelevision|speaker|radio)'),
     ('poubelle', r'^trashcan'),
     ('rangement', r'^(bookcase|cardboard|coatRack)'),
     ('eau',     r'^(bathroom|bath|toilet|shower|washer|dryer)'),
     ('deco',    r'^(lamp|plant|potted|bear|books|ceilingFan|rug)'),
     ('coffre',  r'^c:')]
def fam(n):
    n=n[2:] if n.startswith('n:') else n
    for f,r in FAM:
        if re.match(r,n): return f
    return 'autre'
def facteur(n): return 0.18 if n.startswith('n:') else 1.0
def cel(m):
    e=EMP[m['m']]; f=facteur(m['m'])*(m.get('t',1) or 1); lo,ech=e['lo'],e['ech']
    cx,cz=lo[0]+ech[0]/2, lo[2]+ech[2]/2; r=m['r']; out={}
    for j in range(N):
        for i in range(N):
            h=e['h'][j][i]
            if h<=0.004: continue
            u=(lo[0]+(i+0.5)/N*ech[0]-cx)*f; v=(lo[2]+(j+0.5)/N*ech[2]-cz)*f
            if r==1: u,v=v,-u
            elif r==2: u,v=-u,-v
            elif r==3: u,v=-v,u
            k=(int((m['x']+u)//M), int((m['z']+v)//M))
            y0=m.get('y',0.0); out[k]=(y0, y0+h*f)
    return out
tot=0
for id in ['taudis','ouvrier','planque','atelier','pavillon','poste','loft','penthouse']:
    f=cat[id]; ms=f['meubles']; g=[cel(m) for m in ms]; vus=[]
    for i in range(len(ms)):
        if ms[i]['m'].startswith('n:') or fam(ms[i]['m'])=='deco': continue
        for j in range(i+1,len(ms)):
            if ms[j]['m'].startswith('n:') or fam(ms[j]['m'])=='deco': continue
            if fam(ms[i]['m'])==fam(ms[j]['m']): continue
            # les hauteurs doivent se croiser, sinon l'un est posé sur l'autre
            touche=False
            for (cx,cz),(a0,a1) in g[i].items():
                for dx in (-1,0,1):
                    for dz in (-1,0,1):
                        v=g[j].get((cx+dx,cz+dz))
                        if v and not (a0>=v[1]-0.03 or a1<=v[0]+0.03): touche=True; break
                    if touche: break
                if touche: break
            if touche:
                vus.append('    %-24s (%.2f,%.2f) [%s]  colle  %-24s (%.2f,%.2f) [%s]'%(
                    ms[i]['m'],ms[i]['x'],ms[i]['z'],fam(ms[i]['m']),
                    ms[j]['m'],ms[j]['x'],ms[j]['z'],fam(ms[j]['m'])))
    tot+=len(vus); print('== %-10s %2d'%(id,len(vus)))
    if vus: print('\n'.join(vus))
print('TOTAL',tot)
