// created by Neitri, free of charge, free to redistribute

Shader "Neitri/GPU Particles/Attractor"
{
	Properties
	{		
		_SimulationSpeed ("_SimulationSpeed", Float) = 1
		_AttractionSpeed ("_AttractionSpeed", Float) = 1
		_AttractionRadius ("_AttractionRadius", Float) = 10
		_AttractorNoiseRadius ("_AttractorNoiseRadius", Float) = 0.01
		_AttractorSphereRadius("_AttractorSphereRadius", Float) = 0.1
		_IdleNoiseWeight ("_IdleNoiseWeight", Float) = 0.3
		_MaxForce ("_MaxForce", Float) = 1
		_MaxSpeed ("_MaxSpeed", Float) = 0.3
		_ParticlesData ("_ParticlesData", 2D) = "white" {}
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
						
			#include "SimplexNoise2D.cginc"
			#include "SimplexNoise3D.cginc"

			#include "Common.cginc"
			#include "DataLoadSave.cginc"

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
			
			v2f vert (appdata v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.uv = v.uv;
				return o;
			}


			FRAG_RETURN frag (v2f i) : SV_Target
			{			
				float4 data1, data2;
				DataLoad(data1, data2, i.uv);
				float3 position = data1.xyz;
				float3 speed = data2.xyz;

				float2 uv = i.uv;
				uv.x = fmod(uv.x, 0.5) * 2.0;

				// update according to attractor position and settings
				float3 attractorPos = mul(unity_ObjectToWorld, float4(0,0,0,1)).xyz;
				float3 toAttVector = attractorPos - position;
				float distToAttr = length(toAttVector);
				float3 toAttDirection = toAttVector / distToAttr;
				if (_AttractionSpeed != 0)
				{
					float3 forceSum = 0;

					float ddd = distToAttr - _AttractorSphereRadius;
					ddd = ddd * ddd * sign(ddd);
					float attraction = _AttractionRadius / ddd * _AttractionSpeed;
					forceSum += toAttDirection * attraction;
					_MaxSpeed *= smoothstep(0, _AttractorSphereRadius/10, abs(ddd)); // prvent particles jitter on attractor sphere surface

					float3 attNoise = float3(
						snoise(position/5 + uv.xyy*2 + sin(_Time.y/10)),
						snoise(position/5 + uv.xyx*2 - cos(_Time.y/10)),
						snoise(position/5 + uv.yxx*2 - sin(_Time.y/10)));
					attNoise = attNoise * _AttractorNoiseRadius * DELTA_TIME / max(0.0001, abs(ddd)) * sign(ddd);
					_MaxSpeed += length(attNoise);
					speed += attNoise;


					float accelerateOnlyTowardsAttrWeight = smoothstep(8, 5, distToAttr) - smoothstep(1, 0.5, distToAttr);
					forceSum = lerp(forceSum, abs(forceSum) * sign(toAttDirection), saturate(accelerateOnlyTowardsAttrWeight));


					float3 spiralNoise = float3(
						snoise(position + uv.xyy + sin(_Time.y)),
						snoise(position + uv.xyx - cos(_Time.y)),
						snoise(position + uv.yxx - sin(_Time.y)));
					float showSpiralsWeight = smoothstep(5, 3, distToAttr) - smoothstep(3, 2, distToAttr);
					//forceSum += spiralNoise * saturate(showSpiralsWeight);
					//forceSum = spiralNoise;
					//forceSum += toAttDirection * movementWeight * _AttractionSpeed;


					float forceLen = length(forceSum);
					if (forceLen > _MaxForce) forceSum = forceSum / forceLen * _MaxForce;

					speed += forceSum * DELTA_TIME;
				}
				else if (distToAttr < _AttractorSphereRadius)
				{
					// bounce of attractors
					float3 normal = -toAttDirection;
					speed.xyz = reflect(speed, normal) * 0.5 + normal * 0.1;
					position = attractorPos + normal * _AttractorSphereRadius;
				}
				
				// random movement and clustering if attractor is far
				float3 idleNoise = float3(
					snoise(position + sin(_Time.y/100)),
					snoise(position + uv.xyx*5 - cos(_Time.y/100)) * 0.5,
					snoise(position + cos(_Time.y/100))
				);
				//float idleNoisel = length(idleNoise);
				//idleNoise = idleNoise / idleNoisel * sin(idleNoisel);
				speed += idleNoise * DELTA_TIME * smoothstep(_AttractorSphereRadius * 2, 5, distToAttr) * _IdleNoiseWeight;
				//speed += idleNoise * DELTA_TIME * _IdleNoiseWeight;
				
				
				float2 parentUv = float2(data1.w, data2.w);
				/*
				if (parentUv.x > 0)
				{	
					float4 parentPosition, parentSpeed;
					DataLoad(parentPosition, parentSpeed, parentUv);
					
					float3 d = parentPosition.xyz - position;
					speed += d * DELTA_TIME;
				}
				*/


				float speedLen = length(speed);
		
				if (speedLen > _MaxSpeed) speed = speed / speedLen * _MaxSpeed; 

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
