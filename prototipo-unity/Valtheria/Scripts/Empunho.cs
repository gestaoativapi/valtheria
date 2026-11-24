// Empunho.cs — pegada de armas e escudo no cavaleiro (porta do Godot: character.gd + empunhar.gd, v38)
// Mesma lógica do cliente Godot, para as duas versões ficarem iguais:
//  - quadro da pegada medido nos ossos da própria mão (dedo médio, indicador e mindinho);
//  - poses por arma (normal e combate) em direções do espaço do personagem, medidas pelo braço de cada um;
//  - IK de dois ossos + giro da mão; o punho só dobra até um limite (firme em combate, solto fora dele);
//  - fio do machado e da adaga sempre para longe do pulso (nunca para trás/para baixo);
//  - escudo de pé (ponta para baixo, emblema para fora): preso ao peito em guarda, ao lado da mão fora dela.
// Godot: +Z frente, +Y cima, -X direita. Unity: +Z frente, +Y cima, +X direita (por isso o X troca de sinal).
using System.Collections.Generic;
using UnityEngine;

public class Empunho : MonoBehaviour
{
    public enum Arma { Espada, Machado, Adaga }

    struct Pose { public Vector3 mao, lamina, polo; public float k; public Pose(Vector3 m, float kk, Vector3 l, Vector3 p) { mao = m; k = kk; lamina = l; polo = p; } }
    // valores do Godot (POSE_ARMA), lado direito; o X é invertido na leitura (G2U)
    static readonly Dictionary<string, Pose> POSES = new Dictionary<string, Pose>
    {
        { "normal", new Pose(new Vector3(-0.22f, -0.93f, 0.22f), 0.93f, new Vector3(-0.14f, -0.28f, 0.95f), new Vector3(-0.3f, -0.35f, -0.9f)) },
        { "normal_machado", new Pose(new Vector3(-0.28f, -0.55f, 0.78f), 0.55f, new Vector3(0.18f, 0.62f, -0.76f), new Vector3(-0.5f, -0.85f, 0.1f)) },  // no ombro, como lenhador
        { "normal_adaga", new Pose(new Vector3(-0.25f, -0.9f, 0.3f), 0.9f, new Vector3(-0.12f, 0.3f, 0.95f), new Vector3(-0.35f, -0.4f, -0.85f)) },
        { "combate", new Pose(new Vector3(-0.2f, -0.78f, 0.58f), 0.88f, new Vector3(-0.26f, 0.5f, 0.82f), new Vector3(-0.8f, -0.6f, -0.15f)) },
    };
    static Vector3 G2U(Vector3 v) => new Vector3(-v.x, v.y, v.z);

    public Arma arma = Arma.Espada;
    public bool comEscudo;
    public bool emCombate;
    public System.Func<bool> ocupado;  // golpe/reação tocando: a animação manda no braço

    Transform ombroR, cotR, maoR, ombroL, cotL, maoL, peito;
    Quaternion peitoRestLocal = Quaternion.identity;
    Transform pegadaR;           // quadro da pegada preso à mão (+Z lâmina, +Y para o pulso)
    Quaternion pegadaLocalRot;   // rotação da pegada no espaço do osso da mão
    Vector3 pegadaLocalPos;
    float bracoR, bracoL;
    float peso, pesoEscudo, punhoMax = 22f;
    Transform escudo, escudoPeito, escudoMao;
    Vector3 alvoEscudoLocal;     // alvo do punho esquerdo, no espaço do personagem
    Matrix4x4 peitoParaPersonagem0;

    static Transform Osso(Transform raiz, string nome)
    {
        if (raiz.name == nome) return raiz;
        foreach (Transform f in raiz) { var r = Osso(f, nome); if (r != null) return r; }
        return null;
    }

