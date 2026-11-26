// =====================================================================================
// PROTÓTIPO VALTHERIA NO UNITY (comparação com o Godot) — 23/11/2026
// Monta a cena sozinho quando você aperta Play: chão, árvores, luz, névoa, pós-processamento URP,
// o cavaleiro com espada (WASD + clique/Espaço para atacar) e lobisomens que andam e atacam.
// F2 = 20 cavaleiros extras, F3 = 40 (teste de desempenho), F1 = nenhum. O canto da tela mostra
// FPS médio e o "1% mais lento", para comparar com o Godot no mesmo notebook.
// Modelos e animações: Quaternius (CC0) — os mesmos do jogo.
// =====================================================================================
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Animations;
using UnityEngine.Playables;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
#if ENABLE_INPUT_SYSTEM
using UnityEngine.InputSystem;
#endif

public class PrototipoValtheria : MonoBehaviour
{
    // ---------- entrada (funciona com o Input System novo ou com o antigo) ----------
    static class Entrada
    {
        public static Vector2 Eixo()
        {
            Vector2 v = Vector2.zero;
#if ENABLE_INPUT_SYSTEM
            var k = Keyboard.current;
            if (k != null)
            {
                if (k.wKey.isPressed || k.upArrowKey.isPressed) v.y += 1;
                if (k.sKey.isPressed || k.downArrowKey.isPressed) v.y -= 1;
                if (k.dKey.isPressed || k.rightArrowKey.isPressed) v.x += 1;
                if (k.aKey.isPressed || k.leftArrowKey.isPressed) v.x -= 1;
            }
#else
            v.x = Input.GetAxisRaw("Horizontal");
            v.y = Input.GetAxisRaw("Vertical");
#endif
            return v.sqrMagnitude > 1 ? v.normalized : v;
        }

        public static bool Atacar()
        {
#if ENABLE_INPUT_SYSTEM
            return (Mouse.current != null && Mouse.current.leftButton.wasPressedThisFrame)
                || (Keyboard.current != null && Keyboard.current.spaceKey.wasPressedThisFrame);
#else
            return Input.GetMouseButtonDown(0) || Input.GetKeyDown(KeyCode.Space);
#endif
        }

        public static bool Correr()
        {
#if ENABLE_INPUT_SYSTEM
            return Keyboard.current != null && Keyboard.current.leftShiftKey.isPressed;
#else
            return Input.GetKey(KeyCode.LeftShift);
#endif
        }

        public static bool Girar()
        {
#if ENABLE_INPUT_SYSTEM
            return Mouse.current != null && Mouse.current.rightButton.isPressed;
#else
            return Input.GetMouseButton(1);
#endif
        }

        public static Vector2 MouseDelta()
        {
#if ENABLE_INPUT_SYSTEM
            return Mouse.current != null ? Mouse.current.delta.ReadValue() * 0.1f : Vector2.zero;
#else
            return new Vector2(Input.GetAxis("Mouse X"), Input.GetAxis("Mouse Y")) * 2f;
#endif
        }

        public static float Roda()
        {
#if ENABLE_INPUT_SYSTEM
            return Mouse.current != null ? Mouse.current.scroll.ReadValue().y / 120f : 0f;
#else
            return Input.mouseScrollDelta.y;
#endif
        }

        public static int TeclaF()
        {
#if ENABLE_INPUT_SYSTEM
            var k = Keyboard.current;
            if (k == null) return 0;
            if (k.f1Key.wasPressedThisFrame) return 1;
            if (k.f2Key.wasPressedThisFrame) return 2;
            if (k.f3Key.wasPressedThisFrame) return 3;
            return 0;
#else
            if (Input.GetKeyDown(KeyCode.F1)) return 1;
            if (Input.GetKeyDown(KeyCode.F2)) return 2;
            if (Input.GetKeyDown(KeyCode.F3)) return 3;
            return 0;
#endif
        }
    }

    // ---------- animação sem Animator Controller (Playables) ----------
    public class Animador
    {
        PlayableGraph grafo;
        AnimationMixerPlayable mix;
        readonly Dictionary<string, int> indice = new Dictionary<string, int>();
        readonly List<AnimationClipPlayable> clipes = new List<AnimationClipPlayable>();
        readonly List<float> peso = new List<float>();
        readonly HashSet<string> repete = new HashSet<string> { "Idle", "Walk", "Jog_Fwd", "Sprint", "Sword_Idle", "walk", "run" };
        int atual = -1;
        public string Atual = "";
        public float Fim;  // hora em que a ação (golpe, reação) termina

        public Animador(GameObject modelo, AnimationClip[] lista)
        {
            var an = modelo.GetComponentInChildren<Animator>();
            if (an == null) an = modelo.AddComponent<Animator>();
            an.applyRootMotion = false;
            an.cullingMode = AnimatorCullingMode.CullUpdateTransforms;
            grafo = PlayableGraph.Create("Anim_" + modelo.name);
            grafo.SetTimeUpdateMode(DirectorUpdateMode.GameTime);
            var validos = new List<AnimationClip>();
            foreach (var c in lista)
                if (c != null && !c.name.StartsWith("__preview__")) validos.Add(c);
            mix = AnimationMixerPlayable.Create(grafo, validos.Count);
            for (int i = 0; i < validos.Count; i++)
            {
                string nome = validos[i].name;
                int barra = nome.LastIndexOf('|');
                if (barra >= 0) nome = nome.Substring(barra + 1);
                var cp = AnimationClipPlayable.Create(grafo, validos[i]);
                cp.SetApplyFootIK(false);
                grafo.Connect(cp, 0, mix, i);
                mix.SetInputWeight(i, 0f);
                clipes.Add(cp);
                peso.Add(0f);
                indice[nome] = i;
            }
            var saida = AnimationPlayableOutput.Create(grafo, "Saida", an);
            saida.SetSourcePlayable(mix);
            grafo.Play();
        }

        public bool Tem(string n) => indice.ContainsKey(n);

        public float Tocar(string n, float velocidade = 1f, bool reinicia = false)
        {
            if (!indice.TryGetValue(n, out int i)) return 0f;
            var clip = clipes[i].GetAnimationClip();
            clipes[i].SetSpeed(velocidade);
            if (i != atual || reinicia)
            {
                if (i != atual || !repete.Contains(n)) clipes[i].SetTime(0);
                clipes[i].Play();
                atual = i;
                Atual = n;
            }
            float dur = clip.length / Mathf.Max(0.05f, velocidade);
            if (!repete.Contains(n)) Fim = Time.time + dur * 0.92f;
            return dur;
        }

        public bool Ocupado => Time.time < Fim;

