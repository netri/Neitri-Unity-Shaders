// created by Neitri, free of charge, free to redistribute
// downloaded from https://github.com/netri/Neitri-Unity-Shaders

Shader "Neitri/GPU Particles/Render"
{
	Properties
	{
		_ParticlesData ("_ParticlesData", 2D) = "white" {}
	}
	SubShader
	{
		Tags 
		{
			"Queue"="Transparent+1000"
			"IgnoreProjector"="True"
			"DisableBatching"="True"
			"RenderType"="Transparent"
		}

		Pass
		{
			Cull Back
			Blend One One
			ZWrite Off
			ZTest LEqual

			CGPROGRAM
			#pragma vertex vert
			#pragma geometry geom
			#pragma fragment frag

			#include "UnityCG.cginc"
			#include "Common.cginc"

			struct appdata
			{
			};

			struct fragIn
			{
				float4 position : SV_POSITION;
				fixed3 color : TEXCOORD0;
			};


			appdata vert (appdata v)
			{
				return v;
			}



//#define USE_POINT_STREAM
#define USE_TRIANGLE_STREAM


			[maxvertexcount(3)]
			void geom(uint primitiveId : SV_PrimitiveID, point appdata IN[1], 
#ifdef USE_POINT_STREAM
				inout PointStream<fragIn> pointStream
#endif
#ifdef USE_TRIANGLE_STREAM
				inout TriangleStream<fragIn> triangleStream
#endif
			) 
			{
				// reduce particle amount
				//float _ParticlesAmount = 1; // [0, 1]
				//if (primitiveId % (101 - clamp(int(_ParticlesAmount * 100), 0, 100)) != 0) return;

				float2 uv = float2(
					fmod(primitiveId, PARTICLES_ON_EDGE),
					floor(primitiveId / PARTICLES_ON_EDGE)
				);
				uv /= PARTICLES_ON_EDGE - 1;

				float4 data1, data2;
				DataLoad(data1, data2, uv);
				float3 position = data1.xyz;
				float3 speed = data2.xyz;
		
				// DEBUG
				//if (length(speed) > 100) position = float4(float2(intUv) / PARTICLES_ON_EDGE * 10, 0, 1);
				//position = float4(uv.x * 10, uv.y * 10, 0, 1);

				float4 posClip = mul(UNITY_MATRIX_VP, float4(position.xyz, 1));
				
				// early out check if particle is out of screen
				float2 earlyOut = posClip.xy / posClip.w;
				if (any(floor(abs(earlyOut.xy)))) return; // if x >= 1 || x <= -1 || y >= 1 || y <= -1

				float dist = distance(_WorldSpaceCameraPos, position.xyz);

				// reduce particles amount with distane
				//if (fmod(primitiveId, dist) > 20) return;

				// color based on particle data
				float speedLen = length(speed.xyz);
				fixed cv = 
					speedLen +
					_SinTime.x +
					length(uv) * 0.1 +
					snoise(position * 0.1).x * 0.1;


				// modified IQ color palette, original: http://www.iquilezles.org/www/articles/palettes/palettes.htm
				float3 color = (0.5 + 0.5*cos(3.14*2*(1*cv+fixed3(0.67,0,0.33))));
	
				// fade out as particle aproaches camera near plane
				//color *= 1 - smoothstep(_ProjectionParams.y, _ProjectionParams.y + 0.01, posClip.z/posClip.w);

#ifdef USE_POINT_STREAM
				color /= max(0.9, dist);

				fragIn o;
				o.color = color;
				o.position = posClip;
				pointStream.Append(o);
#endif

#ifdef USE_TRIANGLE_STREAM
				//color /= max(0.9, dist / 10);

				float scale = 0.0007;
				float rotation = primitiveId * 0.01;
				float sinValue = sin(rotation) * scale;
				float cosValue = cos(rotation) * scale;
				float2x2 rotationMat = {
					cosValue, -sinValue,
					sinValue, cosValue
				};

				const float2 d1 = float2(0, -1);
				const float2 d2 = float2(0.814181, 0.580611); // cos(360/3), sin(360/3)
				const float2 d3 = float2(-0.814181, 0.580611); // -cos(360/3), sin(360/3)

				float ratio = _ScreenParams.y / _ScreenParams.x;

				float2 coords;

				fragIn o;
				o.color = color;
				coords = mul(d1, rotationMat);
				o.position = posClip + float4(coords.x * ratio, coords.y, 0, 0);
				triangleStream.Append(o);

				coords = mul(d2, rotationMat);
				o.position = posClip + float4(coords.x * ratio, coords.y, 0, 0);
				triangleStream.Append(o);

				coords = mul(d3, rotationMat);
				o.position = posClip + float4(coords.x * ratio, coords.y, 0, 0);
				triangleStream.Append(o);
#endif

		
			}

			fixed4 frag (fragIn i) : SV_Target
			{
				return fixed4(i.color, 1);
			}
			ENDCG
		}
	}	
	FallBack Off
}