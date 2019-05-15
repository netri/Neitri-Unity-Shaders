// idea by Nave, original: https://pastebin.com/Q43UPHf4

#if UNITY_EDITOR

using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEditor;

public class CreateParticlesMesh : MonoBehaviour
{
	[MenuItem("GameObject/Create Paricles Mesh")]
	static void DoIt()
	{
		int size = 256;

		var mesh = new Mesh();
		mesh.vertices = new Vector3[] { new Vector3(0, 0, 0) };
		mesh.triangles = new int[size * size * 3];
		mesh.bounds = new Bounds(new Vector3(0, 0, 0), new Vector3(1, 1, 1));
		string path = "Assets/" + size + "x" + size + ".asset";
		AssetDatabase.CreateAsset(mesh, path);
		EditorGUIUtility.PingObject(mesh);
	}
}
#endif