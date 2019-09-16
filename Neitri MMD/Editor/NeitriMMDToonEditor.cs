using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEditor;

public class NeitriMMDToonEditor : ShaderGUI
{
	static class Presets
	{ 
	
		static void AddPresets()
		{
			Action<NeitriMMDToonEditor> reset = (NeitriMMDToonEditor t) =>
			{
				t.SetTexture("_Ramp", "1283d592696f77545b70f4b513c72188");
				t.SetFloat("_Shadow", 0.4f); // ramp weight
				t.SetTexture("_Matcap", "d6064d42d7ffecd4cba07c5bd929b6d5");
				t.SetFloat("_MatcapWeight", 0.15f);
				t.SetColor("_MatcapTint", new Color(1f, 1f, 1f, 1f));
				t.SetColor("_ShadowColor", new Color(0f, 0f, 0f, 1f));
				t.SetColor("_ShadowRim", new Color(0f, 0f, 0f, 1f));

				t.SetFloat("_BakedLightingFlatness", 0.9f);
				t.SetFloat("_ApproximateFakeLight", 0.7f);
				t.SetFloat("_AlphaCutout", 0.05f);
				t.SetFloat("_ForceLightDirectionToForward", 0.3f);
				t.SetFloat("_Cull", 2);
				t.SetFloat("_ZTest", 4);
			};

			AddPreset("Default", "Reverts all changes to default values", (NeitriMMDToonEditor t) =>
			{
				reset(t);
			});


			Action<NeitriMMDToonEditor> skin = (NeitriMMDToonEditor t) =>
			{
				t.SetTexture("_Matcap", "c897b2f4ac59d7a47979f27af3221229");
				t.SetFloat("_MatcapWeight", 0.5f);
				t.SetFloat("_MatcapType", 2);
				t.SetColor("_MatcapTint", new Color(1f, 1f, 1f, 1f));
				t.SetColor("_ShadowRim", new Color(0.3f, 0f, 0f, 1f));
			};

			AddPreset("Skin", "", (NeitriMMDToonEditor t) =>
			{
				reset(t);
				skin(t);
			});

			AddPreset("Skin +", "", (NeitriMMDToonEditor t) =>
			{
				reset(t);
				skin(t);
				t.SetTexture("_Ramp", "3dc80c595a9f8a948acef6614efe394a");
			});


			AddPreset("Rimlight", "", (NeitriMMDToonEditor t) =>
			{
				reset(t);
				t.SetFloat("_MatcapWeight", 1f);
				t.SetFloat("_MatcapType", 1);
				t.SetTexture("_Matcap", "0c2d781f9138bb74394b78913767973c");
				t.SetColor("_ShadowRim", new Color(0f, 0f, 0f, 1f));
			});

			// TODO: Face, Body, Hair, Silk, Leather, Metal, Carbon fibre
		}


		public struct Preset
		{
			public string Name;
			public string Description;
			public Action<NeitriMMDToonEditor> Action;
		}

		static List<Preset> PresetsList = new List<Preset>();
		static void AddPreset(string Name, string Description, Action<NeitriMMDToonEditor> Preset)
		{
			PresetsList.Add(new Preset() { Name = Name, Description = Description, Action = Preset });
		}

		public static List<Preset> GetPresets()
		{
			if (PresetsList.Count == 0)
			{
				AddPresets();
			}

			return PresetsList;
		}
	}



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

		{
			GUILayout.BeginHorizontal();
			GUILayout.Label("Presets", GUILayout.ExpandWidth(false));
			foreach (var preset in Presets.GetPresets())
			{
				if (GUILayout.Button(new GUIContent(preset.Name, preset.Description), GUILayout.ExpandWidth(false)))
				{
					Undo.RecordObjects(materials.ToArray(), "Preset " + preset.Name);
					preset.Action(this);
				}
			}

			GUILayout.EndHorizontal();
		}

		materialEditor.SetDefaultGUIWidths();

		foreach (MaterialProperty property in properties)
		{
			if ((property.flags & MaterialProperty.PropFlags.PerRendererData) != 0) continue;
			if ((property.flags & MaterialProperty.PropFlags.HideInInspector) != 0) continue;

			string displayName = property.displayName;

			bool isAdvanced = false;
			string advancedString = " -advanced";
			int advancedIndex = displayName.IndexOf(advancedString);
			if (advancedIndex != -1)
			{
				displayName = displayName.Remove(advancedIndex, advancedString.Length);
				isAdvanced = true;
			}

			if (!ShowAdvanced && isAdvanced) continue;

			float propertyHeight = materialEditor.GetPropertyHeight(property, displayName);
			Rect controlRect = EditorGUILayout.GetControlRect(true, propertyHeight, EditorStyles.layerMaskField, new GUILayoutOption[0]);
			materialEditor.ShaderProperty(controlRect, property, displayName);
		}

		if (ShowAdvanced)
		{
			materialEditor.RenderQueueField();
		}		

		GUILayout.Space(10);
		if (ShowAdvanced)
		{
			if (GUILayout.Button("Hide advanced settings"))
			{
				ShowAdvanced = false;
			}
		}
		else
		{
			if (GUILayout.Button("Show advanced settings"))
			{
				ShowAdvanced = true;
			}
		}
	}



	public void SetTexture(string name, string guid)
	{
		foreach (var material in materials)
		{
			SetTexture(material, name, guid);
		}
	}

	public void SetColor(string name, Color color)
	{
		foreach (var material in materials)
		{
			material.SetColor(name, color);
		}
	}

	public void SetFloat(string name, float value)
	{
		foreach (var material in materials)
		{
			material.SetFloat(name, value);
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

	public static void SetTexture(Material material, string name, string guid)
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

