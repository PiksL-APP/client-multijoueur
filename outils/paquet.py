#!/usr/bin/env python3
"""Le paquet de géométrie du kit, pour l'éditeur 3D web (« l'Établi »).

Lit les 202 glTF des deux kits Kenney, aplatit chaque modèle en groupes par NOM
DE MATIÈRE (c'est par ce nom que les intérieurs se repeignent), bake les
transformations de nœuds dans les sommets, quantifie positions et normales, et
sort un tampon unique gzippé en base64 plus son index.

Pourquoi ne pas envoyer les .glb au navigateur : 4,2 Mo de fichiers, un
analyseur glTF à écrire côté page, et des matières à retrouver. Aplati et
quantifié, le même contenu tient en 0,3 Mo que `DecompressionStream` détend
tout seul, et la page n'a plus qu'à découper des tableaux typés.

    python3 outils/paquet.py
        -> _transfert/vitrine/paquet.b64 + paquet-index.json
"""
import json, struct, os, glob, math, gzip, base64, array

COMP = {5120:('b',1),5121:('B',1),5122:('h',2),5123:('H',2),5125:('I',4),5126:('f',4)}
NCOMP = {'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}

def lire_glb(p):
    d=open(p,'rb').read()
    ln=struct.unpack('<I',d[12:16])[0]
    j=json.loads(d[20:20+ln])
    off=20+ln
    bin_=b''
    while off<len(d):
        cl,ct=struct.unpack('<II',d[off:off+8])
        if ct==0x004E4942: bin_=d[off+8:off+8+cl]
        off+=8+cl
    return j,bin_

def accesseur(j,bin_,i):
    a=j['accessors'][i]
    n=NCOMP[a['type']]; fmt,sz=COMP[a['componentType']]
    bv=j['bufferViews'][a.get('bufferView',0)]
    base=bv.get('byteOffset',0)+a.get('byteOffset',0)
    stride=bv.get('byteStride') or n*sz
    out=[]
    for k in range(a['count']):
        o=base+k*stride
        out.append(struct.unpack_from('<'+fmt*n,bin_,o))
    return out

def mm(a,b):
    return [[sum(a[i][k]*b[k][j] for k in range(4)) for j in range(4)] for i in range(4)]
def trs(nd):
    if 'matrix' in nd:
        m=nd['matrix']; return [[m[c*4+r] for c in range(4)] for r in range(4)]
    t=nd.get('translation',[0,0,0]); r=nd.get('rotation',[0,0,0,1]); s=nd.get('scale',[1,1,1])
    x,y,z,w=r
    R=[[1-2*(y*y+z*z),2*(x*y-z*w),2*(x*z+y*w)],[2*(x*y+z*w),1-2*(x*x+z*z),2*(y*z-x*w)],[2*(x*z-y*w),2*(y*z+x*w),1-2*(x*x+y*y)]]
    M=[[R[i][k]*s[k] for k in range(3)]+[t[i]] for i in range(3)]
    M.append([0,0,0,1]); return M

def lire_modele(p):
    j,bin_=lire_glb(p)
    nodes=j.get('nodes',[]); meshes=j.get('meshes',[]); mats=j.get('materials',[])
    groupes={}
    def walk(i,P):
        nd=nodes[i]; M=mm(P,trs(nd))
        if 'mesh' in nd:
            for pr in meshes[nd['mesh']]['primitives']:
                nom = mats[pr['material']]['name'] if 'material' in pr else '_defaultMat'
                pos=accesseur(j,bin_,pr['attributes']['POSITION'])
                nor=accesseur(j,bin_,pr['attributes']['NORMAL']) if 'NORMAL' in pr['attributes'] else [(0,1,0)]*len(pos)
                uv=accesseur(j,bin_,pr['attributes']['TEXCOORD_0']) if 'TEXCOORD_0' in pr['attributes'] else None
                idx=[v[0] for v in accesseur(j,bin_,pr['indices'])] if 'indices' in pr else list(range(len(pos)))
                g=groupes.setdefault(nom,{'p':[],'n':[],'u':[],'i':[],'uv':uv is not None})
                dec=len(g['p'])//3
                for k,(px,py,pz) in enumerate(pos):
                    g['p'] += [M[0][0]*px+M[0][1]*py+M[0][2]*pz+M[0][3],
                               M[1][0]*px+M[1][1]*py+M[1][2]*pz+M[1][3],
                               M[2][0]*px+M[2][1]*py+M[2][2]*pz+M[2][3]]
                    nx,ny,nz=nor[k]
                    tx=M[0][0]*nx+M[0][1]*ny+M[0][2]*nz
                    ty=M[1][0]*nx+M[1][1]*ny+M[1][2]*nz
                    tz=M[2][0]*nx+M[2][1]*ny+M[2][2]*nz
                    L=math.sqrt(tx*tx+ty*ty+tz*tz) or 1.0
                    g['n'] += [tx/L,ty/L,tz/L]
                    if uv is not None: g['u'] += [uv[k][0],uv[k][1]]
                g['i'] += [v+dec for v in idx]
        for c in nd.get('children',[]): walk(c,M)
    I=[[1,0,0,0],[0,1,0,0],[0,0,1,0],[0,0,0,1]]
    for s in j['scenes'][j.get('scene',0)]['nodes']: walk(s,I)
    couleurs={m['name']:[round(x,4) for x in m.get('pbrMetallicRoughness',{}).get('baseColorFactor',[1,1,1,1])] for m in mats}
    return groupes,couleurs

tampon=bytearray()
index={'materiaux':{},'modeles':{}}
def ecrire(fmt,vals):
    o=len(tampon)
    tampon.extend(array.array(fmt,vals).tobytes())
    return o

racine=os.path.expanduser('~/mnt/client-multijoueur/modeles/kenney')
fichiers=([('',f) for f in sorted(glob.glob(racine+'/interieur/*.glb'))]
          + [('n:',f) for f in sorted(glob.glob(racine+'/nourriture/*.glb'))]
          # ce qui n'est pas Kenney : le coffre, fabriqué par outils/coffre.py
          + [('c:',f) for f in sorted(glob.glob(os.path.expanduser('~/mnt/client-multijoueur/modeles/interieur/*.glb')))])
for prefixe,f in fichiers:
    nom=prefixe+os.path.basename(f)[:-4]
    groupes,couleurs=lire_modele(f)
    index['materiaux'].update({k:v for k,v in couleurs.items() if k not in index['materiaux']})
    lo=[1e9]*3; hi=[-1e9]*3
    for g in groupes.values():
        for k in range(0,len(g['p']),3):
            for c in range(3):
                lo[c]=min(lo[c],g['p'][k+c]); hi[c]=max(hi[c],g['p'][k+c])
    ech=[max(hi[c]-lo[c],1e-6) for c in range(3)]
    fiche={'lo':[round(v,5) for v in lo],'ech':[round(v,5) for v in ech],'g':[]}
    for m,g in groupes.items():
        nv=len(g['p'])//3
        q=[]
        for k in range(nv):
            for c in range(3):
                q.append(max(0,min(65535,int(round((g['p'][k*3+c]-lo[c])/ech[c]*65535)))))
        po=ecrire('H',q)
        no=ecrire('b',[max(-127,min(127,int(round(v*127)))) for v in g['n']])
        uo=-1
        if g['uv']:
            uo=ecrire('H',[max(0,min(65535,int(round(v*65535)))) for v in g['u']])
        io=ecrire('H' if nv<65536 else 'I',g['i'])
        fiche['g'].append({'m':m,'nv':nv,'ni':len(g['i']),'po':po,'no':no,'uo':uo,'io':io,'i32':nv>=65536})
    fiche['tex']=nom.startswith('n:')
    index['modeles'][nom]=fiche

brut=bytes(tampon)
comp=gzip.compress(brut,9)
d='/sessions/'+os.environ.get('USER','')+''
sortie=os.path.expanduser('~/mnt/client-multijoueur/_transfert/vitrine')
open(sortie+'/paquet.b64','w').write(base64.b64encode(comp).decode())
json.dump(index,open(sortie+'/paquet-index.json','w'),separators=(',',':'))
print('brut %.2f Mo — gzip %.2f Mo — base64 %.2f Mo — %d modèles' % (len(brut)/1048576,len(comp)/1048576,len(comp)*1.34/1048576,len(index['modeles'])))
import json, struct, os, glob, math, gzip, base64, array

COMP = {5120:('b',1),5121:('B',1),5122:('h',2),5123:('H',2),5125:('I',4),5126:('f',4)}
NCOMP = {'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}

def lire_glb(p):
    d=open(p,'rb').read()
    ln=struct.unpack('<I',d[12:16])[0]
    j=json.loads(d[20:20+ln])
    off=20+ln
    bin_=b''
    while off<len(d):
        cl,ct=struct.unpack('<II',d[off:off+8])
        if ct==0x004E4942: bin_=d[off+8:off+8+cl]
        off+=8+cl
    return j,bin_

def accesseur(j,bin_,i):
    a=j['accessors'][i]
    n=NCOMP[a['type']]; fmt,sz=COMP[a['componentType']]
    bv=j['bufferViews'][a.get('bufferView',0)]
    base=bv.get('byteOffset',0)+a.get('byteOffset',0)
    stride=bv.get('byteStride') or n*sz
    out=[]
    for k in range(a['count']):
        o=base+k*stride
        out.append(struct.unpack_from('<'+fmt*n,bin_,o))
    return out

def mm(a,b):
    return [[sum(a[i][k]*b[k][j] for k in range(4)) for j in range(4)] for i in range(4)]
def trs(nd):
    if 'matrix' in nd:
        m=nd['matrix']; return [[m[c*4+r] for c in range(4)] for r in range(4)]
    t=nd.get('translation',[0,0,0]); r=nd.get('rotation',[0,0,0,1]); s=nd.get('scale',[1,1,1])
    x,y,z,w=r
    R=[[1-2*(y*y+z*z),2*(x*y-z*w),2*(x*z+y*w)],[2*(x*y+z*w),1-2*(x*x+z*z),2*(y*z-x*w)],[2*(x*z-y*w),2*(y*z+x*w),1-2*(x*x+y*y)]]
    M=[[R[i][k]*s[k] for k in range(3)]+[t[i]] for i in range(3)]
    M.append([0,0,0,1]); return M

def lire_modele(p):
    j,bin_=lire_glb(p)
    nodes=j.get('nodes',[]); meshes=j.get('meshes',[]); mats=j.get('materials',[])
    groupes={}
    def walk(i,P):
        nd=nodes[i]; M=mm(P,trs(nd))
        if 'mesh' in nd:
            for pr in meshes[nd['mesh']]['primitives']:
                nom = mats[pr['material']]['name'] if 'material' in pr else '_defaultMat'
                pos=accesseur(j,bin_,pr['attributes']['POSITION'])
                nor=accesseur(j,bin_,pr['attributes']['NORMAL']) if 'NORMAL' in pr['attributes'] else [(0,1,0)]*len(pos)
                uv=accesseur(j,bin_,pr['attributes']['TEXCOORD_0']) if 'TEXCOORD_0' in pr['attributes'] else None
                idx=[v[0] for v in accesseur(j,bin_,pr['indices'])] if 'indices' in pr else list(range(len(pos)))
                g=groupes.setdefault(nom,{'p':[],'n':[],'u':[],'i':[],'uv':uv is not None})
                dec=len(g['p'])//3
                for k,(px,py,pz) in enumerate(pos):
                    g['p'] += [M[0][0]*px+M[0][1]*py+M[0][2]*pz+M[0][3],
                               M[1][0]*px+M[1][1]*py+M[1][2]*pz+M[1][3],
                               M[2][0]*px+M[2][1]*py+M[2][2]*pz+M[2][3]]
                    nx,ny,nz=nor[k]
                    tx=M[0][0]*nx+M[0][1]*ny+M[0][2]*nz
                    ty=M[1][0]*nx+M[1][1]*ny+M[1][2]*nz
                    tz=M[2][0]*nx+M[2][1]*ny+M[2][2]*nz
                    L=math.sqrt(tx*tx+ty*ty+tz*tz) or 1.0
                    g['n'] += [tx/L,ty/L,tz/L]
                    if uv is not None: g['u'] += [uv[k][0],uv[k][1]]
                g['i'] += [v+dec for v in idx]
        for c in nd.get('children',[]): walk(c,M)
    I=[[1,0,0,0],[0,1,0,0],[0,0,1,0],[0,0,0,1]]
    for s in j['scenes'][j.get('scene',0)]['nodes']: walk(s,I)
    couleurs={m['name']:[round(x,4) for x in m.get('pbrMetallicRoughness',{}).get('baseColorFactor',[1,1,1,1])] for m in mats}
    return groupes,couleurs

tampon=bytearray()
index={'materiaux':{},'modeles':{}}
def ecrire(fmt,vals):
    o=len(tampon)
    tampon.extend(array.array(fmt,vals).tobytes())
    return o

racine=os.path.expanduser('~/mnt/client-multijoueur/modeles/kenney')
fichiers=([('',f) for f in sorted(glob.glob(racine+'/interieur/*.glb'))]
          + [('n:',f) for f in sorted(glob.glob(racine+'/nourriture/*.glb'))]
          # ce qui n'est pas Kenney : le coffre, fabriqué par outils/coffre.py
          + [('c:',f) for f in sorted(glob.glob(os.path.expanduser('~/mnt/client-multijoueur/modeles/interieur/*.glb')))])
for prefixe,f in fichiers:
    nom=prefixe+os.path.basename(f)[:-4]
    groupes,couleurs=lire_modele(f)
    index['materiaux'].update({k:v for k,v in couleurs.items() if k not in index['materiaux']})
    lo=[1e9]*3; hi=[-1e9]*3
    for g in groupes.values():
        for k in range(0,len(g['p']),3):
            for c in range(3):
                lo[c]=min(lo[c],g['p'][k+c]); hi[c]=max(hi[c],g['p'][k+c])
    ech=[max(hi[c]-lo[c],1e-6) for c in range(3)]
    fiche={'lo':[round(v,5) for v in lo],'ech':[round(v,5) for v in ech],'g':[]}
    for m,g in groupes.items():
        nv=len(g['p'])//3
        q=[]
        for k in range(nv):
            for c in range(3):
                q.append(max(0,min(65535,int(round((g['p'][k*3+c]-lo[c])/ech[c]*65535)))))
        po=ecrire('H',q)
        no=ecrire('b',[max(-127,min(127,int(round(v*127)))) for v in g['n']])
        uo=-1
        if g['uv']:
            uo=ecrire('H',[max(0,min(65535,int(round(v*65535)))) for v in g['u']])
        io=ecrire('H' if nv<65536 else 'I',g['i'])
        fiche['g'].append({'m':m,'nv':nv,'ni':len(g['i']),'po':po,'no':no,'uo':uo,'io':io,'i32':nv>=65536})
    fiche['tex']=nom.startswith('n:')
    index['modeles'][nom]=fiche

brut=bytes(tampon)
comp=gzip.compress(brut,9)
d='/sessions/'+os.environ.get('USER','')+''
sortie=os.path.expanduser('~/mnt/client-multijoueur/_transfert/vitrine')
open(sortie+'/paquet.b64','w').write(base64.b64encode(comp).decode())
json.dump(index,open(sortie+'/paquet-index.json','w'),separators=(',',':'))
print('brut %.2f Mo — gzip %.2f Mo — base64 %.2f Mo — %d modèles' % (len(brut)/1048576,len(comp)/1048576,len(comp)*1.34/1048576,len(index['modeles'])))