    // chamar logo depois de instanciar (pose de descanso) e de ajustar a escala
    public void Montar(Arma tipo, bool escudoNoBraco, GameObject modeloArma, GameObject modeloEscudo, float comprimento)
    {
        arma = tipo; comEscudo = escudoNoBraco;
        ombroR = Osso(transform, "upperarm_r"); cotR = Osso(transform, "lowerarm_r"); maoR = Osso(transform, "hand_r");
        ombroL = Osso(transform, "upperarm_l"); cotL = Osso(transform, "lowerarm_l"); maoL = Osso(transform, "hand_l");
        peito = Osso(transform, "spine_03");
        if (peito != null) peitoRestLocal = Quaternion.Inverse(transform.rotation) * peito.rotation;
        if (maoR == null || cotR == null || ombroR == null) { enabled = false; return; }
        bracoR = Braco("r");
        bracoL = Braco("l");
        // quadro da pegada (igual ao _hand_grip do Godot)
        var med = Osso(transform, "middle_01_r"); var ind = Osso(transform, "index_01_r"); var min = Osso(transform, "pinky_01_r");
        Vector3 dedo = (med.position - maoR.position).normalized;
        Vector3 th = ind.position - min.position; th = (th - dedo * Vector3.Dot(th, dedo)).normalized;
        var g = new GameObject("PegadaR").transform;
        g.SetParent(maoR, false);
        g.position = maoR.position + (med.position - maoR.position) * 0.55f;
        g.rotation = Quaternion.LookRotation(th, -dedo);
        g.localScale = Vector3.one / Mathf.Max(0.0001f, maoR.lossyScale.x);
        pegadaR = g;
        pegadaLocalRot = g.localRotation;
        pegadaLocalPos = g.localPosition;
        MedirCapsulas();
        if (modeloArma != null) PorArma(modeloArma, comprimento);
        if (comEscudo && modeloEscudo != null && peito != null && maoL != null) PorEscudo(modeloEscudo);
    }

    float Braco(string l)
    {
        var o = Osso(transform, "upperarm_" + l); var c = Osso(transform, "lowerarm_" + l); var m = Osso(transform, "hand_" + l); var d = Osso(transform, "middle_01_" + l);
        if (o == null || c == null || m == null) return 0.6f;
        return Vector3.Distance(o.position, c.position) + Vector3.Distance(c.position, m.position) + (d != null ? Vector3.Distance(m.position, d.position) * 0.55f : 0f);
    }

    // ---------- arma ----------
    void PorArma(GameObject inst, float comprimento)
    {
        var mfs = inst.GetComponentsInChildren<MeshFilter>();
        if (mfs.Length == 0) return;
        // caixa no espaço da raiz do modelo
        var pts = Vertices(inst.transform, mfs);
        var b = new Bounds(pts[0], Vector3.zero); foreach (var p in pts) b.Encapsulate(p);
        int eixo = b.size.x >= b.size.y && b.size.x >= b.size.z ? 0 : (b.size.y >= b.size.z ? 1 : 2);
        Vector3 dir = Vector3.zero; dir[eixo] = 1f;
        if (Mathf.Abs(b.min[eixo]) > Mathf.Abs(b.max[eixo])) dir = -dir;
        float k = comprimento / b.size[eixo];
        float cabo = dir[eixo] > 0 ? b.min[eixo] : b.max[eixo];
        float at = arma == Arma.Machado ? 0.4f : (arma == Arma.Adaga ? 0.06f : 0.1f);
        Vector3 pega = b.center; pega[eixo] = cabo + dir[eixo] * at / k;
        laminaM = comprimento - at; caboM = at;
        var suporte = new GameObject("Arma").transform;
        suporte.SetParent(pegadaR, false);
        inst.transform.SetParent(suporte, false);
        inst.transform.localRotation = Quaternion.FromToRotation(dir, Vector3.forward);
        inst.transform.localScale = Vector3.one * k;
        inst.transform.localPosition = -(inst.transform.localRotation * (pega * k));
        // faces largas para os lados, fios para cima/baixo; o lado pesado (fio único) para longe do pulso (-Y)
        var vs = Vertices(suporte, mfs);
        var bb = new Bounds(vs[0], Vector3.zero); foreach (var p in vs) bb.Encapsulate(p);
        if (bb.size.y < bb.size.x * 0.85f) suporte.localRotation = Quaternion.AngleAxis(90f, Vector3.forward) * suporte.localRotation;
        if (arma != Arma.Espada) GirarFio(suporte, mfs, Vector3.down);
    }

