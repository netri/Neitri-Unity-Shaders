// by Neitri, free of charge, free to redistribute
// downloaded from https://github.com/netri/Neitri-Unity-Shaders

Shader "Neitri/MMD Toon Opaque Raymarcher"
{
	Properties
	{
		// Surface properties
		[Header(Main)] 
		_MainTex ("Texture", 2D) = "white" {}
		_Color ("Color", Color) = (1,1,1,1)
		_Glossiness ("Glossiness", Range(0, 1)) = 0

		[Header(Normal Map)]
		_BumpScale("Weight", Range(0, 2)) = 0
		[Normal] _BumpMap("Normal Map", 2D) = "bump" {}

		[Header(Emission)]
		[Enum(Disabled,0,Glow always,1,Glow only in darkness,2)] _EmissionType("Emission Type", Range(0, 2)) = 0
		_EmissionMap ("Texture", 2D) = "black" {}
		[HDR] _EmissionColor ("Color", Color) = (1,1,1,1)

		// Core properties
		[Header(Shading Ramp)]
		_Shadow("Weight -advanced", Range(0, 1)) = 0.4
		[NoScaleOffset] _Ramp("Ramp -advanced", 2D) = "white" {}

		[Header(Matcap)]
		_MatcapWeight("Strength -advanced", Range(0, 1)) = 0.15
		[Enum(Add to final color,1,Multiply final color,2,Multiply by light color then add to final color,3)] _MatcapType("Type -advanced", Range(1, 3)) = 2
		[HDR] _MatcapTint("Tint -advanced", Color) = (1,1,1,1)
		[Enum(Anchored to direction to camera,0,Anchored to camera rotation,1,Anchored to world up,2)] _MatcapAnchor("Anchor -advanced", Range(0, 2)) = 0
		[NoScaleOffset] _Matcap("Matcap -advanced", 2D) = "white" {}

		[Header(Shadow)]
		_ShadowColor ("Shadow color -advanced", Color) = (0,0,0,1)
		_ShadowRim("Shadow rim color -advanced", Color) = (0,0,0,1)

		[Header(Baked Lighting)]
		_BakedLightingFlatness ("Baked lighting flatness -advanced", Range(0, 1)) = 0.9
		_ApproximateFakeLight("Approximate fake light -advanced", Range(0, 1)) = 0.7

		// [Header(Outline)] // only in Outline
		// [HDR] _OutlineColor("Color -advanced", Color) = (0.1,0.1,0.1,1) // only in Outline
		// _OutlineWidth("Width -advanced", Range(0, 10)) = 1 // only in Outline

		[Header(Raymarched Pattern)] // only in Raymarcher
		[Enum(None,0,Spheres,1,Hearts,2)] _Raymarcher_Type("Type", Range(0, 2)) = 1 // only in Raymarcher
		_Raymarcher_Scale("Scale", Range(0.1, 5)) = 1.0 // only in Raymarcher

		[Header(Other)]
		_AlphaCutout("Alpha Cutout", Range(0, 1)) = 0.05
		[Enum(Show in both,0,Show only in mirror,1,Dont show in mirror,2)] _ShowInMirror("Show in mirror -advanced", Range(0, 2)) = 0
		_LightSkew("Light Skew -advanced", Vector) = (1, 0.1, 1)
		[Enum(Disabled,0,Anchored to camera,1,Anchored to texture coordinates,2)] _DitheredTransparencyType("Dithered transparency -advanced", Range(0, 2)) = 0 // hide in Transparent
		[Enum(UnityEngine.Rendering.CullMode)] _Cull ("Cull -advanced", Float) = 2
		[Enum(UnityEngine.Rendering.CompareFunction)] _ZTest ("ZTest -advanced", Float) = 4
		
		//[Toggle(_)] _UseContactDeformation ("Contact Deformation", Range(0, 1)) = 0
		//[Toggle(_)] _DebugInt1("Debug Int 1", Range(0, 1)) = 1
		//[Toggle(_)] _DebugInt2("Debug Int 2", Range(0, 1)) = 1
		//_DebugFloat1("Debug Float 1", Range(0, 1)) = 1

		[HideInInspector] _Version("_Version", Float) = 0.1
	}
	SubShader
	{
		Tags { "Queue" = "Geometry" "RenderType" = "Opaque"	}

		CGINCLUDE

			#define CHANGE_DEPTH
			int _Raymarcher_Type;
			float _Raymarcher_Scale;
			#include "Neitri MMD Raymarcher.cginc"

			#include "Neitri MMD Surface.cginc"

			sampler2D _MainTex; float4 _MainTex_ST;
			fixed4 _Color;
			float _Glossiness; // name from Unity's standard
			sampler2D _EmissionMap; float4 _EmissionMap_ST; // name from Xiexe's
			fixed4 _EmissionColor;
			sampler2D _BumpMap; float4 _BumpMap_ST;
			float _BumpScale;

			void Surface(SurfaceIn i, inout SurfaceOut o)
			{
				fixed4 color = tex2D(_MainTex, TRANSFORM_TEX(i.uv0.xy, _MainTex));
				o.Albedo = color.rgb * _Color;
				o.Alpha = color.a;
				o.Smoothness = _Glossiness;
				o.Emission = tex2D(_EmissionMap, TRANSFORM_TEX(i.uv0.xy, _EmissionMap)) * _EmissionColor;
				o.Normal = UnpackNormal(tex2D(_BumpMap, TRANSFORM_TEX(i.uv0.xy, _BumpMap)));
				o.Normal = lerp(float3(0, 0, 1), o.Normal, _BumpScale);

				UNITY_BRANCH
				if (_Raymarcher_Type != 0)
				{
					float depth;
					float3 tint = 0;
					Raymarch(i.worldPos.xyz, tint, depth);
					o.Albedo.rgb *= tint;
					#ifdef CHANGE_DEPTH
						float realDepthWeight = i.color.r;
						o.Depth = lerp(depth, i.screenPos.z, realDepthWeight);
					#endif
				}

			}

		ENDCG
		
		Pass
		{
			Name "ForwardBase"
			Tags { "LightMode" = "ForwardBase" }
			Cull [_Cull]
			ZTest [_ZTest]
			Blend One Zero
			//AlphaToMask On
			CGPROGRAM
			#pragma vertex VertexProgram
			#pragma fragment FragmentProgram
			#ifndef UNITY_PASS_FORWARDBASE
				#define UNITY_PASS_FORWARDBASE
			#endif
			#pragma target 2.0
			#pragma only_renderers d3d11
			#pragma multi_compile_fwdbase
			#pragma multi_compile_fog
			#include "Neitri MMD Core.cginc"
			ENDCG
		}
		Pass
		{
			Name "ForwardAdd"
			Tags { "LightMode" = "ForwardAdd" }
			Cull [_Cull]
			ZTest [_ZTest]
			Blend SrcAlpha One
			//AlphaToMask On
			ZWrite Off
			Fog { Color (0,0,0,0) }
			ZTest LEqual
			CGPROGRAM
			#pragma vertex VertexProgram
			#pragma fragment FragmentProgram
			#ifndef UNITY_PASS_FORWARDADD
				#define UNITY_PASS_FORWARDADD
			#endif
			#pragma target 2.0
			#pragma only_renderers d3d11
			#pragma multi_compile_fwdadd_fullshadows
			#pragma multi_compile_fog
			#include "Neitri MMD Core.cginc"
			ENDCG
		}
		Pass
		{
			Name "ShadowCaster"
			Tags { "LightMode" = "ShadowCaster" }
			ZWrite On
			ZTest LEqual
			CGPROGRAM
			#pragma vertex VertexProgramShadowCaster
			#pragma fragment FragmentProgramShadowCaster
			#ifndef UNITY_PASS_SHADOWCASTER
				#define UNITY_PASS_SHADOWCASTER
			#endif
			#pragma target 2.0
			#pragma only_renderers d3d11
			#include "Neitri MMD Core.cginc"
			ENDCG
		}
	}	
	FallBack Off
	CustomEditor "NeitriMMDToonEditor"
}