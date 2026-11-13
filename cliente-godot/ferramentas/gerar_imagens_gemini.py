#!/usr/bin/env python3
"""
Gera em lote as imagens de docs/PROMPTS_GEMINI.md pela API do Gemini (conta paga).
Alternativa a copiar e colar no app do Gemini: o resultado é o mesmo.

Preparar (uma vez):
    pip install google-genai pillow
    defina a chave:  Windows (PowerShell):  $env:GEMINI_API_KEY="sua-chave"
                     Linux/Mac:             export GEMINI_API_KEY="sua-chave"

Usar:
    python gerar_imagens_gemini.py --listar                    # mostra os grupos e quantos pedidos tem
    python gerar_imagens_gemini.py --grupo 1                   # todas as raças
    python gerar_imagens_gemini.py --grupo 2 --so-ng           # armas, só o grau NG
    python gerar_imagens_gemini.py --id humano_m_pesada        # um pedido só
    python gerar_imagens_gemini.py --grupo 1 --vistas          # raças + vistas de lado e de costas

As imagens vão para a pasta Valtheria-imagens (ou --saida). O que já existe é pulado,
então dá para parar e continuar depois. Nada aqui foi testado com uma chave real:
se a API reclamar do nome do modelo, troque em --modelo pelo nome que o Google AI Studio mostrar.
"""
import argparse, json, os, sys, time

AQUI = os.path.dirname(os.path.abspath(__file__))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--grupo", help="número do grupo (1 a 9)")
    ap.add_argument("--id", help="id de um pedido (ex.: espada_ng)")
    ap.add_argument("--so-ng", action="store_true", help="armas: só o grau NG")
    ap.add_argument("--vistas", action="store_true", help="personagens e monstros humanoides: gera também lado e costas")
    ap.add_argument("--modelo", default="gemini-3-pro-image-preview")
    ap.add_argument("--tamanho", default="2K", help="1K, 2K ou 4K")
    ap.add_argument("--saida", default="Valtheria-imagens")
    ap.add_argument("--listar", action="store_true")
    a = ap.parse_args()

    data = json.load(open(os.path.join(AQUI, "prompts.json"), encoding="utf-8"))
    items = data["items"]
    if a.listar:
        from collections import Counter
        for g, n in Counter(i["grupo"] for i in items).items():
            print(f"{n:4d}  {g}")
        return
    sel = [i for i in items
           if (not a.grupo or i["grupo"].startswith(a.grupo + "."))
           and (not a.id or i["id"] == a.id)
           and (not a.so_ng or not i["grupo"].startswith("2.") or i["id"].endswith("_ng"))
           and "JÁ FEITO" not in i["titulo"]]
    if not sel:
        sys.exit("nenhum pedido com esse filtro")

    from google import genai
    from google.genai import types
    client = genai.Client()  # lê GEMINI_API_KEY
    os.makedirs(a.saida, exist_ok=True)

    def save(resp, path):
        for part in resp.candidates[0].content.parts:
            if getattr(part, "inline_data", None) and part.inline_data.data:
                with open(path, "wb") as f:
                    f.write(part.inline_data.data)
                return True
        return False

    for n, it in enumerate(sel, 1):
        path = os.path.join(a.saida, it["arquivo"])
        if os.path.exists(path):
            print(f"[{n}/{len(sel)}] já existe: {it['arquivo']}")
            continue
        print(f"[{n}/{len(sel)}] {it['titulo']}")
        cfg = types.GenerateContentConfig(
            response_modalities=["TEXT", "IMAGE"],
            image_config=types.ImageConfig(aspect_ratio=it["aspect"], image_size=a.tamanho))
        chat = client.chats.create(model=a.modelo, config=cfg)
        for tent in range(3):
            try:
                ok = save(chat.send_message(it["prompt"]), path)
                if ok:
                    break
                print("   sem imagem na resposta, tentando de novo")
            except Exception as e:  # limite de uso ou falha temporária
                print("   erro:", e)
                time.sleep(20)
        else:
            print("   desisti deste pedido; rode de novo mais tarde")
            continue
        humanoide = it["grupo"].startswith("1.") or (it["grupo"].startswith("4.") and it["aspect"] == "3:4")
        if a.vistas and humanoide:
            for suf, txt in zip(("_lado", "_costas"), data["turnaround"]):
                vpath = path.replace(".png", suf + ".png")
                if not os.path.exists(vpath):
                    try:
                        save(chat.send_message(txt), vpath)
                        print("   vista", suf[1:])
                    except Exception as e:
                        print("   erro na vista", suf[1:], e)
        time.sleep(2)
    print("Pronto. Imagens em", os.path.abspath(a.saida))


if __name__ == "__main__":
    main()