        public void Atualizar(float dt)
        {
            for (int i = 0; i < clipes.Count; i++)
            {
                float alvo = i == atual ? 1f : 0f;
                peso[i] = Mathf.MoveTowards(peso[i], alvo, dt / 0.15f);  // troca suave de 0,15 s
                mix.SetInputWeight(i, peso[i]);
                var cp = clipes[i];
                float len = cp.GetAnimationClip().length;
                string nome = cp.GetAnimationClip().name;
                int barra = nome.LastIndexOf('|');
                if (barra >= 0) nome = nome.Substring(barra + 1);
                double t = cp.GetTime();
                if (repete.Contains(nome)) { if (t > len) cp.SetTime(t % len); }
                else if (t > len) { cp.SetTime(len); }
            }
        }

        public void Destruir() { if (grafo.IsValid()) grafo.Destroy(); }
    }

    // ---------- materiais URP ----------
    static Shader lit;
    static readonly Dictionary<string, Material> mats = new Dictionary<string, Material>();

    static Material Mat(string chave, Color cor, string textura = null, string normal = null, float liso = 0.3f, float metal = 0f)
    {
        if (mats.TryGetValue(chave, out var m)) return m;
        if (lit == null) lit = Shader.Find("Universal Render Pipeline/Lit");
        m = new Material(lit) { name = chave, enableInstancing = true };
        m.SetColor("_BaseColor", cor);
        if (textura != null)
        {
            var t = Resources.Load<Texture2D>("Valtheria/Texturas/" + textura);
            if (t != null) m.SetTexture("_BaseMap", t);
        }
        if (normal != null)
        {
            var n = Resources.Load<Texture2D>("Valtheria/Texturas/" + normal);
            if (n != null) { m.SetTexture("_BumpMap", n); m.EnableKeyword("_NORMALMAP"); }
        }
        m.SetFloat("_Smoothness", liso);
        m.SetFloat("_Metallic", metal);
        mats[chave] = m;
        return m;
    }

    static void VestirCavaleiro(GameObject g)
    {
        foreach (var r in g.GetComponentsInChildren<Renderer>())
        {
            string n = r.gameObject.name;
            Material m;
            if (n.StartsWith("Male_Knight")) m = Mat("cavaleiro", Color.white, "T_Knight_BaseColor", "T_Knight_Normal", 0.45f, 0.35f);
            else if (n.StartsWith("Eyes")) m = Mat("olhos", Color.white, "T_Eye_Brown", null, 0.9f);
            else if (n.StartsWith("Eyebrows")) m = Mat("sobrancelha", new Color(0.25f, 0.18f, 0.12f), "T_Hair_1_BaseColor", null, 0.2f);
            else m = Mat("pele", Color.white, "T_Superhero_Male_Dark", "T_Superhero_Male_Normal", 0.35f);
            var arr = r.sharedMaterials;
            for (int i = 0; i < arr.Length; i++) arr[i] = m;
            if (arr.Length == 0) arr = new[] { m };
            r.sharedMaterials = arr;
            r.shadowCastingMode = ShadowCastingMode.On;
        }
    }

    static void VestirLobo(GameObject g)
    {
        foreach (var r in g.GetComponentsInChildren<Renderer>())
        {
            var m = Mat("lobo", Color.white, "rig_basecolor", "rig_normal", 0.25f);
            var arr = r.sharedMaterials;
            for (int i = 0; i < arr.Length; i++) arr[i] = m;
            if (arr.Length == 0) arr = new[] { m };
            r.sharedMaterials = arr;
        }
    }

    // põe o modelo com a altura certa (o FBX pode vir em centímetros) e com os pés no chão
    static void Ajustar(GameObject g, float altura)
    {
        var rs = g.GetComponentsInChildren<Renderer>();
        if (rs.Length == 0) return;
        var b = rs[0].bounds;
        foreach (var r in rs) b.Encapsulate(r.bounds);
        if (b.size.y > 0.01f) g.transform.localScale *= altura / b.size.y;
        b = rs[0].bounds;
        foreach (var r in rs) b.Encapsulate(r.bounds);
        g.transform.position += Vector3.up * (g.transform.position.y - b.min.y);
    }

    static Transform Osso(Transform raiz, string nome)
    {
        if (raiz.name == nome) return raiz;
        foreach (Transform f in raiz)
        {
            var r = Osso(f, nome);
            if (r != null) return r;
        }
        return null;
    }

    // espada na mão direita: ponta = lado mais longe da origem do modelo; eixo do punho = do mindinho ao indicador
    static void PorEspada(GameObject cav)
    {
        var mao = Osso(cav.transform, "hand_r");
        var pref = Resources.Load<GameObject>("Valtheria/espada");
        if (mao == null || pref == null) return;
        var e = Instantiate(pref);
        foreach (var r in e.GetComponentsInChildren<Renderer>())
            r.sharedMaterial = Mat("aco", new Color(0.62f, 0.64f, 0.66f), null, null, 0.7f, 0.85f);
        var mf = e.GetComponentInChildren<MeshFilter>();
        if (mf == null) return;
        var b = mf.sharedMesh.bounds;
        int eixo = b.size.x >= b.size.y && b.size.x >= b.size.z ? 0 : (b.size.y >= b.size.z ? 1 : 2);
        Vector3 dir = Vector3.zero; dir[eixo] = 1f;
        if (Mathf.Abs(b.min[eixo]) > Mathf.Abs(b.max[eixo])) dir = -dir;
        float comp = b.size[eixo];
        // suporte: origem no cabo, lâmina em +Z do suporte
        var suporte = new GameObject("Espada");
        var meshT = mf.transform;
        e.transform.SetParent(suporte.transform, false);
        float compMundo = meshT.TransformVector(dir * comp).magnitude;
        e.transform.localRotation = Quaternion.FromToRotation(meshT.TransformDirection(dir).normalized, Vector3.forward);
        e.transform.localScale *= 0.95f / Mathf.Max(0.001f, compMundo);  // espada de 95 cm
        var cabo = (dir[eixo] > 0 ? b.min[eixo] : b.max[eixo]) + dir[eixo] * 0.1f * comp;
        Vector3 pCabo = b.center; pCabo[eixo] = cabo;
        e.transform.position -= meshT.TransformPoint(pCabo) - suporte.transform.position;  // cabo na origem do suporte
        // na mão
        var ind = Osso(cav.transform, "index_01_r");
        var min = Osso(cav.transform, "pinky_01_r");
        Vector3 eixoPunho = (ind != null && min != null) ? (ind.position - min.position).normalized : mao.up;
        Vector3 centro = (ind != null && min != null) ? Vector3.Lerp(mao.position, (ind.position + min.position) * 0.5f, 0.6f) : mao.position;
        suporte.transform.SetParent(mao, true);
        suporte.transform.position = centro;
        suporte.transform.rotation = Quaternion.LookRotation(eixoPunho, mao.forward);
        suporte.transform.localScale = Vector3.one / Mathf.Max(0.0001f, mao.lossyScale.x);
    }

