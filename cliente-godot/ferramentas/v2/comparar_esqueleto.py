# Compara o esqueleto do corpo V2 (MPFB game_engine) com o esqueleto do jogo (65 ossos), na pose de repouso do glTF.
import json, struct, sys, math
import numpy as np
def load(f):
    b=open(f,'rb').read(); l=struct.unpack('<I',b[12:16])[0]; j=json.loads(b[20:20+l]); bin_=b[20+l+8:]
    return j, bin_
def acc(j,bin_,i):
    a=j['accessors'][i]; v=j['bufferViews'][a['bufferView']]; off=v.get('byteOffset',0)+a.get('byteOffset',0)
    n={'MAT4':16,'VEC3':3,'VEC4':4,'SCALAR':1}[a['type']]
    return np.frombuffer(bin_,dtype=np.float32,count=a['count']*n,offset=off).reshape(a['count'],n)
def bones(f):
    j,b=load(f); s=j['skins'][0]; ibm=acc(j,b,s['inverseBindMatrices'])
    out={}
    for k,ni in enumerate(s['joints']):
        m=np.linalg.inv(ibm[k].reshape(4,4).T)  # matriz do osso no espaço do modelo
        out[j['nodes'][ni]['name'].lower()]=m
    par={}
    for ni,n in enumerate(j['nodes']):
        for c in n.get('children',[]): par[j['nodes'][c]['name'].lower()]=n['name'].lower()
    return out,par
A,pa=bones(sys.argv[1]); B,pb=bones(sys.argv[2])
comuns=[k for k in A if k in B]
print("ossos jogo:",len(A)," V2:",len(B)," em comum:",len(comuns))
print("faltam na V2:",sorted(k for k in A if k not in B))
pais=[k for k in comuns if pa.get(k)!=pb.get(k)]
print("pai diferente:",[(k,pa.get(k),pb.get(k)) for k in pais])
res=[]
for k in comuns:
    ra=A[k][:3,:3]; rb=B[k][:3,:3]
    ra=ra/np.linalg.norm(ra,axis=0); rb=rb/np.linalg.norm(rb,axis=0)
    r=ra.T@rb; ang=math.degrees(math.acos(max(-1,min(1,(np.trace(r)-1)/2))))
    res.append((round(ang,1),k))
res.sort(reverse=True)
print("diferença de orientação de repouso (graus), maiores:",res[:14])
print("ossos com diferença <= 1 grau:",sum(1 for a,k in res if a<=1),"de",len(res))
