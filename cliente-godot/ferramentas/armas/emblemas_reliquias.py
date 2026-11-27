#!/usr/bin/env python3
"""Emblemas das Relíquias de Criaturas (armas S e SS, 27/11) — desenhos originais em vetor.

Gera, para cada criatura:
  assets/emblemas/reliquia_<criatura>.png   medalhão (gravado na arma e mostrado no item)
  assets/emblemas/espirito_<criatura>.png   silhueta luminosa (o espírito que surge no golpe forte do SS)
Uso: python3 ferramentas/armas/emblemas_reliquias.py
"""
import io, os
import cairosvg
from PIL import Image, ImageFilter

DEST = os.path.join(os.path.dirname(__file__), '..', '..', 'assets', 'emblemas')

# silhuetas (viewBox 0 0 512 512), criatura olhando para a direita; desenhos próprios
CRIATURAS = {
    'dragao': {
        'cores': ('#ffd27a', '#ff5a1f', '#5a0f06'),
        'forma': (
            # cabeça de dragão de perfil: dois chifres longos para trás, crista de espinhos na nuca, sobrancelha
            # marcada, focinho longo com narina, mandíbula aberta com presas
            'M96 396 C110 360 112 322 104 288 L70 300 L100 266 L62 254 L108 238 L84 210 L130 214 '
            'C140 196 156 182 176 172 L112 92 L196 150 L188 70 L244 150 '
            'C276 146 312 150 344 162 L404 172 C430 176 450 186 458 200 C462 210 454 218 442 218 '
            'L410 220 L420 232 L388 236 C370 244 352 248 334 248 L352 258 L326 262 L340 276 '
            'L404 278 C420 280 424 292 412 300 L330 312 L346 328 L316 326 L322 344 L292 330 '
            'C262 344 226 352 194 352 C176 372 150 390 120 400 Z '
            'M300 192 C316 182 336 186 342 198 C328 204 312 204 300 192 Z'
        ),
        'detalhes': (
            'M150 330 C170 318 196 312 222 314 M140 296 C164 282 192 276 222 278 M150 260 C172 246 200 240 228 242 '
            'M200 112 L232 156 M156 120 L206 160 M360 182 C380 186 396 194 404 204 '
            'M286 330 L300 312 M262 340 L274 318 M238 344 L246 322'
        ),
    },
    'lobo': {
        'cores': ('#e6dcff', '#8a6cff', '#170c33'),
        'forma': (
            # lobo sombrio uivando: focinho erguido, orelhas em pé, juba em tufos, peito
            'M150 440 L170 380 L132 392 L164 340 L120 340 L172 300 L128 286 L184 262 '
            'C186 226 200 196 222 172 L210 96 L254 146 L266 78 L292 144 '
            'C312 150 330 142 346 128 L398 82 C408 76 418 84 412 94 L384 140 '
            'C378 156 366 170 350 180 L376 196 C366 210 348 216 328 214 '
            'C320 250 306 290 300 330 L330 380 L300 380 L318 440 Z '
            'M302 160 C310 152 322 154 324 162 C316 168 308 166 302 160 Z'
        ),
        'detalhes': (
            'M196 300 C210 290 226 288 240 292 M188 340 C204 330 222 328 238 332 M200 380 C214 372 232 370 248 374 '
            'M240 180 C252 196 260 214 262 236 M340 196 L362 200 M226 120 L250 160'
        ),
    },
    'golem': {
        'cores': ('#ffe39a', '#d38f3a', '#2a2012'),
        'forma': (
            # golem de pedra de frente: coroa de rochas, ombros de bloco, olhos e boca de luz (vazados)
            'M96 430 L110 352 L156 330 L144 250 L162 176 L200 150 L222 96 L256 130 L290 96 L312 150 '
            'L350 176 L368 250 L356 330 L402 352 L416 430 Z '
            'M180 236 L238 226 L234 262 L186 268 Z M274 226 L332 236 L326 268 L278 262 Z '
            'M214 300 L298 300 L288 326 L224 326 Z'
        ),
        'detalhes': (
            'M162 176 L200 214 L256 196 L312 214 L350 176 M256 130 L256 196 M144 250 L186 268 M368 250 L326 268 '
            'M156 330 L214 300 M356 330 L298 300 M110 352 L170 380 L256 360 L342 380 L402 352 M256 360 L256 430'
        ),
    },
    'serpente': {
        'cores': ('#e2fbff', '#4cc7ff', '#06263d'),
        'forma': (
            # serpente glacial: corpo enrolado, cabeça com barbatanas de gelo em leque e presas
            'M110 430 C86 368 118 300 196 290 C268 282 306 330 268 364 C238 388 196 370 212 342 '
            'C176 348 168 388 210 404 C292 432 366 370 346 290 C338 256 314 230 306 202 '
            'L258 170 L304 166 L276 120 L326 156 L332 96 L360 154 L392 112 L388 166 '
            'C418 168 444 180 456 198 C438 210 414 212 392 208 L402 220 L378 222 '
            'C388 250 406 280 410 310 C424 410 334 458 240 450 C186 446 144 440 110 430 Z '
            'M360 180 C368 172 380 174 384 184 C374 188 366 186 360 180 Z'
        ),
        'detalhes': (
            'M150 400 C140 370 150 340 178 324 M230 418 C260 420 300 408 324 380 M342 320 C350 300 350 280 344 262 '
            'M304 160 L336 196 M330 132 L344 182 M370 140 L362 182'
        ),
    },
    'fenix': {
        'cores': ('#fff7cc', '#ffae2e', '#4c2003'),
        'forma': (
            # fênix de frente: asas abertas em penas de chama, crista de três plumas e cauda em leque
            'M256 96 L268 120 L290 104 L284 134 C300 146 304 168 296 186 L318 196 L294 204 '
            'C308 228 310 252 302 272 C334 248 362 208 372 160 L388 190 L402 150 L408 196 L432 176 '
            'C430 220 412 254 380 276 L420 290 C380 300 348 304 320 312 C306 336 290 352 276 362 '
            'L304 444 L268 400 L256 456 L244 400 L208 444 L236 362 C222 352 206 336 192 312 '
            'C164 304 132 300 92 290 L132 276 C100 254 82 220 80 176 L104 196 L110 150 L124 190 L140 160 '
            'C150 208 178 248 210 272 C202 252 204 228 218 204 L194 196 L216 186 C208 168 212 146 228 134 '
            'L222 104 L244 120 Z'
        ),
        'detalhes': (
            'M300 272 C330 262 356 244 374 220 M212 272 C182 262 156 244 138 220 M310 296 C340 290 370 286 398 286 '
            'M202 296 C172 290 142 286 114 286 M256 330 L256 420 M244 160 C250 156 262 156 268 160'
        ),
    },
    'grifo': {
        'cores': ('#effcff', '#8fd6ff', '#122d45'),
        'forma': (
            # grifo: cabeça de águia com bico em gancho, penas da nuca em leque e asa erguida atrás
            'M132 440 C140 372 160 320 198 284 C150 268 120 228 112 170 L150 196 L140 140 L178 180 '
            'L182 118 L214 170 C226 150 244 138 266 132 C300 122 334 128 358 146 '
            'C378 160 392 180 398 200 L446 212 C458 216 458 230 446 238 L414 262 C408 268 398 266 394 258 '
            'L398 244 L378 250 C364 276 338 294 306 300 L332 330 L292 322 L306 360 L266 338 L270 380 L240 352 '
            'C230 384 228 414 232 440 Z '
            'M332 176 C340 166 354 166 360 176 C352 184 340 184 332 176 Z'
        ),
        'detalhes': (
            'M398 200 C414 214 420 230 414 250 M300 220 C320 236 346 240 370 234 M254 200 C266 236 290 262 318 276 '
            'M212 290 C228 300 246 304 264 302 M206 330 C220 338 236 342 252 340 M182 180 L214 230 M150 196 L196 250'
        ),
    },
}


