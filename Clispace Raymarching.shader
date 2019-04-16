// by Neitri, free of charge, free to redistribute
// downloaded from https://github.com/netri/Neitri-Unity-Shaders

// Example on how to construct world space ray from clispace uv
Shader "Neitri/Clispace Raymarching"
{
	Properties
	{
		_MainTex ("Texture", 2D) = "white" {}
	}
	SubShader
	{
		Tags {
			"Queue"="Overlay+10"
			"RenderType"="Overlay" 
			"ForceNoShadowCasting"="True"
			"IgnoreProjector"="True"
			"DisableBatching" = "True"
		}

		ZWrite On
		ZTest Less 
		Cull Off
		Blend One Zero

		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			
			#include "UnityCG.cginc"

			sampler2D _Gradient;
			sampler2D _BackgroundTexture;

			struct VertIn
			{
				float2 uv : TEXCOORD0;
			};

			struct VertToFrag
			{
				float4 vertex : SV_POSITION;
				float2 uv : TEXCOORD0;
			};
			
			struct FragOut
			{
				float depth : SV_Depth;
				float4 color : SV_Target;
			};

			VertToFrag vert (VertIn v)
			{
				VertToFrag o;
				o.vertex = float4(v.uv * 2 - 1, 0, 1);
				#ifdef UNITY_UV_STARTS_AT_TOP
					v.uv.y = 1-v.uv.y;
				#endif
				o.uv = UnityStereoTransformScreenSpaceTex(v.uv);
				return o;
			}

			float distanceFunction(float3 p)
			{
				// 1 sphere
				return length(p) - 0.5;

				// grid of spheres
				const float spacing = 0.1;
				const float size = 0.01;
				return length(abs(fmod(p, spacing * 2)) - spacing) - size;
			}


			float2 raymarch(float3 from, float3 direction) 
			{
				float totalDistance = 0.0;
				float3 currentPos = from;
				int steps = 0;

				#define MIN_RAY_DISTANCE 0.0002
				#define MAX_RAY_DISTANCE 200
				#define MAX_RAY_STEPS 100

				[loop]
				for (steps = 0; steps < MAX_RAY_STEPS; steps++) 
				{
					float distance = distanceFunction(currentPos);
					currentPos += distance * direction;
					totalDistance += distance;

					if (distance < MIN_RAY_DISTANCE) 
					{
						return float2(totalDistance, steps/(float)(MAX_RAY_STEPS));
					}

					if (totalDistance > MAX_RAY_DISTANCE) 
					{
						return float2(MAX_RAY_DISTANCE, 1);
					}
				}

				return float2(totalDistance, steps/(float)(MAX_RAY_STEPS));
 			}


			FragOut frag (VertToFrag i)
			{
				float3 worldSpaceRayStart = _WorldSpaceCameraPos;
				
				// construct ray direction
				float4 clipSpacePosition = float4(i.uv.xy * 2 - 1, 1, 1);
				float4 cameraSpacePosition = mul(unity_CameraInvProjection, clipSpacePosition);
				float4 worldSpacePosition = mul(unity_MatrixInvV, cameraSpacePosition);
				float3 worldSpaceRayDirection = normalize(worldSpacePosition.xyz / worldSpacePosition.w - worldSpaceRayStart);

				// move ray start forward a bit
				worldSpaceRayStart += worldSpaceRayDirection * _ProjectionParams.y * 5;

				float2 raymarchResult = raymarch(worldSpaceRayStart, worldSpaceRayDirection);

				// discard if we hit nothing
				clip(0.99 - raymarchResult.y);

				FragOut fragOut;
				
				fragOut.color = 1 - raymarchResult.y;
				fragOut.color.a = 1;

				clipSpacePosition = mul(UNITY_MATRIX_VP, float4(worldSpaceRayStart + worldSpaceRayDirection * raymarchResult.x, 1.0));
				fragOut.depth = clipSpacePosition.z / clipSpacePosition.w;
		
				return fragOut;
			}
			ENDCG
		}
	}
}