    // ---------- armas e escudo com a pegada do Godot (Empunho.cs, v38) ----------
    static void PintarArma(GameObject g)
    {
        foreach (var r in g.GetComponentsInChildren<Renderer>())
        {
            var arr = r.sharedMaterials;
            for (int i = 0; i < arr.Length; i++)
            {
                string n = arr[i] != null ? arr[i].name : "";
                if (n.Contains("DarkWood")) arr[i] = Mat("madeira_escura", new Color(0.40f, 0.27f, 0.19f), null, null, 0.25f);
                else if (n.Contains("Wood")) arr[i] = Mat("madeira", new Color(0.50f, 0.33f, 0.22f), null, null, 0.25f);
                else if (n.Contains("DarkSteel")) arr[i] = Mat("aco_escuro", new Color(0.46f, 0.46f, 0.44f), null, null, 0.6f, 0.8f);
                else arr[i] = Mat("aco", new Color(0.62f, 0.64f, 0.66f), null, null, 0.7f, 0.85f);
            }
            r.sharedMaterials = arr;
            r.shadowCastingMode = ShadowCastingMode.On;
        }
    }

    static Empunho Equipar(GameObject cav, Animador a, Empunho.Arma tipo, bool escudo)
    {
        var emp = cav.AddComponent<Empunho>();
        string nome = tipo == Empunho.Arma.Espada ? "espada" : (tipo == Empunho.Arma.Machado ? "Armas/machado" : "Armas/adaga");
        var pref = Resources.Load<GameObject>("Valtheria/" + nome);
        GameObject inst = pref != null ? Instantiate(pref) : null;
        if (inst != null) PintarArma(inst);
        GameObject esc = null;
        if (escudo)
        {
            var pe = Resources.Load<GameObject>("Valtheria/Armas/escudo");
            if (pe != null) { esc = Instantiate(pe); PintarArma(esc); }
        }
        float comp = tipo == Empunho.Arma.Adaga ? 0.5f : 0.95f;
        emp.Montar(tipo, escudo, inst, esc, comp);
        emp.ocupado = () => a.Ocupado;
        return emp;
    }

    // ---------- personagens ----------
    class Lobo
    {
        public GameObject go; public Animador anim; public float vida = 100; public Vector3 destino;
        public float proxAtaque; public float pisca; public Vector3 empurrao; public bool morto; public float caiu;
        public MaterialPropertyBlock mpb = new MaterialPropertyBlock(); public Renderer[] rs;
    }

    GameObject jogador; Animador animJ; Transform cam; Empunho empJ;
    float yaw = 30f, pitch = 18f, dist = 6.5f;
    float vidaJ = 300, vidaMaxJ = 300; int combo; float golpeEm = -1; bool golpePendente;
    readonly List<Lobo> lobos = new List<Lobo>();
    readonly List<(GameObject go, Animador a, Vector3 c, float fase)> extras = new List<(GameObject, Animador, Vector3, float)>();
    readonly List<Empunho> extrasArmas = new List<Empunho>();
    readonly List<(Vector3 p, string t, Color c, float ate)> textos = new List<(Vector3, string, Color, float)>();
    readonly Queue<float> quadros = new Queue<float>();
    float fpsMed, fpsBaixo, tFps;
    AnimationClip[] clipesCav, clipesLobo;
    GameObject prefCav, prefLobo;

