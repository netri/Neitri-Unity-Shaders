// by Neitri, free of charge, free to redistribute
// downloaded from https://github.com/netri/Neitri-Unity-Shaders

// has to be in geometry queue, beause we want it to be shadowed the same as opaque

Shader "Neitri/MMD Toon Transparent" {
	Properties{
		[Header(Main)]
		_MainTex("Texture", 2D) = "white" {}
		_Color("Color", Color) = (1,1,1,1)
		_Glossiness("Glossiness", Range(0, 1)) = 0

		[Header(Normal Map)]
		_BumpMap("Normal Map", 2D) = "bump" {}
		_BumpScale("Weight", Range(0, 2)) = 0

		[Header(Emission)]
		[Enum(Disabled,0,Glow always,1,Glow only in darkness,2)] _EmissionType("Emission Type", Range(0, 2)) = 1
		_EmissionMap("Texture", 2D) = "black" {}
		[HDR] _EmissionColor("Color", Color) = (1,1,1,1)

		[HideInInspector] [Header(Shading Ramp)]
		[HideInInspector] [HDR] _RampColorAdjustment("Color", Color) = (1,1,1,1)
		[HideInInspector] _ShadingRampStretch("Ramp stretch", Range(0, 1)) = 0
		[HideInInspector] [NoScaleOffset] _Ramp("Ramp", 2D) = "white" {}

		[HideInInspector] [Header(Matcap)]
		[HideInInspector] [Enum(Disabled,0,Add to final color,1,Multiply final color,2,Multiply by light color then add to final color,3)] _MatcapType("Type", Range(0, 3)) = 2
		[HideInInspector] [HDR] _MatcapTint("Color", Color) = (1,1,1,1)
		[HideInInspector] [Enum(Anchored to direction to camera,0,Anchored to camera rotation,1,Anchored to world up,2)] _MatcapAnchor("Anchor", Range(0, 2)) = 0
		[HideInInspector] [NoScaleOffset] _Matcap("Matcap", 2D) = "white" {}

		[HideInInspector] [Header(Shadow)]
		[HideInInspector] [HDR] _ShadowColor("Shadow color", Color) = (0,0,0,1)
		[HideInInspector] _ShadowRim("Shadow rim color", Color) = (0.8,0.8,0.8,1)

		[HideInInspector] [Header(Baked Lighting)]
		[HideInInspector] _BakedLightingFlatness("Baked lighting flatness", Range(0, 1)) = 0.9
		[HideInInspector] _ApproximateFakeLight("Approximate fake light", Range(0, 1)) = 0.7

		[HideInInspector] [Header(Other)]
		[HideInInspector] _AlphaCutout("Alpha Cutout", Range(0, 1)) = 0.05
		[HideInInspector][Enum(Show in both,0,Show only in mirror,1,Dont show in mirror,2)] _ShowInMirror("Show in mirror", Range(0, 2)) = 0
		[HideInInspector] _ForceLightDirectionToForward("Force light to come from forward", Range(0, 1)) = 0.3
		[HideInInspector] [Enum(UnityEngine.Rendering.CullMode)] _Cull("Cull", Float) = 2
		[HideInInspector] [Enum(UnityEngine.Rendering.CompareFunction)] _ZTest("ZTest", Float) = 4
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
			#ifndef UNITY_PASS_FORWARDBASE
				#define UNITY_PASS_FORWARDBASE
			#endif
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
			#ifndef UNITY_PASS_FORWARDADD
				#define UNITY_PASS_FORWARDADD
			#endif
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
			#ifndef UNITY_PASS_SHADOWCASTER
				#define UNITY_PASS_SHADOWCASTER
			#endif
			#define IS_TRANSPARENT_SHADER
			#include "Base.cginc"
			ENDCG
		}
	}
	FallBack Off
	CustomEditor "NeitriMMDToonEditor"
}