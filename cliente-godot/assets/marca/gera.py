import cairosvg, math
def ramo(x0,y0,x1,y1,w0,w1,curva):
    # galho afinando, levemente curvo (polígono)
    dx,dy=x1-x0,y1-y0; L=math.hypot(dx,dy); nx,ny=-dy/L,dx/L
    pts_l=[];pts_r=[]
    for i in range(13):
        t=i/12; w=w0+(w1-w0)*t
        cx=x0+dx*t+nx*curva*math.sin(math.pi*t); cy=y0+dy*t+ny*curva*math.sin(math.pi*t)
        pts_l.append((cx+nx*w/2,cy+ny*w/2)); pts_r.append((cx-nx*w/2,cy-ny*w/2))
    pts=pts_l+pts_r[::-1]
    return "M"+" L".join(f"{x:.1f},{y:.1f}" for x,y in pts)+"Z"
def emblema(ox,oy,s):
    # V em forma de árvore: um só tronco que se abre em dois galhos; raízes embaixo; eclipse entre os galhos
    p=[]
    bx,by=ox,oy+150*s
    p.append(ramo(bx,by+4*s,bx,by-26*s,26*s,30*s,0))  # tronco curto
    p.append(ramo(bx-6*s,by-20*s,ox-110*s,oy-120*s,26*s,8*s,-26*s))
    p.append(ramo(bx+6*s,by-20*s,ox+110*s,oy-120*s,26*s,8*s,26*s))
    # galhos menores, abrindo para fora como copa
    p.append(ramo(ox-58*s,oy-14*s,ox-138*s,oy-62*s,11*s,2.5*s,-10*s))
    p.append(ramo(ox-92*s,oy-82*s,ox-150*s,oy-128*s,8*s,2*s,-6*s))
    p.append(ramo(ox+58*s,oy-14*s,ox+138*s,oy-62*s,11*s,2.5*s,10*s))
    p.append(ramo(ox+92*s,oy-82*s,ox+150*s,oy-128*s,8*s,2*s,6*s))
    # raízes
    p.append(ramo(bx,by-8*s,ox-46*s,oy+186*s,12*s,2*s,6*s))
    p.append(ramo(bx,by-8*s,ox+46*s,oy+186*s,12*s,2*s,-6*s))
    p.append(ramo(bx,by-4*s,ox-8*s,oy+196*s,9*s,2*s,3*s))
    return p
def mundos(ox,oy,s):
    # frutos da Árvore: pequenos mundos com anel na ponta dos galhos
    out=""
    for (x,y,cor) in [(-138,-62,"#7fd6c2"),(-150,-128,"#c9a0ff"),(138,-62,"#ffb070"),(150,-128,"#8fc4ff"),(-110,-120,"#f2e6a8"),(110,-120,"#ff8fa8")]:
        cx,cy=ox+x*s,oy+y*s
        out+=f'<circle cx="{cx:.1f}" cy="{cy:.1f}" r="{12*s:.1f}" fill="{cor}" opacity="0.35"/>'
        out+=f'<circle cx="{cx:.1f}" cy="{cy:.1f}" r="{6*s:.1f}" fill="{cor}"/>'
        out+=f'<ellipse cx="{cx:.1f}" cy="{cy:.1f}" rx="{10*s:.1f}" ry="{3*s:.1f}" fill="none" stroke="{cor}" stroke-width="{1.4*s:.1f}" transform="rotate(-18 {cx:.1f} {cy:.1f})"/>'
    return out
def svg(w,h,conteudo):
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">
<defs>
 <linearGradient id="ouro" x1="0" y1="0" x2="0" y2="1">
  <stop offset="0" stop-color="#fff3c4"/><stop offset="0.38" stop-color="#e2b65a"/>
  <stop offset="0.62" stop-color="#a8742b"/><stop offset="1" stop-color="#f0cf7e"/></linearGradient>
 <linearGradient id="ourotxt" x1="0" y1="200" x2="0" y2="372" gradientUnits="userSpaceOnUse">
  <stop offset="0" stop-color="#fff4cf"/><stop offset="0.45" stop-color="#e6b85c"/>
  <stop offset="0.55" stop-color="#9c6726"/><stop offset="1" stop-color="#e9c67a"/></linearGradient>
 <linearGradient id="prata" x1="0" y1="0" x2="1" y2="1">
  <stop offset="0" stop-color="#ffffff"/><stop offset="1" stop-color="#9fb4d8"/></linearGradient>
 <radialGradient id="halo"><stop offset="0" stop-color="#cfe0ff" stop-opacity="0.9"/>
  <stop offset="0.5" stop-color="#8fb0ff" stop-opacity="0.35"/><stop offset="1" stop-color="#6a7fd0" stop-opacity="0"/></radialGradient>
 <filter id="sombra" x="-20%" y="-20%" width="140%" height="140%">
  <feDropShadow dx="0" dy="4" stdDeviation="5" flood-color="#000" flood-opacity="0.75"/></filter>