    [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterSceneLoad)]
    static void Iniciar()
    {
        if (FindFirstObjectByType<PrototipoValtheria>() == null)
            new GameObject("Valtheria").AddComponent<PrototipoValtheria>();
    }

    void Start()
    {
        Application.targetFrameRate = -1;
        QualitySettings.vSyncCount = 0;
        prefCav = Resources.Load<GameObject>("Valtheria/cavaleiro");
        prefLobo = Resources.Load<GameObject>("Valtheria/lobisomem");
        clipesCav = Resources.LoadAll<AnimationClip>("Valtheria/cavaleiro");
        clipesLobo = Resources.LoadAll<AnimationClip>("Valtheria/lobisomem");
        MontarMundo();
        jogador = NovoCavaleiro(Vector3.zero, out animJ);
        empJ = Equipar(jogador, animJ, Empunho.Arma.Espada, true);
        for (int i = 0; i < 5; i++) NovoLobo(new Vector3(Random.Range(-25f, 25f), 0, Random.Range(8f, 30f)));
    }

    GameObject NovoCavaleiro(Vector3 pos, out Animador a)
    {
        var g = Instantiate(prefCav, pos, Quaternion.identity);
        VestirCavaleiro(g);
        Ajustar(g, 1.8f);
        a = new Animador(g, clipesCav);
        a.Tocar("Idle");
        return g;
    }

    void NovoLobo(Vector3 pos)
    {
        if (prefLobo == null) return;
        var l = new Lobo { go = Instantiate(prefLobo, pos, Quaternion.Euler(0, Random.Range(0, 360f), 0)) };
        VestirLobo(l.go);
        Ajustar(l.go, 2.1f);
        l.anim = new Animador(l.go, clipesLobo);
        l.anim.Tocar("walk");
        l.destino = pos;
        l.rs = l.go.GetComponentsInChildren<Renderer>();
        lobos.Add(l);
    }

    void MontarMundo()
    {
        // céu, luz e névoa na paleta aprovada (céu nublado, névoa úmida)
        RenderSettings.fog = true;
        RenderSettings.fogMode = FogMode.Linear;
        RenderSettings.fogStartDistance = 45f;
        RenderSettings.fogEndDistance = 220f;
        RenderSettings.fogColor = new Color(0.66f, 0.74f, 0.82f);
        // luz ambiente em três tons (céu azul, horizonte claro, chão quente) — cores mais vivas e naturais
        RenderSettings.ambientMode = AmbientMode.Trilight;
        RenderSettings.ambientSkyColor = new Color(0.58f, 0.7f, 0.9f);
        RenderSettings.ambientEquatorColor = new Color(0.56f, 0.6f, 0.52f);
        RenderSettings.ambientGroundColor = new Color(0.3f, 0.26f, 0.2f);

        var sol = FindFirstObjectByType<Light>();
        if (sol == null || sol.type != LightType.Directional) sol = new GameObject("Sol").AddComponent<Light>();
        sol.type = LightType.Directional;
        sol.color = new Color(1f, 0.92f, 0.78f);
        sol.intensity = 1.9f;
        sol.shadows = LightShadows.Soft;
        sol.shadowStrength = 0.82f;
        sol.transform.rotation = Quaternion.Euler(38f, 35f, 0f);

        var camara = Camera.main;
        if (camara == null) { camara = new GameObject("Camera").AddComponent<Camera>(); camara.tag = "MainCamera"; }
        cam = camara.transform;
        camara.clearFlags = CameraClearFlags.SolidColor;
        camara.backgroundColor = RenderSettings.fogColor;
        camara.farClipPlane = 300f;
        var dados = camara.GetUniversalAdditionalCameraData();
        dados.renderPostProcessing = true;
        dados.antialiasing = AntialiasingMode.SubpixelMorphologicalAntiAliasing;
        dados.antialiasingQuality = AntialiasingQuality.High;

        // pós-processamento: ACES, brilho, cor viva e quente, contraste, sombras e luzes separadas, vinheta leve
        var vol = new GameObject("PosProcesso").AddComponent<Volume>();
        vol.isGlobal = true;
        vol.priority = 50;
        var perfil = ScriptableObject.CreateInstance<VolumeProfile>();
        var tm = perfil.Add<Tonemapping>(true); tm.mode.Override(TonemappingMode.ACES);
        var bl = perfil.Add<Bloom>(true); bl.intensity.Override(0.6f); bl.threshold.Override(0.95f); bl.scatter.Override(0.72f);
        var ca = perfil.Add<ColorAdjustments>(true); ca.contrast.Override(12f); ca.saturation.Override(8f); ca.postExposure.Override(0.05f);
        var wb = perfil.Add<WhiteBalance>(true); wb.temperature.Override(3f); wb.tint.Override(1f);
        var smh = perfil.Add<ShadowsMidtonesHighlights>(true);
        smh.shadows.Override(new Vector4(0.92f, 0.96f, 1.08f, 0f)); smh.highlights.Override(new Vector4(1.06f, 1.02f, 0.94f, 0f));
        var vg = perfil.Add<Vignette>(true); vg.intensity.Override(0.2f); vg.smoothness.Override(0.45f);
        vol.profile = perfil;

        // chão de grama com a mesma textura do jogo (CC0)
        var chao = GameObject.CreatePrimitive(PrimitiveType.Plane);
        chao.name = "Chao";
        chao.transform.localScale = new Vector3(40, 1, 40);
        chao.GetComponent<Renderer>().sharedMaterial = MatNat("Chao") ?? Mat("chao", new Color(0.33f, 0.36f, 0.22f), null, null, 0.1f);
        var trilha = GameObject.CreatePrimitive(PrimitiveType.Plane);
        Destroy(trilha.GetComponent<Collider>());
        trilha.transform.position = new Vector3(0, 0.01f, -10f);
        trilha.transform.localScale = new Vector3(1.6f, 1, 4.5f);
        trilha.GetComponent<Renderer>().sharedMaterial = MatNat("Terra") ?? Mat("terra", new Color(0.4f, 0.32f, 0.22f), null, null, 0.1f);

        // árvores, pedras e plantas: os mesmos modelos do jogo (Quaternius, CC0)
        string[] arvores = { "n_commontree_1", "n_commontree_2", "n_commontree_3", "n_pine_1", "n_pine_2" };
        string[] pedras = { "n_rock_medium_1", "n_rock_medium_2", "n_rock_medium_3", "n_rock_large_1" };
        string[] plantas = { "n_bush_common", "n_bush_common_flowers", "n_fern_1", "n_flower_3_group", "n_plant_1_big" };
        // sorteio igual ao do Godot (mesma sequência), para as duas cenas ficarem com as plantas no mesmo lugar
        semente = 7;
        for (int i = 0; i < 90; i++)
        {
            var p = new Vector3(Sorteio() * 180 - 90, 0, Sorteio() * 180 - 90);
            int k = (int)(Sorteio() * arvores.Length); float g = Sorteio() * 360f, e = 0.9f + Sorteio() * 0.5f;
            if (p.magnitude < 12) continue;
            Natureza(arvores[k], p, g, e);
        }
        for (int i = 0; i < 40; i++)
        {
            var p = new Vector3(Sorteio() * 160 - 80, 0, Sorteio() * 160 - 80);
            int k = (int)(Sorteio() * pedras.Length); float g = Sorteio() * 360f, e = 0.6f + Sorteio();
            Natureza(pedras[k], p, g, e);
        }
        for (int i = 0; i < 260; i++)
        {
            var p = new Vector3(Sorteio() * 70 - 35, 0, Sorteio() * 70 - 35);
            int k = (int)(Sorteio() * plantas.Length); float g = Sorteio() * 360f, e = 0.7f + Sorteio() * 0.6f;
            if (p.magnitude < 3) continue;
            Natureza(plantas[k], p, g, e, false);
        }
        Vila();
        var ceu = Resources.Load<Material>("Valtheria/Natureza/Mats/Ceu");
        if (ceu != null) { RenderSettings.skybox = ceu; camara.clearFlags = CameraClearFlags.Skybox; DynamicGI.UpdateEnvironment(); }
    }

    // vila (mesmos modelos do jogo, Quaternius CC0), no mesmo tamanho que o jogo usa (maior medida em metros)
    void Vila()
    {
        void P(string n, float x, float z, float tam, float giro, bool sombra = true) => Peca("Valtheria/Vila/" + n, new Vector3(x, 0, z), giro, tam, sombra);
        P("b_inn", -16, -34, 10.5f, 20); P("b_house_1", 14, -36, 7.5f, -25); P("b_blacksmith", -22, -18, 6.8f, 75);
        P("b_stable", 22, -20, 6.2f, -80); P("b_mill", 30, -48, 9f, -40); P("b_house_1", -6, -50, 7.5f, 5);
        P("b_well", 3, -24, 2.6f, 0); P("b_bonfire_lit", -4, -16, 1.5f, 0);
        P("b_marketstand_1", 9, -14, 3.1f, -60); P("b_marketstand_1", -12, -10, 3.1f, 50);
        P("b_cart", 12, -26, 2.4f, 30); P("b_hay", 15, -24, 1.2f, 10); P("b_hay", 16.2f, -25.5f, 1.2f, 70);
        P("b_barrel", -9, -13, 0.9f, 0); P("b_barrel", -9.8f, -12.2f, 0.9f, 40); P("b_crate", -10.5f, -14.2f, 0.7f, 15);
        P("b_bags", 8, -12.5f, 0.6f, 0); P("b_bench_1", -1, -19, 1.6f, 90); P("b_bench_1", 6, -20, 1.6f, -90);
        P("n_light_street_1", -3, -8, 4.2f, 0); P("n_light_street_1", 5, -30, 4.2f, 0); P("d_torch", -14, -24, 2.2f, 0);
        P("q_birchtree_1", 26, -8, 9f, 0); P("q_willow_1", -28, -40, 8f, 30); P("n_twistedtree_1", 36, -30, 10f, 0);
        P("n_tree_light_1", -32, -6, 8f, 0); P("q_treestump_moss", 18, -6, 1f, 0); P("q_woodlog_moss", -20, -4, 2.5f, 60);
        P("q_bushberries_1", 10, -6, 1.3f, 0, false); P("n_mushroom_common", -16, -6, 0.5f, 0, false); P("n_flower_4_group", 4, -6, 0.7f, 0, false);
        P("a_deer", 30, -2, 1.7f, -120); P("a_horse", 24, -14, 2.4f, -95);
    }

    void Peca(string caminho, Vector3 pos, float giro, float tam, bool sombra)
    {
        var pref = Resources.Load<GameObject>(caminho);
        if (pref == null) return;
        var g = Instantiate(pref, pos, Quaternion.Euler(0, giro, 0) * pref.transform.rotation);
        var b = new Bounds(); bool primeiro = true;
        foreach (var r in g.GetComponentsInChildren<Renderer>()) { if (primeiro) { b = r.bounds; primeiro = false; } else b.Encapsulate(r.bounds); }
        float maior = Mathf.Max(b.size.x, Mathf.Max(b.size.y, b.size.z));
        if (maior > 0.001f) g.transform.localScale *= tam / maior;
        foreach (var r in g.GetComponentsInChildren<Renderer>())
        {
            var ms = r.sharedMaterials;
            for (int i = 0; i < ms.Length; i++)
            {
                if (ms[i] == null) continue;
                var troca = MatNat(ms[i].name.Replace(" (Instance)", "").Trim());
                if (troca != null) ms[i] = troca;
            }
            r.sharedMaterials = ms;
            if (!sombra) r.shadowCastingMode = ShadowCastingMode.Off;
        }
    }

    static long semente = 7;
    static float Sorteio() { semente = (semente * 1103515245L + 12345L) % 2147483648L; return semente / 2147483648f; }

    static readonly Dictionary<string, Material> matsNat = new Dictionary<string, Material>();
    static Material MatNat(string nome)
    {
        if (matsNat.TryGetValue(nome, out var m)) return m;
        m = Resources.Load<Material>("Valtheria/Natureza/Mats/" + nome);
        matsNat[nome] = m;
        return m;
    }

    readonly Dictionary<string, GameObject> modelosNat = new Dictionary<string, GameObject>();
    void Natureza(string nome, Vector3 pos, float giro, float escala, bool sombra = true)
    {
        if (!modelosNat.TryGetValue(nome, out var pref)) { pref = Resources.Load<GameObject>("Valtheria/Natureza/" + nome); modelosNat[nome] = pref; }
        if (pref == null) return;
        var g = Instantiate(pref, pos, Quaternion.Euler(0, giro, 0) * pref.transform.rotation);
        g.transform.localScale *= escala;
        foreach (var r in g.GetComponentsInChildren<Renderer>())
        {
            var ms = r.sharedMaterials;
            for (int i = 0; i < ms.Length; i++)
            {
                if (ms[i] == null) continue;
                var troca = MatNat(ms[i].name.Replace(" (Instance)", "").Trim());
                if (troca != null) ms[i] = troca;
            }
            r.sharedMaterials = ms;
            if (!sombra) r.shadowCastingMode = ShadowCastingMode.Off;
        }
    }

    void Extras(int n)
    {
        foreach (var e in extras) { e.a.Destruir(); Destroy(e.go); }
        extras.Clear();
        extrasArmas.Clear();
        for (int i = 0; i < n; i++)
        {
            var c = new Vector3((i % 8) * 3f - 10.5f, 0, -6f - (i / 8) * 3f);
            var g = NovoCavaleiro(c, out var a);
            a.Tocar(i % 2 == 0 ? "Walk" : "Sword_Idle");
            var tipo = (Empunho.Arma)(i % 3);
            var emp = Equipar(g, a, tipo, tipo == Empunho.Arma.Espada);
            emp.emCombate = i % 2 == 1;
            extrasArmas.Add(emp);
            extras.Add((g, a, c, i * 0.7f));
        }
    }

    // medição automática: Valtheria.exe -medir C:/caminho/unity.json
    // fases de 15 s (3 s de aquecimento): 0, 20 e 40 cavaleiros extras; grava FPS médio e 1% mais lento e fecha.
    string medirSaida;
    int medirFase = -1;
    float medirT;
    readonly List<float> medirQuadros = new List<float>();
    readonly System.Text.StringBuilder medirJson = new System.Text.StringBuilder();
    static readonly int[] MEDIR_N = { 0, 20, 40 };

    // foto para comparar com o Godot: Valtheria.exe -foto C:/caminho/unity.png (20 cavaleiros, câmera fixa)
    string fotoSaida;
    float fotoT;
    bool fotoTirada;
    void FotoAuto(float dt)
    {
        if (fotoSaida == null)
        {
            var args = System.Environment.GetCommandLineArgs();
            fotoSaida = "";
            for (int i = 0; i < args.Length - 1; i++) if (args[i] == "-foto") fotoSaida = args[i + 1];
            if (fotoSaida != "") Extras(20);
        }
        if (fotoSaida == "" && string.IsNullOrEmpty(medirSaida)) return;
        // câmera fixa, a mesma da clareira do Godot (foto e medição)
        cam.position = new Vector3(5.5f, 4.2f, 7.5f);
        cam.rotation = Quaternion.LookRotation(new Vector3(-1.5f, 1.0f, -9f) - cam.position);
        if (fotoSaida == "" || fotoTirada) return;
        fotoT += dt;
        if (fotoT < 8f) return;
        ScreenCapture.CaptureScreenshot(fotoSaida);
        fotoTirada = true;
        if (medirSaida == "") Invoke(nameof(Sair), 1.5f);
    }

    // foto da pegada: Valtheria.exe -pegada C:/caminho/pegada (grava _frente.png e _lado.png)
    // seis cavaleiros: espada+escudo, machado e adaga, em combate (frente) e fora dele (atrás)
    string pegadaSaida;
    float pegadaT;
    int pegadaFase;
    readonly List<(GameObject go, Animador a)> pegadaBonecos = new List<(GameObject, Animador)>();
    void PegadaAuto(float dt)
    {
        if (pegadaSaida == null)
        {
            var args = System.Environment.GetCommandLineArgs();
            pegadaSaida = "";
            for (int i = 0; i < args.Length - 1; i++) if (args[i] == "-pegada") pegadaSaida = args[i + 1];
            if (pegadaSaida == "") return;
            foreach (var l in lobos) { l.anim.Destruir(); Destroy(l.go); }
            lobos.Clear();
            jogador.transform.position = new Vector3(60, 0, 60);
            for (int i = 0; i < 6; i++)
            {
                bool combate = i < 3;
                var tipo = (Empunho.Arma)(i % 3);
                var pos = new Vector3(((i % 3) - 1) * 1.3f + (combate ? 0f : 0.4f), 0, combate ? 0f : 2.2f);
                var g = NovoCavaleiro(pos, out var a);
                g.transform.rotation = Quaternion.Euler(0, 180f, 0);
                a.Tocar(combate ? "Sword_Idle" : "Idle");
                var emp = Equipar(g, a, tipo, tipo == Empunho.Arma.Espada);
                emp.emCombate = combate;
                pegadaBonecos.Add((g, a));
            }
        }
        if (pegadaSaida == "") return;
        foreach (var b in pegadaBonecos) b.a.Atualizar(dt);
        pegadaT += dt;
        // câmeras: frente e lado das duas fileiras, depois de perto (machado e adaga, frente e lado)
        var cams = new (Vector3 p, Vector3 o, string n)[] {
            (new Vector3(0, 1.3f, -3.6f), new Vector3(0, 1.05f, 0.6f), "_frente"),
            (new Vector3(-4.2f, 1.3f, 1.0f), new Vector3(0, 1.05f, 1.0f), "_lado"),
            (new Vector3(0.2f, 1.25f, -1.7f), new Vector3(0, 1.05f, 0f), "_machado_frente"),
            (new Vector3(-1.6f, 1.25f, -0.4f), new Vector3(0, 1.05f, 0f), "_machado_lado"),
            (new Vector3(1.5f, 1.25f, -1.7f), new Vector3(1.3f, 1.05f, 0f), "_adaga_frente"),
            (new Vector3(0.7f, 1.25f, 0.9f), new Vector3(-0.9f, 1.0f, 2.2f), "_escudo_normal") };
        if (pegadaFase < cams.Length)
        {
            cam.position = cams[pegadaFase].p;
            cam.rotation = Quaternion.LookRotation(cams[pegadaFase].o - cam.position);
            if (pegadaT > 5f) { ScreenCapture.CaptureScreenshot(pegadaSaida + cams[pegadaFase].n + ".png"); pegadaFase++; pegadaT = 4.6f; }
        }
        else if (pegadaFase == cams.Length) { pegadaFase++; Invoke(nameof(Sair), 1.5f); }
    }
    // foto das raças (26/11): Valtheria.exe -racas C:/caminho/racas (grava _frente.png, _perto.png e _lado.png)
    // os 12 corpos do Godot (mesmo esqueleto, mesmas texturas), parados em fila, na mesma ordem da foto do Godot
    static readonly string[] RACAS = { "humano_m", "humano_f", "elfo_m", "elfo_f", "sombrio_m", "sombrio_f", "orc_m", "orc_f", "anao_m", "anao_f", "gigante_m", "gigante_f" };
    static readonly float[] ALTURAS = { 1.8f, 1.68f, 1.85f, 1.75f, 1.82f, 1.72f, 2.0f, 1.87f, 1.36f, 1.3f, 2.6f, 2.45f };
    string racasSaida;
    float racasT;
    int racasFase;
    readonly List<Animador> racasAnim = new List<Animador>();
    void RacasAuto(float dt)
    {
        if (racasSaida == null)
        {
            var args = System.Environment.GetCommandLineArgs();
            racasSaida = "";
            for (int i = 0; i < args.Length - 1; i++) if (args[i] == "-racas") racasSaida = args[i + 1];
            if (racasSaida == "") return;
            foreach (var l in lobos) { l.anim.Destruir(); Destroy(l.go); }
            lobos.Clear();
            jogador.transform.position = new Vector3(60, 0, 60);
            // palco limpo, como no estúdio do Godot: some com a natureza e o jogador; chão cinza liso
            foreach (var go in UnityEngine.SceneManagement.SceneManager.GetActiveScene().GetRootGameObjects())
                if (go != gameObject && go.GetComponentInChildren<Light>() == null && go.GetComponentInChildren<Camera>() == null && go.GetComponentInChildren<Canvas>() == null) go.SetActive(false);
            jogador.SetActive(false);
            var chaoR = GameObject.CreatePrimitive(PrimitiveType.Plane);
            chaoR.transform.localScale = new Vector3(4, 1, 4);
            if (lit == null) lit = Shader.Find("Universal Render Pipeline/Lit");
            chaoR.GetComponent<Renderer>().sharedMaterial = new Material(lit) { color = new Color(0.24f, 0.26f, 0.28f) };
            for (int i = 0; i < RACAS.Length; i++)
            {
                var pref = Resources.Load<GameObject>("Valtheria/Racas/" + RACAS[i]);
                if (pref == null) { Debug.LogWarning("sem raça " + RACAS[i]); continue; }
                var g = Instantiate(pref, new Vector3((i - (RACAS.Length - 1) * 0.5f) * 1.25f, 0, 0), Quaternion.Euler(0, 180f - 20f, 0));
                if (lit == null) lit = Shader.Find("Universal Render Pipeline/Lit");
                var m = new Material(lit) { name = RACAS[i], enableInstancing = true };
                var t = Resources.Load<Texture2D>("Valtheria/Racas/Texturas/" + RACAS[i] + "_cor");
                if (t != null) m.SetTexture("_BaseMap", t);
                m.SetFloat("_Smoothness", 0.25f);
                foreach (var r in g.GetComponentsInChildren<Renderer>())
                {
                    var arr = r.sharedMaterials;
                    for (int k = 0; k < arr.Length; k++) arr[k] = m;
                    if (arr.Length == 0) arr = new[] { m };
                    r.sharedMaterials = arr;
                    r.shadowCastingMode = ShadowCastingMode.On;
                }
                Ajustar(g, ALTURAS[i]);
                var a = new Animador(g, Resources.LoadAll<AnimationClip>("Valtheria/Racas/" + RACAS[i]));
                a.Tocar("Idle");
                racasAnim.Add(a);
            }
        }
        if (racasSaida == "") return;
        foreach (var a in racasAnim) a.Atualizar(dt);
        racasT += dt;
        var cams = new (Vector3 p, Vector3 o, string n)[] {
            (new Vector3(0, 1.4f, -17.5f), new Vector3(0, 1.1f, 0), "_frente"),
            (new Vector3(-4.4f, 1.7f, -2.2f), new Vector3(-4.4f, 1.62f, 0), "_perto"),
            (new Vector3(1.25f, 1.9f, -3.0f), new Vector3(1.25f, 1.7f, 0), "_perto2") };
        if (racasFase < cams.Length)
        {
            cam.position = cams[racasFase].p;
            cam.rotation = Quaternion.LookRotation(cams[racasFase].o - cam.position);
            if (racasT > 6f) { ScreenCapture.CaptureScreenshot(racasSaida + cams[racasFase].n + ".png"); racasFase++; racasT = 5.4f; }
        }
        else if (racasFase == cams.Length) { racasFase++; Invoke(nameof(Sair), 1.5f); }
    }
    void Sair() { Application.Quit(); }
    void LateUpdate() { FotoAuto(Time.deltaTime); PegadaAuto(Time.deltaTime); RacasAuto(Time.deltaTime); }

    void MedirAuto(float dt)
    {
        if (medirSaida == null)
        {
            var args = System.Environment.GetCommandLineArgs();
            medirSaida = "";
            for (int i = 0; i < args.Length - 1; i++) if (args[i] == "-medir") medirSaida = args[i + 1];
            if (medirSaida == "") return;
            medirFase = 0; medirT = 0; Extras(MEDIR_N[0]);
            medirJson.Append("{\n");
        }
        if (medirSaida == "" || medirFase < 0) return;
        medirT += dt;
        if (medirT > 3f) medirQuadros.Add(dt);
        if (medirT < 18f) return;
        var l = new List<float>(medirQuadros); l.Sort();
        float soma = 0; foreach (var q in l) soma += q;
        int n = Mathf.Max(1, l.Count / 100);
        float pior = 0; for (int i = l.Count - n; i < l.Count; i++) pior += l[i];
        medirJson.Append($"  \"extras_{MEDIR_N[medirFase]}\": {{\"fps_medio\": {(l.Count / Mathf.Max(0.0001f, soma)).ToString("0.0", System.Globalization.CultureInfo.InvariantCulture)}, \"fps_1pct_baixo\": {(n / Mathf.Max(0.0001f, pior)).ToString("0.0", System.Globalization.CultureInfo.InvariantCulture)}, \"quadros\": {l.Count}}},\n");
        medirQuadros.Clear(); medirT = 0; medirFase++;
        if (medirFase < MEDIR_N.Length) { Extras(MEDIR_N[medirFase]); return; }
        medirJson.Append($"  \"placa_de_video\": \"{SystemInfo.graphicsDeviceName}\", \"api\": \"{SystemInfo.graphicsDeviceVersion}\", \"processador\": \"{SystemInfo.processorType}\", \"janela\": \"{Screen.width}x{Screen.height}\", \"unity\": \"{Application.unityVersion}\"\n}}\n");
        System.IO.File.WriteAllText(medirSaida, medirJson.ToString());
        medirFase = -1;
        Application.Quit();
    }

    void Update()
    {
        float dt = Time.deltaTime;
        Medir(dt);
        MedirAuto(dt);
        int f = Entrada.TeclaF();
        if (f == 1) Extras(0); else if (f == 2) Extras(20); else if (f == 3) Extras(40);

        // câmera em terceira pessoa (botão direito gira, roda aproxima)
        if (Entrada.Girar()) { var d = Entrada.MouseDelta(); yaw += d.x * 3f; pitch = Mathf.Clamp(pitch - d.y * 3f, 5f, 60f); }
        dist = Mathf.Clamp(dist - Entrada.Roda() * 0.8f, 3f, 14f);

        if (vidaJ > 0) MoverJogador(dt);
        animJ.Atualizar(dt);
        var alvoCam = jogador.transform.position + Vector3.up * 1.5f;
        var rot = Quaternion.Euler(pitch, yaw, 0);
        cam.position = Vector3.Lerp(cam.position, alvoCam - rot * Vector3.forward * dist, 1f - Mathf.Exp(-dt * 10f));
        cam.rotation = Quaternion.Slerp(cam.rotation, Quaternion.LookRotation(alvoCam - cam.position), 1f - Mathf.Exp(-dt * 12f));

        foreach (var l in lobos) AtualizarLobo(l, dt);
        for (int i = 0; i < extras.Count; i++)
        {
            var e = extras[i];
            if (e.a.Atual == "Walk")
            {
                float t = Time.time * 0.5f + e.fase;
                e.go.transform.position = e.c + new Vector3(Mathf.Cos(t), 0, Mathf.Sin(t)) * 1.5f;
                e.go.transform.rotation = Quaternion.LookRotation(new Vector3(-Mathf.Sin(t), 0, Mathf.Cos(t)));
            }
            e.a.Atualizar(dt);
        }
        textos.RemoveAll(t => Time.time > t.ate);
        if (lobos.TrueForAll(l => l.morto) && lobos.Count > 0 && Time.time > lobos[0].caiu + 4f)
        {
            foreach (var l in lobos) { l.anim.Destruir(); Destroy(l.go); }
            lobos.Clear();
            for (int i = 0; i < 5; i++) NovoLobo(jogador.transform.position + new Vector3(Random.Range(-25f, 25f), 0, Random.Range(-25f, 25f)));
        }
    }

    void MoverJogador(float dt)
    {
        var e = Entrada.Eixo();
        var frente = Quaternion.Euler(0, yaw, 0) * Vector3.forward;
        var direita = Quaternion.Euler(0, yaw, 0) * Vector3.right;
        var mov = frente * e.y + direita * e.x;
        bool emCombate = lobos.Exists(l => !l.morto && (l.go.transform.position - jogador.transform.position).magnitude < 12f);
        if (empJ != null) empJ.emCombate = emCombate || animJ.Ocupado;

        if (Entrada.Atacar() && !animJ.Ocupado)
        {
            combo = (combo + 1) % 3;
            string g = combo == 0 ? "Sword_Regular_A" : (combo == 1 ? "Sword_Regular_B" : "Sword_Regular_C");
            float dur = animJ.Tocar(g, 1.15f, true);
            golpeEm = Time.time + dur * 0.4f;
            golpePendente = true;
            var alvo = LoboMaisPerto(4f);
            if (alvo != null)
            {
                var d = alvo.go.transform.position - jogador.transform.position; d.y = 0;
                if (d.sqrMagnitude > 0.01f) jogador.transform.rotation = Quaternion.LookRotation(d);
            }
        }
        if (golpePendente && Time.time >= golpeEm)
        {
            golpePendente = false;
            var alvo = LoboMaisPerto(3.0f);
            if (alvo != null) Acertar(alvo, Random.Range(18, 30) * (Random.value < 0.12f ? 2 : 1));
        }
        if (animJ.Ocupado) return;

        if (mov.sqrMagnitude > 0.01f)
        {
            bool corre = Entrada.Correr();
            float vel = corre ? 7.5f : 4.2f;
            jogador.transform.position += mov * vel * dt;
            jogador.transform.rotation = Quaternion.Slerp(jogador.transform.rotation, Quaternion.LookRotation(mov), 1f - Mathf.Exp(-dt * 12f));
            animJ.Tocar(corre ? "Sprint" : "Jog_Fwd");
        }
        else animJ.Tocar(emCombate && animJ.Tem("Sword_Idle") ? "Sword_Idle" : "Idle");
    }

    Lobo LoboMaisPerto(float alcance)
    {
        Lobo melhor = null; float md = alcance;
        foreach (var l in lobos)
        {
            if (l.morto) continue;
            float d = (l.go.transform.position - jogador.transform.position).magnitude;
            if (d < md) { md = d; melhor = l; }
        }
        return melhor;
    }

    void Acertar(Lobo l, int dano)
    {
        l.vida -= dano;
        l.pisca = 0.12f;
        var dir = (l.go.transform.position - jogador.transform.position); dir.y = 0;
        l.empurrao = dir.normalized * 6f;
        textos.Add((l.go.transform.position + Vector3.up * 2.3f, "-" + dano, dano > 35 ? new Color(1f, 0.85f, 0.3f) : new Color(1f, 0.55f, 0.4f), Time.time + 0.9f));
        if (l.vida <= 0 && !l.morto) { l.morto = true; l.caiu = Time.time; }
    }

    void AtualizarLobo(Lobo l, float dt)
    {
        var t = l.go.transform;
        if (l.morto)
        {
            // sem animação de morte no pacote: tomba de lado
            float k = Mathf.Clamp01((Time.time - l.caiu) / 0.6f);
            t.rotation = Quaternion.Slerp(t.rotation, Quaternion.LookRotation(t.forward) * Quaternion.Euler(0, 0, 85f), k * 0.2f);
            l.anim.Atualizar(0f);
            return;
        }
        var pj = jogador.transform.position;
        float d = (pj - t.position).magnitude;
        Vector3 alvo = l.destino;
        bool persegue = d < 14f && vidaJ > 0;
        if (persegue) alvo = pj;
        else if ((l.destino - t.position).magnitude < 1f) l.destino = t.position + new Vector3(Random.Range(-10f, 10f), 0, Random.Range(-10f, 10f));
        var dir = alvo - t.position; dir.y = 0;
        if (dir.magnitude > (persegue ? 1.8f : 0.5f))
        {
            float vel = persegue ? 4.6f : 1.6f;
            t.position += dir.normalized * vel * dt;
            t.rotation = Quaternion.Slerp(t.rotation, Quaternion.LookRotation(dir), 1f - Mathf.Exp(-dt * 6f));
            l.anim.Tocar(persegue ? "run" : "walk");
        }
        else if (persegue && Time.time > l.proxAtaque)
        {
            l.proxAtaque = Time.time + 1.6f;
            int dano = Random.Range(8, 16);
            vidaJ = Mathf.Max(0, vidaJ - dano);
            textos.Add((pj + Vector3.up * 2.1f, "-" + dano, new Color(1f, 0.35f, 0.3f), Time.time + 0.9f));
            if (!animJ.Ocupado) animJ.Tocar(Random.value < 0.35f ? "Hit_Head" : "Hit_Chest", 1f, true);
            if (vidaJ <= 0) animJ.Tocar("Death01", 1f, true);
        }
        // recuo ao levar golpe e clarão branco
        t.position += l.empurrao * dt;
        l.empurrao = Vector3.MoveTowards(l.empurrao, Vector3.zero, dt * 30f);
        l.pisca -= dt;
        var cor = l.pisca > 0 ? new Color(2.2f, 2.2f, 2.2f) : Color.white;
        foreach (var r in l.rs) { r.GetPropertyBlock(l.mpb); l.mpb.SetColor("_BaseColor", cor); r.SetPropertyBlock(l.mpb); }
        l.anim.Atualizar(dt);
    }

    void Medir(float dt)
    {
        quadros.Enqueue(dt);
        while (quadros.Count > 300) quadros.Dequeue();
        tFps += dt;
        if (tFps < 0.5f) return;
        tFps = 0;
        var lista = new List<float>(quadros);
        float soma = 0; foreach (var q in lista) soma += q;
        fpsMed = lista.Count / Mathf.Max(0.0001f, soma);
        lista.Sort();
        int n = Mathf.Max(1, lista.Count / 100);
        float pior = 0; for (int i = lista.Count - n; i < lista.Count; i++) pior += lista[i];
        fpsBaixo = n / Mathf.Max(0.0001f, pior);
    }

    void OnGUI()
    {
        if (!string.IsNullOrEmpty(fotoSaida) || !string.IsNullOrEmpty(pegadaSaida)) return;  // fotos sem o painel
        var est = new GUIStyle(GUI.skin.label) { fontSize = 16 };
        GUI.color = new Color(0, 0, 0, 0.55f);
        GUI.DrawTexture(new Rect(8, 8, 430, 118), Texture2D.whiteTexture);
        GUI.color = Color.white;
        GUI.Label(new Rect(16, 12, 420, 24), $"FPS médio {fpsMed:0}   |   1% mais lento {fpsBaixo:0}", est);
        GUI.Label(new Rect(16, 34, 420, 24), $"Cavaleiros extras: {extras.Count}   Lobisomens: {lobos.FindAll(l => !l.morto).Count}", est);
        GUI.Label(new Rect(16, 56, 420, 24), $"Vida: {vidaJ:0}/{vidaMaxJ:0}   Placa: {SystemInfo.graphicsDeviceName}", est);
        GUI.Label(new Rect(16, 78, 420, 24), "WASD anda, Shift corre, clique/Espaço ataca", est);
        GUI.Label(new Rect(16, 100, 420, 24), "Botão direito gira a câmera, F1/F2/F3 = 0/20/40 extras", est);
        foreach (var t in textos)
        {
            var sp = Camera.main.WorldToScreenPoint(t.p + Vector3.up * (0.9f - (t.ate - Time.time)) * 0.8f);
            if (sp.z < 0) continue;
            var s = new GUIStyle(GUI.skin.label) { fontSize = 22, fontStyle = FontStyle.Bold };
            s.normal.textColor = t.c;
            GUI.Label(new Rect(sp.x - 30, Screen.height - sp.y - 12, 120, 30), t.t, s);
        }
    }

    void OnDestroy()
    {
        animJ?.Destruir();
        foreach (var l in lobos) l.anim?.Destruir();
        foreach (var e in extras) e.a?.Destruir();
    }
}