    static List<Vector3> Vertices(Transform espaco, MeshFilter[] mfs)
    {
        var l = new List<Vector3>();
        foreach (var mf in mfs)
        {
            if (mf.sharedMesh == null) continue;
            var m = espaco.worldToLocalMatrix * mf.transform.localToWorldMatrix;
            foreach (var v in mf.sharedMesh.vertices) l.Add(m.MultiplyPoint3x4(v));
        }
        return l;
    }

    // gira em volta do cabo (+Z do suporte) para a média dos vértices da metade de cima (cabeça/lâmina) ir para "para"
    static void GirarFio(Transform suporte, MeshFilter[] mfs, Vector3 para)
    {
        var pai = suporte.parent;
        var vs = Vertices(pai, mfs);
        float maxp = 0; foreach (var v in vs) maxp = Mathf.Max(maxp, v.z);
        Vector3 soma = Vector3.zero; int n = 0; float raio = 0;
        foreach (var v in vs) if (v.z > maxp * 0.5f) { var o = new Vector3(v.x, v.y, 0); soma += o; raio = Mathf.Max(raio, o.magnitude); n++; }
        if (n == 0) return;
        var off = soma / n;
        if (off.magnitude < raio * 0.1f) return;
        float ang = Vector3.SignedAngle(off, new Vector3(para.x, para.y, 0), Vector3.forward);
        suporte.localRotation = Quaternion.AngleAxis(ang, Vector3.forward) * suporte.localRotation;
    }

    // ---------- escudo ----------
    void PorEscudo(GameObject inst)
    {
        var mfs = inst.GetComponentsInChildren<MeshFilter>();
        var pts = Vertices(inst.transform, mfs);
        var b = new Bounds(pts[0], Vector3.zero); foreach (var p in pts) b.Encapsulate(p);
        var tam = b.size;
        int alto = tam.x >= tam.y && tam.x >= tam.z ? 0 : (tam.y >= tam.z ? 1 : 2);
        int fino = tam.x <= tam.y && tam.x <= tam.z ? 0 : (tam.y <= tam.z ? 1 : 2);
        int largo = 3 - alto - fino;
        float[] larg = new float[2]; int[] conta = new int[2];
        for (int lado = 0; lado < 2; lado++)
        {
            float mn = 1e9f, mx = -1e9f;
            foreach (var p in pts)
            {
                float u = (p[alto] - b.min[alto]) / Mathf.Max(tam[alto], 1e-5f);
                if ((lado == 0 && u < 0.1f) || (lado == 1 && u > 0.9f)) { mn = Mathf.Min(mn, p[largo]); mx = Mathf.Max(mx, p[largo]); }
            }
            larg[lado] = mx - mn;
        }
        foreach (var p in pts) conta[p[fino] < b.center[fino] ? 0 : 1]++;
        Vector3 cima = Vector3.zero; cima[alto] = larg[1] >= larg[0] ? 1f : -1f;    // ponta (lado estreito) para baixo
        Vector3 frente = Vector3.zero; frente[fino] = conta[1] >= conta[0] ? 1f : -1f; // face com mais detalhe = emblema
        float k = 0.72f * (transform.lossyScale.y > 0 ? 1f : 1f) / tam[alto];
        var modeloRot = Quaternion.Inverse(Quaternion.LookRotation(frente, cima)); // modelo -> (frente=+Z, cima=+Y)
        escudo = new GameObject("Escudo").transform;
        inst.transform.SetParent(escudo, false);
        inst.transform.localRotation = modeloRot;
        inst.transform.localScale = Vector3.one * k;
        inst.transform.localPosition = -(modeloRot * (b.center * k));
        // em guarda: nó que segue o peito; alvo do punho esquerdo à frente do peito
        alvoEscudoLocal = G2U(new Vector3(0.22f, 1.04f, 0.34f));
        if (capsulas.Count > 1) alvoEscudoLocal.z = Mathf.Max(alvoEscudoLocal.z, capsulas[1].r / Mathf.Max(0.0001f, transform.lossyScale.x) + 0.2f / Mathf.Max(0.0001f, transform.lossyScale.x));
        // nó do escudo em guarda: segue a posição do peito e só o giro horizontal dele (num golpe o tronco se
        // curva e o escudo não pode deitar nem ir para as costas)
        escudoPeito = new GameObject("EscudoPeito").transform;
        escudoPeito.SetParent(transform, false);
        escudoPeito.localScale = Vector3.one / Mathf.Max(0.0001f, transform.lossyScale.x);
        frentePeitoLocal = Quaternion.Inverse(peito.rotation) * transform.forward;
        offPeito = Quaternion.Inverse(transform.rotation) * (transform.TransformPoint(alvoEscudoLocal) - peito.position);
        SeguirPeito();
        escudoMao = new GameObject("EscudoMao").transform;
        escudoMao.SetParent(transform, false);
        escudoMao.localScale = Vector3.one / Mathf.Max(0.0001f, transform.lossyScale.x);
        PosEscudo(false);
    }

