# Gera a imagem do mapa do mundo (data/mapa_mundo.png) a partir do relevo, da cor do terreno e da água.
# Uso: python3 ferramentas/gerar_mapa_mundo.py   (rodar na pasta cliente-godot)
import json, numpy as np
from PIL import Image, ImageFilter
w = json.load(open("data/world.json")); n = w["n"]
h = np.frombuffer(open("data/height.bin", "rb").read(), dtype="<u2").reshape(n, n).astype(np.float32) / 65535 * w["range"] + w["lo"]
tint = np.asarray(Image.open("data/tint.png").convert("RGB")).astype(np.float32) / 255
# áreas sem cor no terreno = chão calçado das cidades e estradas: pinta de pedra
pedra = tint.sum(2) < 0.12
tint[pedra] = [0.62, 0.58, 0.52]
# sombra de relevo (luz do noroeste)
gy, gx = np.gradient(h, 2.0)
nx, ny, nz = -gx, -gy, np.ones_like(h); l = np.sqrt(nx**2 + ny**2 + nz**2)
L = np.array([-0.6, -0.6, 0.55]); L /= np.linalg.norm(L)
shade = np.clip((nx * L[0] + ny * L[1] + nz * L[2]) / l, 0, 1)
img = tint * (0.55 + 0.6 * shade[..., None])
# neve nos picos, água por profundidade, faixa de areia na costa
img = np.where((h > 150)[..., None], img * 0.4 + 0.6 * np.array([0.93, 0.95, 0.98]), img)
dep = np.clip(-h / 30, 0, 1)[..., None]
agua = (1 - dep) * np.array([0.33, 0.62, 0.72]) + dep * np.array([0.10, 0.25, 0.42])
img = np.where((h < 0)[..., None], agua, img)
costa = (h >= 0) & (h < 1.2)
img = np.where(costa[..., None], img * 0.5 + 0.5 * np.array([0.86, 0.80, 0.62]), img)
out = Image.fromarray((np.clip(img, 0, 1) * 255).astype(np.uint8)).resize((1024, 1024), Image.LANCZOS)
out = out.filter(ImageFilter.UnsharpMask(radius=1.2, percent=60))
out.save("data/mapa_mundo.png", optimize=True)
print("ok", out.size)
