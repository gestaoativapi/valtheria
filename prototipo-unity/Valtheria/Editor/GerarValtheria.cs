// Gera o executável do protótipo sem abrir o editor:
// Unity.exe -batchmode -quit -projectPath <projeto> -executeMethod GerarValtheria.Windows
using UnityEditor;
using UnityEditor.Build.Reporting;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using UnityEditor.SceneManagement;

public static class GerarValtheria
{
    const string NAT = "Assets/Valtheria/Resources/Valtheria/Natureza/";

    // materiais da natureza como arquivos (assim o Unity inclui as variações de sombreador no executável)
    static void Mat(string nome, string tex, bool corte, Vector2 repete, float liso = 0.1f, string normal = null)
    {
        System.IO.Directory.CreateDirectory(NAT + "Mats");
        string caminho = NAT + "Mats/" + nome + ".mat";
        var m = AssetDatabase.LoadAssetAtPath<Material>(caminho);
        bool novo = m == null;
        if (novo) m = new Material(Shader.Find("Universal Render Pipeline/Lit"));
        var t = tex == null ? null : AssetDatabase.LoadAssetAtPath<Texture2D>(tex);
        if (t != null) { m.SetTexture("_BaseMap", t); m.SetTextureScale("_BaseMap", repete); }
        if (normal != null)
        {
            var n = AssetDatabase.LoadAssetAtPath<Texture2D>(normal);
            if (n != null) { m.SetTexture("_BumpMap", n); m.EnableKeyword("_NORMALMAP"); }
        }
        m.SetColor("_BaseColor", Color.white);
        m.SetFloat("_Smoothness", liso);
        m.SetFloat("_Metallic", 0f);
        if (corte)
        {
            m.SetFloat("_AlphaClip", 1f); m.SetFloat("_Cutoff", 0.45f); m.EnableKeyword("_ALPHATEST_ON");
            m.SetFloat("_Cull", 0f); m.doubleSidedGI = true;
            m.renderQueue = (int)RenderQueue.AlphaTest;
        }
        m.enableInstancing = true;
        if (novo) AssetDatabase.CreateAsset(m, caminho); else EditorUtility.SetDirty(m);
    }

    public static void Preparar()
    {
        string T = NAT + "Texturas/";
        Mat("Bark_NormalTree", T + "Bark_NormalTree.png", false, Vector2.one, 0.05f, T + "Bark_NormalTree_Normal.png");
        Mat("Leaves_NormalTree", T + "Leaves_NormalTree_C.png", true, Vector2.one, 0.15f);
        Mat("Leaves_Pine", T + "Leaf_Pine_C.png", true, Vector2.one, 0.15f);
        Mat("Leaves_TwistedTree", T + "Leaves_TwistedTree_C.png", true, Vector2.one, 0.15f);
        Mat("Leaves", T + "Leaves.png", true, Vector2.one, 0.15f);
        Mat("Flowers", T + "Flowers.png", true, Vector2.one, 0.15f);
        Mat("Rocks", T + "Rocks_Diffuse.png", false, Vector2.one, 0.2f);
        Mat("Atlas", T + "Atlas.png", false, Vector2.one, 0.2f);
        Mat("Chao", T + "t_grass.png", false, new Vector2(70, 70), 0.08f);
        Mat("Terra", T + "t_dirt.png", false, new Vector2(8, 8), 0.08f);
        // céu: o mesmo do jogo é um shader próprio; aqui o céu procedural do Unity com tons parecidos
        string ceu = NAT + "Mats/Ceu.mat";
        var c = AssetDatabase.LoadAssetAtPath<Material>(ceu);
        if (c == null) { c = new Material(Shader.Find("Skybox/Procedural")); AssetDatabase.CreateAsset(c, ceu); }
        c.SetFloat("_SunSize", 0.035f); c.SetFloat("_AtmosphereThickness", 0.85f);
        c.SetColor("_SkyTint", new Color(0.56f, 0.62f, 0.68f)); c.SetColor("_GroundColor", new Color(0.42f, 0.43f, 0.4f));
        c.SetFloat("_Exposure", 1.15f);
        EditorUtility.SetDirty(c);
        AssetDatabase.SaveAssets();

        // cena: névoa ligada e céu (senão o Unity tira a névoa do executável)
        var cena = EditorSceneManager.OpenScene("Assets/Scenes/SampleScene.unity");
        RenderSettings.fog = true;
        RenderSettings.fogMode = FogMode.Linear;
        RenderSettings.skybox = c;
        EditorSceneManager.MarkSceneDirty(cena);
        EditorSceneManager.SaveScene(cena);

        // sombras: distância e cascatas parecidas com o jogo
        var lista = new System.Collections.Generic.List<RenderPipelineAsset>();
        if (GraphicsSettings.defaultRenderPipeline != null) lista.Add(GraphicsSettings.defaultRenderPipeline);
        for (int i = 0; i < QualitySettings.names.Length; i++)
        {
            var q = QualitySettings.GetRenderPipelineAssetAt(i);
            if (q != null) lista.Add(q);
        }
        foreach (var a in lista)
        {
            if (a is UniversalRenderPipelineAsset u)
            {
                u.shadowDistance = 90f;
                u.shadowCascadeCount = 2;
                EditorUtility.SetDirty(u);
            }
        }
        AssetDatabase.SaveAssets();
    }

    public static void Windows()
    {
        Preparar();
        var cenas = new System.Collections.Generic.List<string>();
        foreach (var c in EditorBuildSettings.scenes) if (c.enabled) cenas.Add(c.path);
        if (cenas.Count == 0) cenas.Add("Assets/Scenes/SampleScene.unity");
        PlayerSettings.productName = "Valtheria Unity Prototipo";
        PlayerSettings.fullScreenMode = FullScreenMode.Windowed;
        PlayerSettings.defaultScreenWidth = 1600;
        PlayerSettings.defaultScreenHeight = 900;
        var r = BuildPipeline.BuildPlayer(new BuildPlayerOptions
        {
            scenes = cenas.ToArray(),
            locationPathName = "Build/ValtheriaUnity.exe",
            target = BuildTarget.StandaloneWindows64,
            options = BuildOptions.None
        });
        Debug.Log("GERAR_VALTHERIA " + r.summary.result + " " + r.summary.totalSize);
        EditorApplication.Exit(r.summary.result == BuildResult.Succeeded ? 0 : 1);
    }
}
