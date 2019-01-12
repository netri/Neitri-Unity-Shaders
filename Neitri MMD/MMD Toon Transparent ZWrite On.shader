// by Neitri, free of charge, free to redistribute
// downloaded from https://github.com/netri/Neitri-Unity-Shaders

// both "transoarent" shaders actually have to be in geometry queue, beause we want them to be shadowed the same as opaque
// ZWrite On is for big geometry such as transparent hair where you want it to occlude it self

Shader "Neitri/MMD Toon Transparent ZWrite On" {
	Properties{
		[KeywordEnum(None, Skin, Cloth)] _SHADER_TYPE ("Shader specialization", Float) = 0
		
		[Header(Main)] 
		_MainTex ("Texture", 2D) = "white" {}
		_Color ("Color", Color) = (1,1,1,1)

		[Header(Normal)] 
		_BumpMap("Normal Map", 2D) = "bump" {}
		_BumpScale("Scale", Float) = 0

		[Header(Emission)]
		_EmissionMap ("Texture", 2D) = "black" {}
		_EmissionColor ("Color", Color) = (1,1,1,1)
		
		[Header(Other)]
		_Glossiness ("Glossiness", Range(0, 1)) = 0
		_Shadow ("Surface direction shading darkness", Range(0, 1)) = 0.4
		_LightCastedShadowStrength ("Shadow from lights darkness", Range(0, 1)) = 0.9
		_IndirectLightingFlatness ("Baked lighting flatness", Range(0, 1)) = 0.7

		[Header(Change color over time)]
		[Toggle(_COLOR_OVER_TIME_ON)] _COLOR_OVER_TIME_ON ("Enable", Float) = 0
		_ColorOverTime_Ramp ("Colors Texture", 2D) = "white" {}
		_ColorOverTime_Speed ("Time Speed Multiplier", Float) = 0.1

		[Header(Raymarched Pattern)]
		[KeywordEnum(None, Spheres, Hearts)] _RAYMARCHER_TYPE ("Type", Float) = 0
		_Raymarcher_Scale("Scale", Range(0.5, 1.5)) = 1.0

		[Header(Other)]
		[Enum(UnityEngine.Rendering.CullMode)] _Cull ("Cull", Float) = 0
	}
	SubShader{
		Tags {
			"Queue" = "Geometry+400"
			"RenderType" = "Transparent"
		}
		Pass {
			Name "FORWARD"
			Tags {
				"LightMode" = "ForwardBase"
			}
			Cull [_Cull]
			Blend SrcAlpha OneMinusSrcAlpha
			ZWrite On
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#define UNITY_PASS_FORWARDBASE
			#define SUPPORT_TRANSPARENCY
			#include "Base.cginc"
			#pragma only_renderers d3d11 glcore gles
			#pragma target 4.0
			#pragma multi_compile_fwdbase
			#pragma multi_compile_fog
			#pragma shader_feature _ _SHADER_TYPE_SKIN _SHADER_TYPE_CLOTH _SHADER_TYPE_HAIR
			#pragma shader_feature _ _RAYMARCHER_TYPE_SPHERES _RAYMARCHER_TYPE_HEARTS 
			#pragma shader_feature _ _COLOR_OVER_TIME_ON
			ENDCG
		}
		Pass {
			Name "FORWARD_DELTA"
			Tags {
				"LightMode" = "ForwardAdd"
			}
			Cull [_Cull]
			Blend SrcAlpha One
			ZWrite On
			Fog { Color(0,0,0,0) }
			ZTest LEqual
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#define UNITY_PASS_FORWARDADD
			#define SUPPORT_TRANSPARENCY
			#include "Base.cginc"
			#pragma only_renderers d3d11 glcore gles
			#pragma target 4.0
			#pragma multi_compile_fwdadd_fullshadows
			#pragma multi_compile_fog
			#pragma shader_feature _ _SHADER_TYPE_SKIN _SHADER_TYPE_CLOTH _SHADER_TYPE_HAIR
			#pragma shader_feature _ _RAYMARCHER_TYPE_SPHERES _RAYMARCHER_TYPE_HEARTS 
			#pragma shader_feature _ _COLOR_OVER_TIME_ON
			ENDCG
		}
		UsePass "VertexLit/SHADOWCASTER"
	}
}