    Vector3 frentePeitoLocal, offPeito;
    void SeguirPeito()
    {
        Vector3 f = peito.rotation * frentePeitoLocal; f.y = 0;
        if (f.sqrMagnitude < 0.04f) f = transform.forward;
        // só 30% do giro do tronco (correndo ele torce e o escudo rodava junto, até entrar no corpo)
        var giro = Quaternion.Slerp(transform.rotation, Quaternion.LookRotation(f.normalized, Vector3.up), 0.3f);
        Vector3 pos = peito.position + giro * offPeito;
        escudoPeito.SetPositionAndRotation(pos, giro);
        if (escudo != null && escudoNaGuarda && capsulas.Count > 0)
        {
            for (int it = 0; it < 4; it++)
            {
                Vector3 pior = Vector3.zero;
                foreach (var mf in escudo.GetComponentsInChildren<MeshFilter>())
                {
                    var bb = mf.sharedMesh.bounds;
                    for (int ix = 0; ix < 3; ix++) for (int iy = 0; iy < 3; iy++) for (int iz = 0; iz < 3; iz++)
                    {
                        var pl = bb.min + Vector3.Scale(bb.size, new Vector3(ix, iy, iz) * 0.5f);
                        var sa = Saida(mf.transform.TransformPoint(pl), 0.06f);
                        if (sa.magnitude > pior.magnitude) pior = sa;
                    }
                }
                if (pior.sqrMagnitude < 1e-10f) break;
                escudoPeito.position += pior * 1.1f;
            }
        }
    }

    bool escudoNaGuarda;
    void PosEscudo(bool guarda)
    {
        escudoNaGuarda = guarda;
        if (guarda)
        {
            escudo.SetParent(escudoPeito, false);
            // de pé, frente 16° aberta para fora (esquerda = -X) e um pouco erguida; centro à frente do punho
            escudo.localRotation = Quaternion.Euler(-6f, -16f, 0f);
            escudo.localPosition = G2U(new Vector3(-0.02f, -0.03f, 0.1f));
        }
        else
        {
            escudo.SetParent(escudoMao, false);
            // ao lado do corpo: frente para fora (-X) e 22° para a frente; ponta para baixo
            escudo.localRotation = Quaternion.Euler(0f, -90f + 22f, 0f);
            escudo.localPosition = G2U(new Vector3(0.08f, 0.02f, 0f));
        }
        escudo.localScale = Vector3.one;
    }

