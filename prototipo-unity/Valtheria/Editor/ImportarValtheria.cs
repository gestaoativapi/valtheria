// Protótipo Valtheria (Unity) — ajustes automáticos de importação dos arquivos em Assets/Valtheria.
// Texturas "Normal" viram mapa normal; modelos entram como "Generic", com as animações, sem criar materiais
// (o script do protótipo monta os materiais URP).
using UnityEditor;

public class ImportarValtheria : AssetPostprocessor
{
    bool DoValtheria => assetPath.Replace('\\', '/').Contains("/Valtheria/");

    void OnPreprocessTexture()
    {
        if (!DoValtheria) return;
        var ti = (TextureImporter)assetImporter;
        if (assetPath.Contains("Normal"))
        {
            ti.textureType = TextureImporterType.NormalMap;
        }
        ti.maxTextureSize = 1024;
    }

    void OnPreprocessModel()
    {
        if (!DoValtheria) return;
        var mi = (ModelImporter)assetImporter;
        mi.animationType = ModelImporterAnimationType.Generic;
        mi.importAnimation = true;
        mi.materialImportMode = ModelImporterMaterialImportMode.None;
        mi.globalScale = 1f;
    }
}
