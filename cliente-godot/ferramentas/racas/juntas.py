# Padrão Valtheria: articulações por gabarito de proporção + medição da malha (A-pose, frente +z, esquerda +x)
import numpy as np, trimesh, json, sys
from PIL import Image, ImageDraw
GAB={'pelvis':.477,'spine_01':.543,'spine_02':.629,'spine_03':.714,'neck_01':.845,'Head':.891,
     'clav':.825,'upper':.805,'thigh':.43,'calf':.24,'foot':.08,'ball':.024,'tip':.015}
def detectar(m, aj=None):
    aj=aj or {}; g={**GAB,**aj.get('gab',{})}
    v=m.vertices; y0=v[:,1].min(); top=v[:,1].max(); h=top-y0; Y=lambda f: y0+f*h
    def faixa(f0,f1): return v[(v[:,1]>Y(f0))&(v[:,1]<Y(f1))]
    def zmeio(p,q=(10,90)): return float((np.percentile(p[:,2],q[0])+np.percentile(p[:,2],q[1]))/2)
    # tronco
    t=faixa(.55,.75); t=t[np.abs(t[:,0])<0.12]; zt=zmeio(t)
    cab=faixa(.86,.98); cab=cab[np.abs(cab[:,0])<0.12]; zc=zmeio(cab)
    tr=faixa(.6,.7); xr=np.abs(tr[:,0]); 
    # meia largura do tronco: percentil de |x| entre vértices perto do z do tronco (exclui braços afastados)
    rT=float(np.percentile(xr,60)); rH=float(np.percentile(np.abs(cab[:,0]),95))
    # mãos: ponto mais lateral e baixo de cada lado entre 25% e 55%
    J={'spine':{},'arm':{},'leg':{}}
    for k in ['pelvis','spine_01','spine_02','spine_03','neck_01','Head']:
        J['spine'][k]=[round(float(Y(g[k])),3), round(zt if k!='Head' and k!='neck_01' else zc,3)]
    J['headTop']=[round(float(top),3), round(zc,3)]
    maos={}
    for s in (+1,-1):
        p=faixa(.22,.58); p=p[p[:,0]*s>0]
        lat=np.abs(p[:,0]); sel=p[lat>np.percentile(lat,93)]
        tip=sel[np.argmin(sel[:,1])]          # ponta dos dedos: o mais baixo entre os mais laterais
        maos[s]=tip
    ytip=float((maos[1][1]+maos[-1][1])/2); xtip=float((abs(maos[1][0])+abs(maos[-1][0]))/2)
    up=np.array([rT*0.95, Y(g['upper'])]); hand=np.array([xtip-0.03, ytip+0.11*h*0.95*0.5*2.2/2.2*1.0])
    hand[1]=ytip+0.12*h* (0.5)  # punho ~6% da altura acima da ponta
    hand=np.array([xtip-0.035, ytip+0.105*h])  # mão humana ~10,5% da altura (punho à ponta do dedo médio)
    el=up+(hand-up)*0.48; el[0]+=0.04   # cotovelo levemente para fora
    armz=faixa(.4,.6); armz=armz[np.abs(armz[:,0])>rT]; az=float(np.median(armz[:,2])) if len(armz)>20 else zt
    J['arm']={'z':round(az,3),'clav':[round(0.09,3),round(float(Y(g['clav'])),3)],'upper':[round(float(up[0]),3),round(float(up[1]),3)],
      'lower':[round(float(el[0]),3),round(float(el[1]),3)],'hand':[round(float(hand[0]),3),round(float(hand[1]),3)],'tip':[round(xtip,3),round(ytip,3)]}
    ra=0.5*rT
    J['arm']['r']=[round(ra*1.0,3),round(ra*.85,3),round(ra*.72,3),round(ra*.65,3)]
    # pernas: x pelo centro de cada perna na altura do joelho/canela
    p=faixa(.12,.2); xl=float(np.median(p[p[:,0]>0][:,0])); xr2=float(np.median(-p[p[:,0]<0][:,0])); xL=(xl+xr2)/2
    pe=faixa(0,.06); zcal=float(np.percentile(pe[:,2],4)); zpon=float(np.percentile(pe[:,2],99.5))
    zp=zt
    J['leg']={'thigh':[round(xL*0.85,3),round(float(Y(g['thigh'])),3),round(zp,3)],'calf':[round(xL,3),round(float(Y(g['calf'])),3),round(zp,3)],
      'foot':[round(xL*1.05,3),round(float(Y(g['foot'])),3),round(zcal+0.25*(zpon-zcal),3)],
      'ball':[round(xL*1.05,3),round(float(Y(g['ball'])),3),round(zcal+0.65*(zpon-zcal),3)],
      'tip':[round(xL*1.05,3),round(float(Y(g['tip'])),3),round(zpon,3)]}
    rl=xL*0.9; J['leg']['r']=[round(rl,3),round(rl*.85,3),round(rl*.75,3),round(rl*.65,3)]
    J['rTorso']=round(rT,3); J['rHead']=round(rH,3); J['rNeck']=round(rH*0.85,3)
    J['hip']=[J['leg']['thigh'][0],J['leg']['thigh'][1]+0.02,round(rl*1.5,3)]; J['shoulder']=[round(rT*0.8,3),J['arm']['upper'][1],round(ra*1.1,3)]
    J['y0']=round(float(y0),3); J['top']=round(float(top),3); J['xs']=round(rT,3)
    for k,vv in aj.get('fixo',{}).items():  # ajustes manuais pontuais: 'arm.lower': [x,y]
        a,b=k.split('.') if '.' in k else (k,None)
        if b: J[a][b]=vv
        else: J[a]=vv
    return J
def previa(m,J,saida):
    v=m.vertices; R=700; lo=v.min(0); hi=v.max(0); e=(R-40)/(hi[1]-lo[1])
    out=[]
    for ex in (0,2):
        W=int((hi[ex]-lo[ex])*e)+40; im=Image.new('RGB',(W,R),(235,235,235)); d=ImageDraw.Draw(im)
        P=lambda x,y:((x-lo[ex])*e+20,(hi[1]-y)*e+20)
        for f in m.faces[::2]: d.polygon([P(v[i,ex],v[i,1]) for i in f],fill=(150,150,160))
        pts=[]
        for k,(yy,zz) in J['spine'].items(): pts.append(((0 if ex==0 else zz),yy))
        pts.append(((0 if ex==0 else J['headTop'][1]),J['headTop'][0]))
        A=J['arm']; braco=[(A[k][0],A[k][1]) for k in ['clav','upper','lower','hand','tip']]
        L=J['leg']; perna=[(L[k][0],L[k][1],L[k][2]) for k in ['thigh','calf','foot','ball','tip']]
        def linha(seq,cor):
            q=[P(*s) for s in seq]; d.line(q,fill=cor,width=3)
            for c in q: d.ellipse([c[0]-4,c[1]-4,c[0]+4,c[1]+4],fill=cor)
        linha(pts,(220,40,40))
        for sd in (1,-1):
            linha([((sd*x if ex==0 else A['z']),y) for x,y in braco],(30,120,220))
            linha([((sd*x if ex==0 else z),y) for x,y,z in perna],(30,170,60))
        out.append(im)
    Wt=sum(i.width for i in out); T=Image.new('RGB',(Wt,R)); x=0
    for i in out: T.paste(i,(x,0)); x+=i.width
    T.save(saida)
if __name__=='__main__':
    m=trimesh.load(sys.argv[1]); J=detectar(m); print(json.dumps(J)); previa(m,J,sys.argv[2])
