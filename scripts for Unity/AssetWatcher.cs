using UnityEngine;
using UnityEditor;
using System.IO;

namespace ProceduralImport
{
    public class AssetWatcher : AssetPostprocessor
    {
        private static readonly string ImportPath = "Assets/ProceduralImport/Imported";
        private static readonly string MetadataPattern = "*_metadata.json";
        private static bool isChecking = false;

        [InitializeOnLoadMethod]
        private static void InitializeWatcher()
        {
            EditorApplication.update += CheckForNewAssets;
        }

        private static void CheckForNewAssets()
        {
            if (isChecking) return;
            isChecking = true;

            try
            {
                if (!Directory.Exists(ImportPath))
                {
                    Directory.CreateDirectory(ImportPath);
                    return;
                }

                string[] metadataFiles = Directory.GetFiles(
                    ImportPath, MetadataPattern, SearchOption.TopDirectoryOnly);

                foreach (string rawPath in metadataFiles)
                {
                    string metadataPath = rawPath.Replace("\\", "/");

                    string json = File.ReadAllText(metadataPath);
                    Metadata metadata = JsonUtility.FromJson<Metadata>(json);

                    if (metadata == null || string.IsNullOrEmpty(metadata.material_name))
                        continue;

                    string materialPath = ImportPath + "/" + metadata.material_name + ".mat";
                    if (AssetDatabase.LoadAssetAtPath<Material>(materialPath) != null)
                        continue;

                    CreateMaterial(metadata, ImportPath);
                }
            }
            catch (System.Exception e)
            {
                Debug.LogError($"[ProceduralImport] Ошибка проверки ассетов: {e.Message}");
            }
            finally
            {
                isChecking = false;
            }
        }

        private static void CreateMaterial(Metadata metadata, string folderPath)
        {
            Shader shader = Shader.Find("Universal Render Pipeline/Lit")
                         ?? Shader.Find("Standard");

            if (shader == null)
            {
                Debug.LogError("[ProceduralImport] Не найден шейдер URP/Lit или Standard!");
                return;
            }

            Material material   = new Material(shader);
            material.name       = metadata.material_name;

            SetupTextures(material, metadata, folderPath);
            SetupParameters(material, metadata);

            string materialPath = $"{folderPath}/{metadata.material_name}.mat";
            AssetDatabase.CreateAsset(material, materialPath);
            AssetDatabase.SaveAssets();
            AssetDatabase.Refresh();

            Debug.Log($"[ProceduralImport] Материал создан: {materialPath}");
        }

        private static void SetupTextures(Material material, Metadata metadata, string folderPath)
        {
            if (metadata.textures == null) return;

            if (!string.IsNullOrEmpty(metadata.textures.albedo))
            {
                string texPath = folderPath + "/" + metadata.textures.albedo;

                if (AssetImporter.GetAtPath(texPath) == null)
                    AssetDatabase.Refresh();

                ConfigureTextureImport(texPath, TextureImporterType.Default, sRGB: true);

                Texture2D tex = AssetDatabase.LoadAssetAtPath<Texture2D>(texPath);
                if (tex != null)
                {
                    material.SetTexture("_BaseMap", tex);
                    material.SetTexture("_MainTex", tex);
                    Debug.Log($"[ProceduralImport] Albedo назначен: {tex.name}");
                }
                else
                {
                    Debug.LogWarning($"[ProceduralImport] Albedo не найден по пути: {texPath}");
                }
            }

            if (!string.IsNullOrEmpty(metadata.textures.normal))
            {
                string texPath = folderPath + "/" + metadata.textures.normal;

                ConfigureTextureImport(texPath, TextureImporterType.NormalMap, sRGB: false);

                Texture2D tex = AssetDatabase.LoadAssetAtPath<Texture2D>(texPath);
                if (tex != null)
                {
                    material.SetTexture("_BumpMap", tex);
                    material.EnableKeyword("_NORMALMAP");
                    Debug.Log($"[ProceduralImport] Normal map назначен: {tex.name}");
                }
            }

            if (!string.IsNullOrEmpty(metadata.textures.roughness))
            {
                string texPath = folderPath + "/" + metadata.textures.roughness;

                ConfigureTextureImport(texPath, TextureImporterType.Default, sRGB: false);

                Texture2D tex = AssetDatabase.LoadAssetAtPath<Texture2D>(texPath);
                if (tex != null)
                {
                    material.SetTexture("_MetallicGlossMap", tex);
                    Debug.Log($"[ProceduralImport] Roughness назначен: {tex.name}");
                }
            }
        }

        private static void ConfigureTextureImport(
            string assetPath,
            TextureImporterType type,
            bool sRGB)
        {
            TextureImporter importer = AssetImporter.GetAtPath(assetPath) as TextureImporter;
            if (importer == null) return;

            bool changed = false;

            if (importer.textureType != type)
            {
                importer.textureType = type;
                changed = true;
            }

            if (importer.sRGBTexture != sRGB)
            {
                importer.sRGBTexture = sRGB;
                changed = true;
            }

            if (changed)
            {
                importer.SaveAndReimport();
            }
        }

        private static void SetupParameters(Material material, Metadata metadata)
        {
            if (metadata.@params == null) return;

            float glossiness = 1.0f - metadata.@params.roughness;
            material.SetFloat("_Glossiness", glossiness);
            material.SetFloat("_Smoothness", glossiness);

            material.SetFloat("_Metallic", metadata.@params.specular);

            Debug.Log($"[ProceduralImport] Параметры применены: " +
                      $"glossiness={glossiness:F2}, " +
                      $"metallic={metadata.@params.specular:F2}");
        }
    }

    [System.Serializable]
    public class Metadata
    {
        public string      version;
        public string      exported_at;
        public string      material_name;
        public TextureData textures;
        public ParamsData  @params;
    }

    [System.Serializable]
    public class TextureData
    {
        public string albedo;
        public string normal;
        public string roughness;
        public string metallic;
        public string ao;
        public string height;
    }

    [System.Serializable]
    public class ParamsData
    {
        public float scale;
        public float threshold;
        public float wave_speed;
        public float roughness;
        public float specular;
        public float metallic;
    }
}
