import json,struct,sys,glob,os,io
from PIL import Image
def load(p):
    b=open(p,'rb').read(); jl=struct.unpack('<I',b[12:16])[0]; j=json.loads(b[20:20+jl]); bin_=b[20+jl+8:] if len(b)>20+jl else b''
    return j,bin_
rows=[]
for p in sorted(glob.glob('assets/**/*.glb',recursive=True)):
    j,bn=load(p); tris=0; verts=0
    for m in j.get('meshes',[]):
        for pr in m['primitives']:
            a=j['accessors'][pr['attributes']['POSITION']]; verts+=a['count']
            tris+= (j['accessors'][pr['indices']]['count']//3) if 'indices' in pr else a['count']//3
    bones=max([len(s['joints']) for s in j.get('skins',[])] or [0])
    anims=[a.get('name','') for a in j.get('animations',[])]
    texs=[]
    for im in j.get('images',[]):
        if 'bufferView' in im:
            bv=j['bufferViews'][im['bufferView']]; data=bn[bv.get('byteOffset',0):bv.get('byteOffset',0)+bv['byteLength']]
            try: texs.append('x'.join(map(str,Image.open(io.BytesIO(data)).size)))
            except Exception: texs.append('?')
        else: texs.append('ext:'+im.get('uri','')[:30])
    rows.append(dict(arq=p.replace('assets/',''),kb=os.path.getsize(p)//1024,tris=tris,verts=verts,malhas=len(j.get('meshes',[])),mats=len(j.get('materials',[])),ossos=bones,anims=len(anims),anim_nomes=anims[:40],texturas=texs))
json.dump(rows,open('/tmp/inventario_glb.json','w'),ensure_ascii=False,indent=0)
for r in rows: print(f"{r['arq'][:42]:42} {r['kb']:7}KB tri={r['tris']:7} mat={r['mats']:2} ossos={r['ossos']:3} anim={r['anims']:3} tex={','.join(r['texturas'][:3])}")
