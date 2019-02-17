// by Neitri, free of charge, free to redistribute
// downloaded from https://github.com/netri/Neitri-Unity-Shaders

Shader "Neitri/MMD Toon Opaque" {
	Properties {
		[KeywordEnum(None, Skin, Cloth)] _SHADER_TYPE ("Shader specialization", Float) = 0

		[Header(Main)] 
		_MainTex ("Texture", 2D) = "white" {}
		_Color ("Color", Color) = (1,1,1,1)

		[Header(Normal)] 
		_BumpMap("Normal Map", 2D) = "bump" {}
		_BumpScale("Weight", Float) = 0

		[Header(Emission)]
		_EmissionMap ("Texture", 2D) = "black" {}
		_EmissionColor ("Color", Color) = (1,1,1,1)
		
		[Header(Other)]
		_Glossiness ("Glossiness", Range(0, 1)) = 0
		_Shadow ("Direction shading darkness", Range(0, 1)) = 0.4
		_DirectionShadingSmoothness ("Direction shading smoothness", Range(0, 2)) = 2
		_LightCastedShadowDarkness ("Light shadows darkness", Range(0, 1)) = 0.9
		_BakedLightingFlatness ("Baked lighting flatness", Range(0, 1)) = 0.7

		[Header(Change color over time)]
		[Toggle(_COLOR_OVER_TIME_ON)] _COLOR_OVER_TIME_ON ("Enable", Float) = 0
		_ColorOverTime_Ramp ("Colors Texture", 2D) = "white" {}
		_ColorOverTime_Speed ("Time Speed Multiplier", Float) = 0.1

		[Header(Raymarched Pattern)]
		[KeywordEnum(None, Spheres, Hearts)] _RAYMARCHER_TYPE ("Type", Float) = 0
		_Raymarcher_Scale("Scale", Range(0.5, 1.5)) = 1.0

		[Header(Other)]
		[Enum(UnityEngine.Rendering.CullMode)] _Cull ("Cull", Float) = 2
		[Toggle(_DITHERED_TRANSPARENCY_ON)] _DITHERED_TRANSPARENCY_ON ("Dithered Transparency", Float) = 0
		//[Toggle(_MESH_DEFORMATION_ON)] _MESH_DEFORMATION_ON ("Mesh Deformation", Float) = 0
	}
	SubShader {
		Tags {
			"Queue" = "Geometry"
			"RenderType" = "Opaque"
		}
		
		Pass {
			Name "FORWARD"
			Tags { "LightMode" = "ForwardBase" }
			Cull [_Cull]
			Blend SrcAlpha OneMinusSrcAlpha
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#include "Base.cginc"
			#define UNITY_PASS_FORWARDBASE
			#pragma only_renderers d3d11 glcore gles
			#pragma target 2.0
			#pragma multi_compile_fwdbase
			#pragma multi_compile_fog
			#pragma shader_feature _ _SHADER_TYPE_SKIN _SHADER_TYPE_CLOTH _SHADER_TYPE_HAIR
			#pragma shader_feature _ _RAYMARCHER_TYPE_SPHERES _RAYMARCHER_TYPE_HEARTS 
			#pragma shader_feature _ _COLOR_OVER_TIME_ON
			//#pragma shader_feature _ _MESH_DEFORMATION_ON
			#pragma shader_feature _ _DITHERED_TRANSPARENCY_ON
			ENDCG
		}
		Pass {
			Name "FORWARD_DELTA"
			Tags { "LightMode" = "ForwardAdd" }
			Cull [_Cull]
			Blend SrcAlpha One
			ZWrite Off
			Fog { Color (0,0,0,0) }
			ZTest LEqual
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#define UNITY_PASS_FORWARDADD
			#include "Base.cginc"
			#pragma only_renderers d3d11 glcore gles
			#pragma target 2.0
			#pragma multi_compile_fwdadd_fullshadows
			#pragma multi_compile_fog
			#pragma shader_feature _ _SHADER_TYPE_SKIN _SHADER_TYPE_CLOTH _SHADER_TYPE_HAIR
			#pragma shader_feature _ _RAYMARCHER_TYPE_SPHERES _RAYMARCHER_TYPE_HEARTS 
			#pragma shader_feature _ _COLOR_OVER_TIME_ON
			//#pragma shader_feature _ _MESH_DEFORMATION_ON
			#pragma shader_feature _ _DITHERED_TRANSPARENCY_ON
			ENDCG
		}
		Pass {
			Name "ShadowCaster"
			Tags { "LightMode" = "ShadowCaster" }
			ZWrite On
			ZTest LEqual
			CGPROGRAM
			#pragma target 2.0
			#pragma vertex vertShadowCaster
			#pragma fragment fragShadowCaster
			#include "Base.cginc"
			ENDCG
		}
	}
}