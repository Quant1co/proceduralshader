using UnityEngine;
using UnityEditor;

namespace ProceduralImport
{
    public class MaterialApplier : EditorWindow
    {
        private Material    selectedMaterial;
        private GameObject  targetObject;

        [MenuItem("Tools/Procedural Import/Apply Material")]
        public static void ShowWindow()
        {
            GetWindow<MaterialApplier>("Apply Procedural Material");
        }

        private void OnGUI()
        {
            GUILayout.Label("Применить процедурный материал", EditorStyles.boldLabel);
            EditorGUILayout.Space();

            targetObject = (GameObject)EditorGUILayout.ObjectField(
                "Target Object", targetObject, typeof(GameObject), true);

            selectedMaterial = (Material)EditorGUILayout.ObjectField(
                "Material", selectedMaterial, typeof(Material), false);

            EditorGUILayout.Space();

            GUI.enabled = (targetObject != null && selectedMaterial != null);
            if (GUILayout.Button("Применить материал"))
            {
                Renderer r = targetObject.GetComponent<Renderer>();
                if (r != null)
                {
                    Undo.RecordObject(r, "Apply Procedural Material");
                    r.sharedMaterial = selectedMaterial;
                    Debug.Log($"[ProceduralImport] Материал '{selectedMaterial.name}' " +
                              $"применён к '{targetObject.name}'");
                }
                else
                {
                    EditorUtility.DisplayDialog(
                        "Ошибка",
                        $"У объекта '{targetObject.name}' нет компонента Renderer.",
                        "OK");
                }
            }
            GUI.enabled = true;

            EditorGUILayout.Space();
            EditorGUILayout.HelpBox(
                "Пайплайн:\n" +
                "1. Нажать 'Запечь текстуру' в Godot\n" +
                "2. Нажать 'Открыть папку экспорта' в Godot\n" +
                "3. Скопировать PNG + JSON в Assets/ProceduralImport/Imported/\n" +
                "4. AssetWatcher создаст .mat автоматически\n" +
                "5. Выбрать объект сцены и применить материал здесь",
                MessageType.Info);
        }
    }
}
