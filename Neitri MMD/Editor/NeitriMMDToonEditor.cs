using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEditor;

public class NeitriMMDToonEditor : ShaderGUI
{
	static bool ShowPresets = true;
	static bool ShowAdvanced = false;

	List<Material> materials = new List<Material>();
	public override void OnGUI(MaterialEditor materialEditor, MaterialProperty[] properties)
	{
		materials.Clear();
		foreach (var obj in materialEditor.targets)
		{
			Material material = obj as Material;
			if (!material) continue;
			materials.Add(material);
		}

		ShowAdvanced = EditorGUILayout.Toggle("Show Advanced", ShowAdvanced);
		ShowPresets = EditorGUILayout.Foldout(ShowPresets, "Presets", Styles.foldoutBold);

		if (ShowPresets)
		{
			GUILayout.BeginHorizontal();

			if (GUILayout.Button(new GUIContent("Default", "Reverts changes done by other presets to default values"), GUILayout.ExpandWidth(false)))
			{
				SetTexture("_Ramp", "96ad26bf5aa0f2147b6c1651287c1ae6");
				SetTexture("_Matcap", "fc97398b94ec4c74faef69b1cb644ae2");
				SetColor("_ShadowColor", new Color(0f, 0f, 0f, 1f));
				SetColor("_ShadowRim", new Color(0.8f, 0.8f, 0.8f, 1f));
			}

			if (GUILayout.Button(new GUIContent("Skin", "Changes shading ramp, shadow color, shadow rim, to skin like values"), GUILayout.ExpandWidth(false)))
			{
				SetTexture("_Ramp", "56d182764dfbf6747955d65bfa1a79e0");
				SetTexture("_Matcap", "dc916bfb70935a74f9fc1461d7945a15");
				SetColor("_ShadowColor", new Color(0.2f, 0f, 0f, 1f));
				SetColor("_ShadowRim", new Color(1f, 0.66f, 0.66f, 1f));
			}

			GUILayout.EndHorizontal();
		}

		materialEditor.SetDefaultGUIWidths();

		foreach (MaterialProperty property in properties)
		{
			if ((property.flags & MaterialProperty.PropFlags.PerRendererData) != 0) continue;
			if (ShowAdvanced == false && (property.flags & MaterialProperty.PropFlags.HideInInspector) != 0) continue;

			float propertyHeight = materialEditor.GetPropertyHeight(property, property.displayName);
			Rect controlRect = EditorGUILayout.GetControlRect(true, propertyHeight, EditorStyles.layerMaskField, new GUILayoutOption[0]);
			materialEditor.ShaderProperty(controlRect, property, property.displayName);
		}

		if (ShowAdvanced)
		{
			materialEditor.RenderQueueField();
		}
	}



	void SetTexture(string name, string guid)
	{
		foreach(var material in materials)
		{
			SetTexture(material, name, guid);
		}
	}

	void SetColor(string name, Color color)
	{
		foreach(var material in materials)
		{
			material.SetColor(name, color);
		}
	}


	static Texture2D FindTextureByGuid(string guid)
	{
		string assetPath = AssetDatabase.GUIDToAssetPath(guid);
		if (string.IsNullOrEmpty(assetPath)) return null;
		Texture2D texture = AssetDatabase.LoadAssetAtPath<Texture2D>(assetPath);
		if (!texture) return null;
		return texture;
	}

	static void SetTexture(Material material, string name, string guid)
	{
		if (string.IsNullOrEmpty(name)) return;
		if (!material) return;
		Texture2D texture = FindTextureByGuid(guid);
		if (!texture) return;
		material.SetTexture(name, texture);
	}

	static class Styles
	{ 
		public static GUIStyle foldoutBold = new GUIStyle(EditorStyles.foldout);

		static Styles()
		{
			foldoutBold.fontStyle = FontStyle.Bold;
		}
	}

}

