// by Neitri, free of charge, free to redistribute
// downloaded from https://github.com/netri/Neitri-Unity-Shaders

// both "transoarent" shaders actually have to be in geometry queue, beause we want them to be shadowed the same as opaque
// ZWrite On is for big geometry such as transparent hair where you want it to occlude it self

Shader "Neitri/MMD Transparent ZWrite On" {
	Properties{
		[Header(Main)]
		[KeywordEnum(None, Skin)] _SHADER_TYPE ("Shader specialization", Float) = 0
		_MainTex ("_MainTex", 2D) = "white" {}
        _Color ("_Color", Color) = (1,1,1,1)

		[Header(Emission)]
		_EmissionMap ("_EmissionMap", 2D) = "black" {}
		_EmissionColor ("_EmissionColor", Color) = (0,0,0,1)
		
		[Header(Direct or point or vertex lights)]
		_Shadow ("_Shadow", Range(0, 1)) = 0.4
		_Smoothness ("_Smoothness", Range(0, 1)) = 0

		[Header(Light probes)]
		_IndirectLightingFlatness ("_IndirectLightingFlatness", Range(0, 1)) = 0.9

		[Header(Color over time)]
		[Toggle(_COLOR_OVER_TIME_ON)] _COLOR_OVER_TIME_ON ("Enable", Float) = 0
		_ColorOverTime_Ramp ("Ramp", 2D) = "white" {}
		_ColorOverTime_Speed ("Speed", float) = 0.1

		[Header(Raymarcher)]
		[KeywordEnum(None, Spheres, Hearts)] _RAYMARCHER_TYPE ("Type", Float) = 0
		_Raymarcher_Scale("Scale", Range(0.5, 1.5)) = 1.0
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
				Cull Off
				Blend SrcAlpha OneMinusSrcAlpha
				ZWrite On
				CGPROGRAM
				#pragma vertex vert
				#pragma fragment frag
				#define UNITY_PASS_FORWARDBASE
				#include "Base.cginc"
				#pragma only_renderers d3d11 glcore gles
				#pragma target 4.0
				#pragma multi_compile_fwdbase
				#pragma multi_compile_fog
				#pragma multi_compile _ _SHADER_TYPE_SKIN
				#pragma multi_compile _ _RAYMARCHER_TYPE_SPHERES _RAYMARCHER_TYPE_HEARTS 
				#pragma multi_compile _ _COLOR_OVER_TIME_ON
				ENDCG
			}
			Pass {
				Name "FORWARD_DELTA"
				Tags {
					"LightMode" = "ForwardAdd"
				}
				Cull Off
				Blend SrcAlpha One
				ZWrite On
				Fog { Color(0,0,0,0) }
				ZTest LEqual
				CGPROGRAM
				#pragma vertex vert
				#pragma fragment frag
				#define UNITY_PASS_FORWARDADD
				#include "Base.cginc"
				#pragma only_renderers d3d11 glcore gles
				#pragma target 4.0
				#pragma multi_compile_fwdadd_fullshadows
				#pragma multi_compile_fog
				#pragma multi_compile _ _SHADER_TYPE_SKIN
				#pragma multi_compile _ _RAYMARCHER_TYPE_SPHERES _RAYMARCHER_TYPE_HEARTS 
				#pragma multi_compile _ _COLOR_OVER_TIME_ON
				ENDCG
			}
	}
	FallBack "Standard"
}