</defs>{conteudo}</svg>'''
def eclipse(cx,cy,r):
    return (f'<circle cx="{cx}" cy="{cy}" r="{r*2.4}" fill="url(#halo)"/>'
            f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="url(#prata)"/>'
            f'<circle cx="{cx+r*0.32}" cy="{cy-r*0.22}" r="{r*0.93}" fill="#0b0d1a"/>'
            f'<circle cx="{cx+r*0.32}" cy="{cy-r*0.22}" r="{r*0.93}" fill="none" stroke="#3a3f6a" stroke-width="{r*0.06}"/>')
def fragmentos(cx,cy,R,n=6,s=1.0):
    out=""
    for i in range(n):
        a=math.radians(200+i*28)
        x,y=cx+R*math.cos(a),cy+R*math.sin(a)
        k=7*s
        out+=f'<path d="M{x:.1f},{y-k*1.6:.1f} L{x+k:.1f},{y:.1f} L{x:.1f},{y+k*1.6:.1f} L{x-k:.1f},{y:.1f}Z" fill="#bfe3ff" opacity="0.95"/>'
    return out

# logotipo completo
W,H=1700,560
ox,oy=170,220
c='<g filter="url(#sombra)">'
c+=eclipse(ox,oy-50,40)
for d in emblema(ox,oy,1.0):
    c+=f'<path d="{d}" fill="url(#ouro)" stroke="#3b2410" stroke-width="3"/>'
c+=mundos(ox,oy,1.0)
T='x="315" y="372" font-family="Cinzel" font-weight="bold" font-size="210" letter-spacing="14"'
c+=f'<text {T} fill="none" stroke="#1a0f05" stroke-width="12" stroke-linejoin="round">ALTHERIA</text>'
c+=f'<text {T} fill="url(#ourotxt)">ALTHERIA</text>'
c+='</g>'
# subtítulo com fios e losangos
c+='<g font-family="Cinzel" font-weight="bold" font-size="44" letter-spacing="9" fill="#e8d6a8">'
c+='<text x="905" y="470" text-anchor="middle">A ÁRVORE DOS MIL MUNDOS</text></g>'
c+='<path d="M330,457 L440,457" stroke="#c9a45a" stroke-width="2.5"/><path d="M1370,457 L1480,457" stroke="#c9a45a" stroke-width="2.5"/>'
c+='<path d="M450,449 L460,457 L450,465 L440,457Z" fill="#e2b65a"/><path d="M1360,449 L1370,457 L1360,465 L1350,457Z" fill="#e2b65a"/>'
c+=fragmentos(ox,oy-50,78,6,0.9)
open('logo.svg','w').write(svg(W,H,c))
cairosvg.svg2png(url='logo.svg',write_to='logo.png',output_width=W)
# emblema sozinho (ícone)
E=512; c='<rect width="512" height="512" rx="96" fill="#0c0f1c"/>'
c+='<circle cx="256" cy="256" r="236" fill="none" stroke="#a8742b" stroke-width="6"/>'
c+='<g filter="url(#sombra)">'+eclipse(256,150,46)
for d in emblema(256,262,1.12): c+=f'<path d="{d}" fill="url(#ouro)" stroke="#3b2410" stroke-width="3"/>'
c+=mundos(256,262,1.12)
c+='</g>'+fragmentos(256,150,86,6,1.0)
open('emblema.svg','w').write(svg(E,E,c))
cairosvg.svg2png(url='emblema.svg',write_to='emblema.png',output_width=512)
