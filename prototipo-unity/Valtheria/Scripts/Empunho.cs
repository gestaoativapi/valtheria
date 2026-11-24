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
        { "normal", new Pose(new Vector3(-0.14f, -0.95f, 0.22f), 0.93f, new Vector3(-0.14f, -0.28f, 0.95f), new Vector3(-0.3f, -0.35f, -0.9f)) },
        { "normal_machado", new Pose(new Vector3(-0.28f, -0.55f, 0.78f), 0.55f, new Vector3(0.18f, 0.62f, -0.76f), new Vector3(-0.5f, -0.85f, 0.1f)) },  // no ombro, como lenhador
        { "normal_adaga", new Pose(new Vector3(-0.16f, -0.92f, 0.3f), 0.9f, new Vector3(-0.12f, 0.3f, 0.95f), new Vector3(-0.35f, -0.4f, -0.85f)) },
        { "combate", new Pose(new Vector3(-0.08f, -0.8f, 0.6f), 0.88f, new Vector3(-0.22f, 0.5f, 0.84f), new Vector3(-0.7f, -0.7f, -0.2f)) },
    };
    static Vector3 G2U(Vector3 v) => new Vector3(-v.x, v.y, v.z);

    public Arma arma = Arma.Espada;
    public bool comEscudo;
    public bool emCombate;
    public System.Func<bool> ocupado;  // golpe/reação tocando: a animação manda no braço

    Transform ombroR, cotR, maoR, ombroL, cotL, maoL, peito;
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
        var giro = Quaternion.LookRotation(f.normalized, Vector3.up);
        escudoPeito.SetPositionAndRotation(peito.position + giro * offPeito, giro);
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
        Vector3 desvio = transform.TransformVector(maoAnim - refMao) * balanco;
        var giroBal = Quaternion.Slerp(Quaternion.identity, Quaternion.FromToRotation(transform.TransformDirection(refAnte), transform.TransformDirection(anteAnim)), balanco * 0.7f);
        string chave = emCombate ? "combate" : (arma == Arma.Machado ? "normal_machado" : (arma == Arma.Adaga ? "normal_adaga" : "normal"));
        var p = POSES[chave];
        Vector3 om = ombroR.position;
        Vector3 mao = om + transform.TransformDirection(G2U(p.mao).normalized) * bracoR * p.k;
        Vector3 z = transform.TransformDirection(G2U(p.lamina).normalized);
        Vector3 dica = (om - mao).normalized;
        Vector3 y = (dica - z * Vector3.Dot(dica, z)).normalized;
        Vector3 polo = om + transform.TransformDirection(G2U(p.polo)) * bracoR + desvio;
        mao += desvio;
        z = giroBal * z; y = giroBal * y;
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