    // ---------- a cada quadro, depois da animação ----------
    void LateUpdate()
    {
        float dt = Time.deltaTime;
        bool golpe = ocupado != null && ocupado();
        peso = Mathf.MoveTowards(peso, golpe ? 0f : 1f, dt * (golpe ? 14f : 4f));
        punhoMax = Mathf.Lerp(punhoMax, emCombate ? 22f : (arma == Arma.Machado ? 60f : 35f), Mathf.Clamp01(dt * 6f));
        if (peso > 0.001f) MaoDireita(peso);
        if (peso < 0.999f && capsulas.Count > 0) GolpeForaDoCorpo();
        if (escudo != null)
        {
            if (emCombate != escudoNaGuarda) PosEscudo(emCombate);
            if (!emCombate) escudoMao.position = maoL.position;
            else SeguirPeito();
            pesoEscudo = Mathf.MoveTowards(pesoEscudo, emCombate ? 1f : 0f, dt * 5f);
            if (pesoEscudo > 0.001f)
            {
                var alvo = escudoPeito.position;
                var polo = transform.TransformPoint(G2U(new Vector3(0.75f, 0.75f, -0.15f)));
                IK(ombroL, cotL, maoL, alvo, polo, pesoEscudo);
            }
        }
    }

    // a arma acompanha o corpo: o balanço que a animação dá à mão e ao antebraço é somado à pose
    // (referência = média lenta da própria animação; parado não muda nada)
    Vector3 refMao, refAnte; bool temRef;
    public float balanco = 1f;

    void MaoDireita(float w)
    {
        Vector3 maoAnim = transform.InverseTransformPoint(maoR.position);
        Vector3 anteAnim = transform.InverseTransformDirection(maoR.position - cotR.position).normalized;
        if (!temRef) { refMao = maoAnim; refAnte = anteAnim; temRef = true; }
        float kr = Mathf.Clamp01(Time.deltaTime * 1.6f);
        refMao = Vector3.Lerp(refMao, maoAnim, kr);
        refAnte = Vector3.Lerp(refAnte, anteAnim, kr).normalized;
        // limites (Godot 24/11 14:38): o desvio tem teto de 12 cm, nunca puxa a mão para dentro do corpo e o giro do
        // antebraço entra pela metade e até 20 graus
        Vector3 dl = (maoAnim - refMao) * balanco;
        Vector3 radial = new Vector3(maoAnim.x, 0, 0);
        if (radial.sqrMagnitude > 1e-6f && Vector3.Dot(dl, radial.normalized) < 0) dl -= radial.normalized * Vector3.Dot(dl, radial.normalized);
        dl = Vector3.ClampMagnitude(dl, 0.12f / Mathf.Max(0.0001f, transform.lossyScale.x));
        Vector3 desvio = transform.TransformVector(dl);
        var giroTotal = Quaternion.FromToRotation(transform.TransformDirection(refAnte), transform.TransformDirection(anteAnim));
        giroTotal.ToAngleAxis(out float angG, out Vector3 _);
        float kG = angG > 0.01f ? Mathf.Min(balanco * 0.5f, 20f / angG) : 0f;
        var giroBal = Quaternion.Slerp(Quaternion.identity, giroTotal, kG);
        string chave = emCombate ? "combate" : (arma == Arma.Machado ? "normal_machado" : (arma == Arma.Adaga ? "normal_adaga" : "normal"));
        var p = POSES[chave];
        Vector3 om = ombroR.position;
        Vector3 mao = om + transform.TransformDirection(G2U(p.mao).normalized) * bracoR * p.k;
        Vector3 z = transform.TransformDirection(G2U(p.lamina).normalized);
        Vector3 dica = (om - mao).normalized;
        Vector3 y = (dica - z * Vector3.Dot(dica, z)).normalized;
        Vector3 polo = om + transform.TransformDirection(G2U(p.polo)) * bracoR + desvio;
        if (!emCombate && arma == Arma.Machado && peito != null)
        {
            // machado no ombro: a pose gira junto com a inclinação do peito, em volta do ombro
            var rq = peito.rotation * Quaternion.Inverse(transform.rotation * peitoRestLocal);
            mao = om + rq * (mao - om); polo = om + rq * (polo - om); z = rq * z; y = rq * y;
        }
        mao += desvio;
        z = giroBal * z; y = giroBal * y;
        ForaDoCorpo(ref mao, ref z, ref y);
        var alvoRot = Quaternion.LookRotation(z, y);      // rotação desejada da pegada
        var rotMao = alvoRot * Quaternion.Inverse(pegadaLocalRot);
        Vector3 pulso = mao - rotMao * Vector3.Scale(pegadaLocalPos, maoR.lossyScale);
        var antes = maoR.rotation;
        IK(ombroR, cotR, maoR, pulso, polo, w);
        // punho natural: a mão continua o antebraço e só dobra até punhoMax; o resto vai para a arma
        Vector3 ante = (cotR.position - maoR.position).normalized;
        float ang = Vector3.Angle(y, ante);
        if (ang > punhoMax)
        {
            var ajuste = Quaternion.AngleAxis(ang - punhoMax, Vector3.Cross(y, ante).normalized);
            alvoRot = ajuste * alvoRot;
            rotMao = alvoRot * Quaternion.Inverse(pegadaLocalRot);
            pulso = mao - rotMao * Vector3.Scale(pegadaLocalPos, maoR.lossyScale);
            IK(ombroR, cotR, maoR, pulso, polo, w);
        }
        maoR.rotation = Quaternion.Slerp(maoR.rotation, rotMao, w);
    }

