// created by Neitri, free of charge, free to redistribute

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
			#include "DataLoadSave.cginc"

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

			[maxvertexcount(3)]
			void geom(uint primitiveId : SV_PrimitiveID, point appdata IN[1], inout PointStream<fragIn> stream) //  LineStream stream
			{
				//float _ParticlesAmount = 1; // [0, 1]
				//if (primitiveId % (101 - clamp(int(_ParticlesAmount * 100), 0, 100)) != 0) return;

				float2 uv = float2(
					fmod(primitiveId, PARTICLES_ON_EDGE)  / (PARTICLES_ON_EDGE - 1),
					floor(primitiveId / PARTICLES_ON_EDGE)  / (PARTICLES_ON_EDGE - 1)
				);

				float4 data1, data2;
				DataLoad(data1, data2, uv);				
				float3 position = data1.xyz;
				float3 speed = data2.xyz;
		
				// DEBUG
				//if (length(speed) > 100) position = float4(float2(intUv) / PARTICLES_ON_EDGE * 10, 0, 1);
				//position = float4(uv.x * 10, uv.y * 10, 0, 1);

				float4 posClip = mul(UNITY_MATRIX_VP, float4(position.xyz, 1));
				
				float2 earlyOut = posClip.xy / posClip.w;
				if (any(floor(abs(earlyOut.xy)))) return; // if x >= 1 || x <= -1 || y >= 1 || y <= -1


				float dist = distance(_WorldSpaceCameraPos, position.xyz);

				if (fmod(primitiveId, dist) > 10) return;

				fragIn o;
				float vl = length(speed.xyz);
				fixed cv = vl*0.5 + _SinTime.x;
				// modified IQ color palette, original: http://www.iquilezles.org/www/articles/palettes/palettes.htm
				o.color = (0.5 + 0.5*cos(3.14*2*(1*cv+fixed3(0.67,0,0.33))));
				o.color /= max(0.9, dist);
				
				o.position = posClip;
				stream.Append(o);
				/*
				float2 parent = float2(data1.w, data2.w);
				if (parent.x > 0)
				{
					DataLoad(data1, data2, parent);
					position = data1.xyz;
					speed = data2.xyz;

					posClip = mul(UNITY_MATRIX_VP, float4(position.xyz, 1));
					o.position = posClip;
				}
				else
				{
					float trailLength = clamp(vl, 0.0005, 0.003);
					if (vl == 0) speed.xyz = float3(0.001, 0, 0);
					else speed.xyz = speed.xyz / vl * trailLength;

					o.color = 0;
					o.position = mul(UNITY_MATRIX_VP, float4(position.xyz - speed.xyz, 1));
				}
				
				stream.Append(o);
				*/
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