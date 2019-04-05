Shader "Neitri/Clispace Raymarching "
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
				return length(p) - 0.5;

				const float spacing = 0.1;
				const float size = 0.01;
				return length(abs(fmod(p, spacing * 2)) - spacing) - size;
			}


			struct RayMarchResult
			{
				int steps;
				float distance;
			};

			RayMarchResult rayMarch(float3 from, float3 direction) 
			{
				const int maxSteps = 100;
				const float maxDistance = 200.0;
				const float minDistance = 0.0002;
    
				RayMarchResult result;
				result.distance = 0;

				float currentDistance;

				for(result.steps = 0; result.steps < maxSteps; result.steps++)
				{
					currentDistance = distanceFunction(from + direction * result.distance);
					if(currentDistance.x < minDistance || result.distance > maxDistance)
					{
						break;
					}
					result.distance += currentDistance;
				}

				return result;
 			}


			FragOut frag (VertToFrag i)
			{
				FragOut fragOut;

				float3 worldRayStart = _WorldSpaceCameraPos;
				
				// construct ray direction
				float4 a = float4(0, 0, 1, 1);
				a.xy = i.uv.xy * 2 - 1;
				float4 b = mul(unity_CameraInvProjection, a);
				float4 c = mul(unity_MatrixInvV, b);
				float3 worldRayDir = normalize(c.xyz / c.w - worldRayStart);

				// move ray start forward
				worldRayStart += worldRayDir * _ProjectionParams.y * 5;

				RayMarchResult rayMarchResult = rayMarch(worldRayStart, worldRayDir);
				fragOut.color = 1 - rayMarchResult.steps / 20;
				fragOut.color.a = 1;

				float4 clipPos = mul(UNITY_MATRIX_VP, float4(worldRayStart + worldRayDir * rayMarchResult.distance, 1.0));
				fragOut.depth = clipPos.z / clipPos.w;
		
				return fragOut;
			}
			ENDCG
		}
	}
}
