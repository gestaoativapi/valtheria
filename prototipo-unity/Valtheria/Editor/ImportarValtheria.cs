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
        var nomeTex = System.IO.Path.GetFileNameWithoutExtension(assetPath).ToLowerInvariant();
        if (nomeTex.EndsWith("_normal"))
        {
            ti.textureType = TextureImporterType.NormalMap;
        }
        ti.maxTextureSize = 1024;
        if (assetPath.Contains("Leaves") || assetPath.Contains("Leaf") || assetPath.Contains("Flowers"))
            ti.alphaIsTransparency = true;
    }

    void OnPreprocessModel()
    {
        if (!DoValtheria) return;
        var mi = (ModelImporter)assetImporter;
        if (assetPath.Contains("/Natureza/") || assetPath.Contains("/Vila/"))
        {
            // árvores, pedras e plantas (Quaternius, CC0, os mesmos do jogo): sem animação; o nome do material
            // vem do arquivo e o protótipo troca pelo material pronto da pasta Mats
            mi.animationType = ModelImporterAnimationType.None;
            mi.importAnimation = false;
            mi.materialImportMode = ModelImporterMaterialImportMode.ImportViaMaterialDescription;
            mi.globalScale = 1f;
            return;
        }
        if (assetPath.Contains("/Armas/") || assetPath.EndsWith("/espada.fbx"))
        {
            // armas e escudo (v38): o Empunho.cs lê os vértices para achar a ponta, o fio e a frente do escudo
            mi.animationType = ModelImporterAnimationType.None;
            mi.importAnimation = false;
            mi.isReadable = true;
            mi.materialImportMode = ModelImporterMaterialImportMode.ImportViaMaterialDescription;
            mi.globalScale = 1f;
            return;
        }
        mi.animationType = ModelImporterAnimationType.Generic;
        mi.importAnimation = true;
        mi.isReadable = true;  // o Empunho.cs mede o corpo (cápsulas) nos vértices da malha
        mi.materialImportMode = ModelImporterMaterialImportMode.None;
        mi.globalScale = 1f;
    }
}