def medalhao(nome, c):
    brilho, cor, sombra = c['cores']
    runas = ''.join(
        f'<rect x="252" y="22" width="8" height="18" rx="2" fill="{brilho}" transform="rotate({a} 256 256)"/>'
        for a in range(0, 360, 15))
    svg = f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512" width="512" height="512">
<defs>
 <radialGradient id="fundo" cx="50%" cy="45%" r="60%"><stop offset="0" stop-color="{sombra}"/><stop offset="1" stop-color="#07080c"/></radialGradient>
 <linearGradient id="corpo" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="{brilho}"/><stop offset="0.55" stop-color="{cor}"/><stop offset="1" stop-color="{sombra}"/></linearGradient>
 <linearGradient id="aro" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#f4e2b0"/><stop offset="0.5" stop-color="#9c7a3c"/><stop offset="1" stop-color="#4a3618"/></linearGradient>
</defs>
<circle cx="256" cy="256" r="250" fill="url(#aro)"/>
<circle cx="256" cy="256" r="226" fill="#1a140c"/>
{runas}
<circle cx="256" cy="256" r="206" fill="url(#fundo)" stroke="{cor}" stroke-width="4"/>
<g transform="translate(256 262) scale(0.78) translate(-256 -256)">
 <path d="{c['forma']}" fill="url(#corpo)" fill-rule="evenodd" stroke="{brilho}" stroke-width="5" stroke-linejoin="round"/>
 <path d="{c['detalhes']}" fill="none" stroke="{sombra}" stroke-width="6" stroke-linecap="round" opacity="0.75"/>
</g>
</svg>'''
    return Image.open(io.BytesIO(cairosvg.svg2png(bytestring=svg.encode()))).convert('RGBA')


def espirito(nome, c):
    brilho, cor, sombra = c['cores']
    svg = f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512" width="512" height="512">
<path d="{c['forma']}" fill="{brilho}" fill-rule="evenodd" stroke="{cor}" stroke-width="10" stroke-linejoin="round"/>
<path d="{c['detalhes']}" fill="none" stroke="{cor}" stroke-width="7" stroke-linecap="round" opacity="0.9"/></svg>'''
    nucleo = Image.open(io.BytesIO(cairosvg.svg2png(bytestring=svg.encode()))).convert('RGBA')
    # halo: a mesma silhueta borrada na cor do elemento, por baixo
    halo = Image.new('RGBA', nucleo.size, (0, 0, 0, 0))
    r, g, b = Image.new('RGB', (1, 1), cor).getpixel((0, 0))
    a = nucleo.split()[3].filter(ImageFilter.GaussianBlur(18))
    halo = Image.merge('RGBA', (Image.new('L', nucleo.size, r), Image.new('L', nucleo.size, g), Image.new('L', nucleo.size, b), a.point(lambda v: min(255, int(v * 1.6)))))
    out = Image.alpha_composite(halo, nucleo)
    return out


if __name__ == '__main__':
    os.makedirs(DEST, exist_ok=True)
    for nome, c in CRIATURAS.items():
        medalhao(nome, c).save(os.path.join(DEST, f'reliquia_{nome}.png'))
        espirito(nome, c).save(os.path.join(DEST, f'espirito_{nome}.png'))
        print('ok', nome)
