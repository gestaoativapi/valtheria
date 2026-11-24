// Gera o executável do protótipo sem abrir o editor:
// Unity.exe -batchmode -quit -projectPath <projeto> -executeMethod GerarValtheria.Windows
using UnityEditor;
using UnityEditor.Build.Reporting;
using UnityEngine;

public static class GerarValtheria
{
    public static void Windows()
    {
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