    // ---------- corpo como cápsulas (porta de character.gd _capsulas / empunhar.gd _fora_do_corpo) ----------
    static readonly string[,] CAPS = { { "pelvis", "spine_03" }, { "spine_03", "neck_01" }, { "neck_01", "Head" }, { "thigh_l", "calf_l" }, { "thigh_r", "calf_r" }, { "calf_l", "foot_l" }, { "calf_r", "foot_r" } };
    readonly List<(Transform a, Transform b, float r, bool cabeca)> capsulas = new List<(Transform, Transform, float, bool)>();
    float laminaM = 1f, caboM = 0.1f, larguraM = 0.03f;

    void MedirCapsulas()
    {
        var dist = new List<float>[CAPS.GetLength(0)];
        var ossoSeg = new Dictionary<Transform, int>();
        for (int i = 0; i < CAPS.GetLength(0); i++)
        {
            dist[i] = new List<float>();
            var t = Osso(transform, CAPS[i, 0]);
            if (t != null) ossoSeg[t] = i;
            if (i == 0) { var s1 = Osso(transform, "spine_01"); var s2 = Osso(transform, "spine_02"); if (s1) ossoSeg[s1] = 0; if (s2) ossoSeg[s2] = 0; }
            if (i == 2) { var hd = Osso(transform, "Head"); if (hd) ossoSeg[hd] = 2; }
        }
        foreach (var smr in GetComponentsInChildren<SkinnedMeshRenderer>())
        {
            var m = smr.sharedMesh; if (m == null || !m.isReadable) continue;
            var vs = m.vertices; var bw = m.boneWeights; var bp = m.bindposes; var bones = smr.bones;
            if (bw.Length != vs.Length) continue;
            for (int v = 0; v < vs.Length; v += 4)
            {
                int bi = bw[v].boneIndex0;
                if (bi < 0 || bi >= bones.Length || bones[bi] == null || !ossoSeg.TryGetValue(bones[bi], out int seg)) continue;
                Vector3 pw = bones[bi].localToWorldMatrix.MultiplyPoint3x4(bp[bi].MultiplyPoint3x4(vs[v]));
                var a = Osso(transform, CAPS[seg, 0]); var b = Osso(transform, CAPS[seg, 1]);
                if (a == null || b == null) continue;
                dist[seg].Add(Vector3.Distance(pw, PontoSeg(pw, a.position, b.position)));
            }
        }
        for (int i = 0; i < CAPS.GetLength(0); i++)
        {
            var a = Osso(transform, CAPS[i, 0]); var b = Osso(transform, CAPS[i, 1]);
            if (a == null || b == null) continue;
            float r;
            if (dist[i].Count > 10) { dist[i].Sort(); r = dist[i][(int)(dist[i].Count * 0.6f)]; }
            else r = i == 2 ? 0.1f : (i < 2 ? 0.13f : 0.08f);
            capsulas.Add((a, b, r, i == 2));
        }
    }

    static Vector3 PontoSeg(Vector3 p, Vector3 a, Vector3 b)
    {
        Vector3 ab = b - a; float t = Mathf.Clamp01(Vector3.Dot(p - a, ab) / Mathf.Max(ab.sqrMagnitude, 1e-8f));
        return a + ab * t;
    }

