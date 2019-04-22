using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEditor;

public class NeitriMMDToonEditor : ShaderGUI
{
	static bool ShowPresets = true;
	public override void OnGUI(MaterialEditor materialEditor, MaterialProperty[] properties)
	{
		/*
		ShowPresets = EditorGUILayout.Foldout(ShowPresets, "Presets");
		if (ShowPresets)
		{
			GUILayout.BeginHorizontal();

			MaterialProperty _Ramp = FindProperty("_Ramp", properties);

			if (GUILayout.Button("Default", GUILayout.ExpandWidth(false)))
			{
			}

			if (GUILayout.Button("Skin", GUILayout.ExpandWidth(false)))
			{
			}

			if (GUILayout.Button("Cloth", GUILayout.ExpandWidth(false)))
			{
			}

			GUILayout.EndHorizontal();
		}
		*/
		base.OnGUI(materialEditor, properties);
	}
}

