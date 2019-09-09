// created by Neitri, free of charge, free to redistribute

Shader "Neitri/GPU Particles/Attractor"
{
	Properties
	{
		_SimulationSpeed("_SimulationSpeed", Float) = 1
		_AttractionSpeed("_AttractionSpeed", Float) = 1
		_AttractionRadius("_AttractionRadius", Float) = 50
		_AttractorNoiseRadius("_AttractorNoiseRadius", Float) = 0.01
		_AttractorSphereRadius("_AttractorSphereRadius", Float) = 0.1
		_IdleNoiseWeight("_IdleNoiseWeight", Float) = 0.05
		_MaxForce("_MaxForce", Float) = 1
		_MaxSpeed("_MaxSpeed", Float) = 1
		_ParticlesData("_ParticlesData", 2D) = "white" {}
	}
	SubShader
	{
		Tags
		{
			"RenderType" = "Opaque"
			"IgnoreProjector" = "True"
			"DisableBatching" = "True"
		}

		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			#include "UnityCG.cginc"
			#include "Common.cginc"

			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
			};

			struct v2f
			{
				float2 uv : TEXCOORD0;
				float4 vertex : SV_POSITION;
			};


			float _SimulationSpeed;
			float _AttractionSpeed;
			float _AttractionRadius;
			float _AttractorNoiseRadius;
			float _AttractorSphereRadius;
			float _IdleNoiseWeight;
			float _MaxForce;
			float _MaxSpeed;


			sampler2D _Attractor1Position;
			sampler2D _Attractor2Position;

			v2f vert(appdata v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.uv = v.uv;
				return o;
			}


			float4 frag(v2f i) : SV_Target
			{
				float4 data1, data2;
				DataLoad(data1, data2, i.uv);
				float3 position = data1.xyz;
				float3 speed = data2.xyz;

				float2 uv = i.uv;
				uv.x = fmod(uv.x, 0.5) * 2.0; // so both pos and vel data have same uv

				// update according to attractor position and settings
				float3 attractorPos = mul(unity_ObjectToWorld, float4(0,0,0,1)).xyz;
				float3 toAttVector = attractorPos - position;
				float distToAttr = length(toAttVector);

				if (distToAttr > 0.01)
				{
					float3 toAttDirection = toAttVector / distToAttr; // normalize
					if (_AttractionSpeed != 0)
					{
						float3 forceSum = 0;

						float distToSurface = distToAttr - _AttractorSphereRadius;
						float attraction = rcp(distToSurface * distToSurface * sign(distToSurface));
						forceSum += toAttDirection * attraction * _AttractionRadius * _AttractionSpeed;

						// prevent particles jitter on attractor sphere surface
						_MaxSpeed *= max(0.1, smoothstep(0, _AttractorSphereRadius / 10, abs(distToSurface)));

						// solar flare like pulses
						float solarFlares = 1 + sin(_Time.y * 0.1 + uv.x * 10) + sin(_Time.y * 0.1 + uv.y * 10);

						// noise movement the closer particle is to attractor
						float3 attNoise = float3(
							snoise(position / 5 + uv.xyy * 2 + sin(_Time.y / 10)),
							snoise(position / 5 + uv.xyx * 2 - cos(_Time.y / 10)),
							snoise(position / 5 + uv.yxx * 2 - sin(_Time.y / 10)));
						attNoise = attNoise * smoothstep(1, 0, abs(distToSurface)) * DELTA_TIME * solarFlares;
						_MaxSpeed += length(attNoise);
						speed += attNoise;

						// spiral like movement towards attractor
						float3 spiralNoise = float3(
							snoise(position + uv.xyy),
							snoise(position + uv.xyx),
							snoise(position + uv.yxx));
						spiralNoise = spiralNoise * smoothstep(10, 0, distToSurface);
						_MaxForce += length(spiralNoise);
						forceSum += spiralNoise;

						// clamp max force
						{
							float forceLen = length(forceSum);
							if (forceLen > _MaxForce) forceSum = forceSum / forceLen * _MaxForce;
						}

						speed += forceSum * DELTA_TIME;
					}
					else if (distToAttr < _AttractorSphereRadius)
					{
						// slightly bounce off attractors
						float3 normal = -toAttDirection;
						speed.xyz = reflect(speed, normal) * 0.5 + normal * 0.1;
						position = attractorPos + normal * _AttractorSphereRadius;
					}
				}

				// random movement and clustering if attractor is far
				float3 idleNoise = float3(
					snoise(position + sin(_Time.y / 100)),
					snoise(position + uv.xyx * 5 - cos(_Time.y / 100)) * 0.5,
					snoise(position + cos(_Time.y / 100))
				);
				speed += idleNoise * smoothstep(_AttractorSphereRadius * 2, 5, distToAttr) * _IdleNoiseWeight * DELTA_TIME;


				float2 parentUv = float2(data1.w, data2.w);


				// clamp max speed
				{
					float speedLen = length(speed);
					if (speedLen > _MaxSpeed) speed = speed / speedLen * _MaxSpeed;
				}

				// damping
				speed *= 1 - DELTA_TIME;
				//speed *= 0.99;

				// move by speed
				position += speed * DELTA_TIME * _SimulationSpeed;



				return DataSave(float4(position, parentUv.x), float4(speed, parentUv.y), i.uv);
			}
			ENDCG
		}
	}
		FallBack Off
}