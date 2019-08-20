// by Neitri, free of charge, free to redistribute
// downloaded from https://github.com/netri/Neitri-Unity-Shaders

Shader "Neitri/MMD Toon Opaque" {
	Properties {
		[Header(Main)] 
		_MainTex ("Texture", 2D) = "white" {}
		_Color ("Color", Color) = (1,1,1,1)
		_Glossiness ("Glossiness", Range(0, 1)) = 0

		[Header(Normal Map)]
		_BumpMap("Normal Map", 2D) = "bump" {}
		_BumpScale("Weight", Range(0, 2)) = 0

		[Header(Emission)]
		[Enum(Disabled,0,Glow always,1,Glow only in darkness,2)] _EmissionType("Emission Type", Range(0, 2)) = 0
		_EmissionMap ("Texture", 2D) = "white" {}
		[HDR] _EmissionColor ("Color", Color) = (1,1,1,1)

		[Header(Shading Ramp)]
		[HDR] _RampColorAdjustment("Color -advanced", Color) = (1,1,1,1)
		_ShadingRampStretch("Ramp stretch -advanced", Range(0, 1)) = 0
		[NoScaleOffset] _Ramp("Ramp -advanced", 2D) = "white" {}

		[Header(Matcap)]
		[Enum(Disabled,0,Add to final color,1,Multiply final color,2,Multiply by light color then add to final color,3)] _MatcapType("Type -advanced", Range(0, 3)) = 2
		[HDR] _MatcapTint("Color -advanced", Color) = (1,1,1,1)
		[Enum(Anchored to direction to camera,0,Anchored to camera rotation,1,Anchored to world up,2)] _MatcapAnchor("Anchor -advanced", Range(0, 2)) = 0
		[NoScaleOffset] _Matcap("Matcap -advanced", 2D) = "white" {}

		[Header(Shadow)]
		_ShadowColor ("Shadow color -advanced", Color) = (0,0,0,1)
		_ShadowRim("Shadow rim color -advanced", Color) = (0.8,0.8,0.8,1)
		//_ShadowRimWeight("Shadow rim weight", Range(0, 1)) = 0.7

		[Header(Baked Lighting)]
		_BakedLightingFlatness ("Baked lighting flatness -advanced", Range(0, 1)) = 0.9
		_ApproximateFakeLight("Approximate fake light -advanced", Range(0, 1)) = 0.7

		[Header(Other)]
		_AlphaCutout("Alpha Cutout", Range(0, 1)) = 0.05
		[Enum(Show in both,0,Show only in mirror,1,Dont show in mirror,2)] _ShowInMirror("Show in mirror -advanced", Range(0, 2)) = 0
		_ForceLightDirectionToForward("Force light to come from forward -advanced", Range(0, 1)) = 0.3
		[Enum(Disabled,0,Anchored to camera,1,Anchored to texture coordinates,2)] _DitheredTransparencyType("Dithered transparency -advanced", Range(0, 2)) = 0
		[Enum(UnityEngine.Rendering.CullMode)] _Cull ("Cull -advanced", Float) = 2
		[Enum(UnityEngine.Rendering.CompareFunction)] _ZTest ("ZTest -advanced", Float) = 4
		
		//[Toggle(_)] _UseContactDeformation ("Contact Deformation", Range(0, 1)) = 0
		//[Toggle(_)] _DebugInt1("Debug Int 1", Range(0, 1)) = 1
		//[Toggle(_)] _DebugInt2("Debug Int 2", Range(0, 1)) = 1
		//_DebugFloat1("Debug Float 1", Range(0, 1)) = 1
	}
	SubShader {
		Tags {
			"Queue" = "Geometry"
			"RenderType" = "Opaque"
		}
		
		Pass {
			Name "ForwardBase"
			Tags { "LightMode" = "ForwardBase" }
			Cull [_Cull]
			ZTest [_ZTest]
			Blend One Zero
			AlphaToMask On
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#ifndef UNITY_PASS_FORWARDBASE
				#define UNITY_PASS_FORWARDBASE
			#endif
			#pragma only_renderers d3d11 glcore gles
			#pragma target 2.0
			#pragma multi_compile_fwdbase
			#pragma multi_compile_fog
			#include "Base.cginc"
			ENDCG
		}
		Pass {
			Name "ForwardAdd"
			Tags { "LightMode" = "ForwardAdd" }
			Cull [_Cull]
			ZTest [_ZTest]
			Blend SrcAlpha One
			AlphaToMask On
			ZWrite Off
			Fog { Color (0,0,0,0) }
			ZTest LEqual
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#ifndef UNITY_PASS_FORWARDADD
				#define UNITY_PASS_FORWARDADD
			#endif
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
			#include "Base.cginc"
			ENDCG
		}
	}	
	FallBack Off
	CustomEditor "NeitriMMDToonEditor"
}