    Vector3 Saida(Vector3 p, float folga)
    {
        Vector3 melhor = Vector3.zero;
        foreach (var c in capsulas)
        {
            Vector3 a = c.a.position, b = c.b.position;
            if (c.cabeca) b += (b - a).normalized * c.r * 1.2f;
            Vector3 d = p - PontoSeg(p, a, b);
            float dentro = c.r + folga - d.magnitude;
            if (dentro > melhor.magnitude) melhor = (d.sqrMagnitude > 1e-10f ? d.normalized : transform.right) * dentro;
        }
        return melhor;
    }

    // pegada fora do corpo e lâmina girada para fora quando passaria por dentro (mesma regra do Godot)
    void ForaDoCorpo(ref Vector3 mao, ref Vector3 z, ref Vector3 y)
    {
        if (capsulas.Count == 0) return;
        mao += Saida(mao, 0.06f);
        float C = caboM / Mathf.Max(laminaM, 0.01f);
        float[] ts = { -C, -C * 0.5f, 0.1f, 0.25f, 0.45f, 0.65f, 0.85f, 1f };
        float girado = 0f;
        for (int it = 0; it < 6; it++)
        {
            Vector3 pior = Vector3.zero; float tp = 0;
            foreach (var t in ts)
            {
                var sa = Saida(mao + z * laminaM * t, 0.03f + (t > 0.6f ? larguraM : 0f));
                if (sa.magnitude > pior.magnitude) { pior = sa; tp = t; }
            }
            if (pior.sqrMagnitude < 1e-10f) break;
            var q = Quaternion.FromToRotation(z, (z * laminaM * tp + pior * 1.6f).normalized);
            q.ToAngleAxis(out float aq, out Vector3 _);
            if (girado + aq > 35f) { mao += pior * 1.1f; continue; }  // girar demais vira a arma; a mão se afasta
            girado += aq;
            z = q * z; y = q * y;
        }
    }

    // no golpe a animação manda; aqui só se tira a mão de dentro do corpo
    void GolpeForaDoCorpo()
    {
        for (int it = 0; it < 4; it++)
        {
            Vector3 palma = pegadaR.position;
            var s = Saida(palma, 0.045f);
            if (s.sqrMagnitude < 1e-10f) break;
            var rot = maoR.rotation;
            IK(ombroR, cotR, maoR, maoR.position + s * 1.15f, cotR.position + s, 1f);
            maoR.rotation = rot;
        }
    }

    // IK de dois ossos com polo (igual ao empunhar.gd)
    static void IK(Transform a, Transform b, Transform c, Vector3 t, Vector3 polo, float w)
    {
        Vector3 pa = a.position, pb = b.position, pc = c.position;
        float l1 = Vector3.Distance(pa, pb), l2 = Vector3.Distance(pb, pc);
        Vector3 dv = t - pa;
        float d = Mathf.Clamp(dv.magnitude, Mathf.Abs(l1 - l2) + 1e-4f, (l1 + l2) * 0.9995f);
        Vector3 dir = dv.normalized;
        float cosA = Mathf.Clamp((l1 * l1 + d * d - l2 * l2) / (2f * l1 * d), -1f, 1f);
        Vector3 perp = polo - pa; perp -= dir * Vector3.Dot(perp, dir);
        if (perp.sqrMagnitude < 1e-8f) { perp = (pb - pa) - dir * Vector3.Dot(pb - pa, dir); }
        perp.Normalize();
        Vector3 cot = pa + dir * (l1 * cosA) + perp * (l1 * Mathf.Sqrt(1f - cosA * cosA));
        var q1 = Quaternion.FromToRotation(pb - pa, cot - pa) * a.rotation;
        a.rotation = Quaternion.Slerp(a.rotation, q1, w);
        pb = b.position; pc = c.position;
        var q2 = Quaternion.FromToRotation(pc - pb, (pa + dir * d) - pb) * b.rotation;
        b.rotation = Quaternion.Slerp(b.rotation, q2, w);
    }
}
