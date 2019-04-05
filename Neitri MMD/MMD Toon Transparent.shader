// by Neitri, free of charge, free to redistribute
// downloaded from https://github.com/netri/Neitri-Unity-Shaders

// has to be in geometry queue, beause we want it to be shadowed the same as opaque

Shader "Neitri/MMD Toon Transparent" {
	Properties{
		[Header(Main)] 
		_MainTex ("Texture", 2D) = "white" {}
		_Color ("Color", Color) = (1,1,1,1)
		_Glossiness ("Glossiness", Range(0, 1)) = 0

		[Header(Normal)] 
		_BumpMap("Normal Map", 2D) = "bump" {}
		_BumpScale("Weight", Range(0, 2)) = 0

		[Header(Emission)]
		_EmissionMap ("Texture", 2D) = "black" {}
		[HDR] _EmissionColor ("Color", Color) = (1,1,1,1)
		
		[Header(Lighting Adjustments)]
		_UseRamp ("Enable Shadow Ramp", Range(0, 1)) = 1
		_LightCastedShadowDarkness ("Shadows darkness", Range(0, 1)) = 0.9
		_BakedLightingFlatness ("Baked lighting flatness", Range(0, 1)) = 0.7
		
		[Header(Shadow Ramp Disabled)]
		_Shadow ("Direction shading darkness", Range(0, 1)) = 1
		_DirectionShadingSmoothness ("Direction shading smoothness", Range(0, 2)) = 1.5

		[Header(Shadow Ramp Enabled)]
		[NoScaleOffset] _Ramp("Shadow Ramp", 2D) = "white" {}

		[Header(Change color over time)]
		_UseColorOverTime ("Enable", Range(0, 1)) = 0 // [Toggle(_COLOR_OVER_TIME_ON)]
		_ColorOverTime_Ramp ("Colors Texture", 2D) = "white" {}
		_ColorOverTime_Speed ("Time Speed Multiplier", Range(0.01, 10)) = 0.1

		[Header(Raymarched Pattern)]
		_Raymarcher_Type ("Type", Range(0, 2)) = 0 // [Enum(None,Spheres,Hearts)] 
		_Raymarcher_Scale("Scale", Range(0.5, 1.5)) = 1.0

		[Header(Other)]
		[Enum(UnityEngine.Rendering.CullMode)] _Cull ("Cull", Float) = 2
		[Enum(UnityEngine.Rendering.CompareFunction)] _ZTest ("ZTest", Float) = 4
	}
	SubShader{
		Tags {
			"Queue" = "Geometry+400"
			"RenderType" = "Transparent"
		}
		Pass {
			Name "ForwardBase"
			Tags {
				"LightMode" = "ForwardBase"
			}
			Cull [_Cull]
			ZTest [_ZTest]
			Blend SrcAlpha OneMinusSrcAlpha
			AlphaToMask Off
			ZWrite Off
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#define UNITY_PASS_FORWARDBASE
			#define IS_TRANSPARENT_SHADER
			#pragma only_renderers d3d11 glcore gles
			#pragma target 2.0
			#pragma multi_compile_fwdbase
			#pragma multi_compile_fog
			#pragma shader_feature _ _RAYMARCHER_TYPE_SPHERES _RAYMARCHER_TYPE_HEARTS 
			#pragma shader_feature _ _COLOR_OVER_TIME_ON
			#pragma shader_feature _ _DITHERED_TRANSPARENCY_ON
			#include "Base.cginc"
			ENDCG
		}
		Pass {
			Name "ForwardAdd"
			Tags {
				"LightMode" = "ForwardAdd"
			}
			Cull [_Cull]
			ZTest [_ZTest]
			Blend SrcAlpha One
			AlphaToMask Off
			ZWrite Off
			Fog { Color(0,0,0,0) }
			ZTest LEqual
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#define UNITY_PASS_FORWARDADD
			#define IS_TRANSPARENT_SHADER
			#pragma only_renderers d3d11 glcore gles
			#pragma target 2.0
			#pragma multi_compile_fwdadd_fullshadows
			#pragma multi_compile_fog
			#include "Base.cginc"
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
			#define IS_TRANSPARENT_SHADER
			#include "Base.cginc"
			ENDCG
		}
	}
	FallBack Off
}