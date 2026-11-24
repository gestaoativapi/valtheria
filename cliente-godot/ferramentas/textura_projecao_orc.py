import sys,trimesh,numpy as np
from PIL import Image
key,frente,folha=sys.argv[1:4]
m=trimesh.load(f'/home/claude/orc/{key}_dec.ply')
def bbox(img,bg_thr):
    a=np.asarray(img.convert('RGB')).astype(int); bg=np.median(np.concatenate([a[:5].reshape(-1,3),a[-5:].reshape(-1,3)]),0)
    d=np.abs(a-bg).sum(2)>bg_thr; ys,xs=np.where(d); return xs.min(),ys.min(),xs.max()+1,ys.max()+1
F=Image.open(frente).convert('RGB'); S=Image.open(folha).convert('RGB'); W=S.width
views={}
views['f']=F.crop(bbox(F,40))
# sheet thirds
for i,n in enumerate(['_','l','b']):
    if n=='_': continue
    part=S.crop((i*W//3,0,(i+1)*W//3,S.height)); views[n]=part.crop(bbox(part,40))
# atlas: each view resized to height H, side by side
H=1024; tiles={}; x=0; ims=[]
for n in ['f','b','l']:
    im=views[n]; w=round(im.width*H/im.height); ims.append(im.resize((w,H),Image.LANCZOS)); tiles[n]=(x,w); x+=w
AW=x; atlas=Image.new('RGB',(AW,H)); 
for im,n in zip(ims,['f','b','l']): atlas.paste(im,(tiles[n][0],0))
# pad atlas width to 2048-friendly
# preenche o fundo com a cor mais próxima do personagem (evita borda branca nas laterais)
from scipy import ndimage
A=np.asarray(atlas).astype(int); bgm=(A.min(2)>185)|((np.abs(A-A[2,2]).sum(2))<40)
bgm=ndimage.binary_dilation(bgm,iterations=5)
idx=ndimage.distance_transform_edt(bgm,return_distances=False,return_indices=True)
A=A[idx[0],idx[1]]; atlas=Image.fromarray(A.astype(np.uint8))
atlas=atlas.resize((2048,1024),Image.LANCZOS); sx=2048/AW
v=m.vertices; fn=m.face_normals; mn,mx=v.min(0),v.max(0)
def uv(n,p):
    x0,w=tiles.get(n,tiles['f'])
    if n=='f': u=(p[:,0]-mn[0])/(mx[0]-mn[0])
    elif n=='b': u=(mx[0]-p[:,0])/(mx[0]-mn[0])
    elif n=='l': u=(p[:,2]-mn[2])/(mx[2]-mn[2])
    else:
        x0,w=tiles['f']; u=(p[:,0]-mn[0])/(mx[0]-mn[0]); t=np.full(len(p),0.95); return np.stack([(x0+u*w)*sx/2048, 1-t],1)  # lado esquerdo do personagem: frente (+z) fica à direita da imagem
    t=(mx[1]-p[:,1])/(mx[1]-mn[1])
    return np.stack([(x0+u*w)*sx/2048, 1-t],1)
fv=m.faces; nv=[]; nuv=[]; nn=[]; vn=m.vertex_normals
for i,f in enumerate(fv):
    nx,ny,nz=fn[i]
    if ny<-0.5: k='s'
    elif abs(nx)>0.6 and abs(nx)>abs(nz) and np.abs(v[f][:,0]).max()<0.27: k='l'
    elif nz>=0 : k='f'
    else: k='b'
    p=v[f]; nv.append(p); nuv.append(uv(k,p)); nn.append(vn[f])
nv=np.concatenate(nv); nuv=np.concatenate(nuv); faces=np.arange(len(nv)).reshape(-1,3)
key2=np.round(np.concatenate([nv,nuv],1),5); u_,inv=np.unique(key2,axis=0,return_inverse=True,return_index=False), None
_,first,inv=np.unique(key2,axis=0,return_index=True,return_inverse=True)
nn=np.concatenate(nn); nv,nuv,nn=nv[first],nuv[first],nn[first]; faces=inv.reshape(-1,3)
atlas.save(f'/home/claude/orc/{key}_atlas.jpg',quality=90)
mat=trimesh.visual.material.PBRMaterial(baseColorTexture=atlas,roughnessFactor=0.85,metallicFactor=0)
out=trimesh.Trimesh(nv,faces,visual=trimesh.visual.TextureVisuals(uv=nuv,material=mat),process=False)
out.vertex_normals=nn
out.export(f'/home/claude/orc/{key}_tex.glb'); print(key,len(nv),AW)
