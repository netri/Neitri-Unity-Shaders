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
		[Enum(Disabled,0,Glow always,1,Glow only in darkness,2)] _EmissionType("Emission Type", Range(0, 2)) = 0
		_EmissionMap("Texture", 2D) = "black" {}
		[HDR] _EmissionColor("Color", Color) = (1,1,1,1)

		[Header(Shading Ramp)]
		[HDR] _RampColorAdjustment("Color", Color) = (1,1,1,1)
		_ShadingRampStretch("Ramp stretch", Range(0, 1)) = 0
		[NoScaleOffset] _Ramp("Ramp", 2D) = "white" {}

		[Header(Matcap)]
		[Enum(Disabled,0,Add to final color,1,Multiply final color,2,Multiply by light color then add to final color,3)] _MatcapType("Type", Range(0, 3)) = 2
		[HDR] _MatcapTint("Color", Color) = (1,1,1,1)
		[Enum(Anchored to direction to camera,0,Anchored to camera rotation,1,Anchored to world up,2)] _MatcapAnchor("Anchor", Range(0, 2)) = 0
		[NoScaleOffset] _Matcap("Matcap", 2D) = "white" {}

		[Header(Shadow)]
		[HDR] _ShadowColor("Shadow color", Color) = (0,0,0,1)

		[Header(Baked Lighting)]
		_BakedLightingFlatness("Baked lighting flatness", Range(0, 1)) = 0.9
		_ApproximateFakeLight("Approximate fake light", Range(0, 1)) = 0.7

		[Header(Other)]
		_AlphaCutout("Alpha Cutout", Range(0, 1)) = 0.05
		[Enum(UnityEngine.Rendering.CullMode)] _Cull("Cull", Float) = 2
		[Enum(UnityEngine.Rendering.CompareFunction)] _ZTest("ZTest", Float) = 4
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