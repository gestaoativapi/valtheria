# D39 — dois jogadores se enxergam? Testa o tempo real (canal "mundo") no PROJETO DE TESTES, como o cliente faz.
# Uso: TESTE_URL=... TESTE_KEY=<anon> TESTE_REF=... python3 teste/d39_tempo_real.py [pasta_evidencias]
import asyncio, base64, json, os, secrets, sys, time, urllib.request
import websockets

PROD_REF = "irpzdghikvoezfeodyiq"
URL, KEY, REF = os.environ["TESTE_URL"], os.environ["TESTE_KEY"], os.environ["TESTE_REF"]
EV = sys.argv[1] if len(sys.argv) > 1 else "d39_evidencias"; os.makedirs(EV, exist_ok=True)
assert PROD_REF not in URL and URL == f"https://{REF}.supabase.co", "trava: só o projeto de testes"
pl = json.loads(base64.urlsafe_b64decode(KEY.split(".")[1] + "=="))
assert pl.get("role") == "anon" and pl.get("ref") == REF, "trava: só a chave anon do projeto de testes"
falhas, total, log = 0, 0, []
def ok(t): global total; total += 1; print("[OK]    " + t); log.append(["OK", t])
def erro(t): global total, falhas; total += 1; falhas += 1; print("[FALHA] " + t); log.append(["FALHA", t])

def post(path, body, tok=None):
    req = urllib.request.Request(URL + path, json.dumps(body).encode(), method="POST",
        headers={"apikey": KEY, "Authorization": "Bearer " + (tok or KEY), "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=20) as r: return r.status, json.loads(r.read() or b"null")
    except urllib.error.HTTPError as e: return e.code, e.read().decode()[:200]

def jogador(rotulo):
    u, s = f"rt{rotulo}_{secrets.token_hex(4)}", secrets.token_urlsafe(15)   # senha gerada, nunca exibida
    c, _ = post("/functions/v1/signup", {"username": u, "password": s}); assert c == 200, f"cadastro {rotulo}: {c}"
    c, r = post("/auth/v1/token?grant_type=password", {"email": f"{u}@jogadores.reinosdeaurora.app", "password": s}); assert c == 200
    tok = r["access_token"]
    c, ch = post("/rest/v1/rpc/game_create_char2", {"p_name": f"R{rotulo}{secrets.token_hex(3)}", "p_race": "humano", "p_type": "l", "p_gender": "m", "p_look": {}}, tok); assert c == 200
    return {"u": u, "tok": tok, "id": ch, "nome": u, "recebidos": [], "presenca": []}

async def conectar(j):
    ws = await websockets.connect(URL.replace("https://", "wss://") + "/realtime/v1/websocket?apikey=" + KEY + "&vsn=1.0.0")
    await ws.send(json.dumps({"topic": "realtime:mundo", "event": "phx_join", "ref": "1", "payload": {"config": {"broadcast": {"self": False}, "presence": {"key": j["id"]}}, "access_token": j["tok"]}}))
    await ws.send(json.dumps({"topic": "realtime:mundo", "event": "presence", "ref": "2", "payload": {"type": "presence", "event": "track", "payload": {"name": j["nome"], "gm": False}}}))
    j["ws"] = ws

async def ouvir(j, ate):
    while time.time() < ate:
        try: m = json.loads(await asyncio.wait_for(j["ws"].recv(), timeout=max(0.1, ate - time.time())))
        except asyncio.TimeoutError: break
        p = m.get("payload") or {}
        if m.get("event") == "broadcast" and p.get("event") == "p": j["recebidos"].append(p.get("payload"))
        if m.get("event") in ("presence_state", "presence_diff"): j["presenca"].append(m)

async def main():
    a, b = jogador("A"), jogador("B"); ok("duas contas descartáveis e dois personagens criados")
    await conectar(a); await conectar(b); await asyncio.sleep(2); ok("os dois entraram no canal do mundo")
    fim = time.time() + 8
    async def mover(j, x):
        for i in range(5):
            await j["ws"].send(json.dumps({"topic": "realtime:mundo", "event": "broadcast", "ref": str(10 + i), "payload": {"type": "broadcast", "event": "p", "payload": {"id": j["id"], "name": j["nome"], "x": x + i, "z": 2575}}}))
            await asyncio.sleep(0.5)
    await asyncio.gather(ouvir(a, fim), ouvir(b, fim), mover(a, 1500), mover(b, 1510))
    ra = [p for p in a["recebidos"] if p and p.get("id") == b["id"]]; rb = [p for p in b["recebidos"] if p and p.get("id") == a["id"]]
    (ok if rb else erro)(f"B enxerga o movimento de A ({len(rb)} posições)")
    (ok if ra else erro)(f"A enxerga o movimento de B ({len(ra)} posições)")
    pa = json.dumps(a["presenca"]); pb = json.dumps(b["presenca"])
    (ok if b["id"] in pa else erro)("A recebe a presença de B (lista de quem está online)")
    (ok if a["id"] in pb else erro)("B recebe a presença de A")
    await a["ws"].close(); await asyncio.sleep(3); fim = time.time() + 3; await ouvir(b, fim)
    saiu = any(a["id"] in json.dumps((m.get("payload") or {}).get("leaves", {})) for m in b["presenca"] if m.get("event") == "presence_diff")
    (ok if saiu else erro)("quando A sai, B é avisado (o boneco some)")
    await b["ws"].close()
    json.dump({"log": log, "aprovados": total - falhas, "total": total}, open(os.path.join(EV, "tempo_real.json"), "w"), ensure_ascii=False, indent=1)
    print(f"Resultado tempo real: {total - falhas}/{total} aprovados"); sys.exit(1 if falhas else 0)

asyncio.run(main())
