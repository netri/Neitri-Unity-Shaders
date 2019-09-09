// by Neitri, free of charge, free to redistribute
// downloaded from https://github.com/netri/Neitri-Unity-Shaders

Shader "Neitri/Procedural Space Skybox"  
{
	Properties 
	{
		_SunSize ("_SunSize", Range(0,1)) = 0.04
		_PlanetSize("_PlanetSize", Range(0,1)) = 0.5
	}

	SubShader 
	{
		Tags 
		{
			"Queue"="Background"
			"RenderType"="Background"
			"PreviewType"="Skybox"
		}
		Cull Off
		ZWrite Off

		Pass
		{

			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			#include "UnityCG.cginc"
			#include "Lighting.cginc"

			float _SunSize;
			float _PlanetSize;

			struct appdata_t
			{
				float4 vertex : POSITION;
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};

			struct v2f
			{
				float4 pos : SV_POSITION;
				float3 vertex : TEXCOORD0;
				UNITY_VERTEX_OUTPUT_STEREO
			};

			v2f vert (appdata_t v)
			{
				v2f o;
				UNITY_SETUP_INSTANCE_ID(v);
				UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
				o.pos = UnityObjectToClipPos(v.vertex);
				o.vertex = v.vertex;
				return o;
			}

			// taken from https://www.shadertoy.com/view/4sBXzG
			float hash(float n) { return frac(sin(n) * 1e4); }
			float hash(float2 p) { return frac(1e4 * sin(17.0 * p.x + p.y * 0.1) * (0.1 + abs(sin(p.y * 13.0 + p.x)))); }
			// 1 octave value noise
			float noise(float x) { float i = floor(x); float f = frac(x); float u = f * f * (3.0 - 2.0 * f); return lerp(hash(i), hash(i + 1.0), u); }
			float noise(float2 x) { float2 i = floor(x); float2 f = frac(x);	float a = hash(i); float b = hash(i + float2(1.0, 0.0)); float c = hash(i + float2(0.0, 1.0)); float d = hash(i + float2(1.0, 1.0)); float2 u = f * f * (3.0 - 2.0 * f); return lerp(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y; }
			float noise(float3 x) { const float3 step = float3(110, 241, 171); float3 i = floor(x); float3 f = frac(x); float n = dot(i, step); float3 u = f * f * (3.0 - 2.0 * f); return lerp(lerp(lerp(hash(n + dot(step, float3(0, 0, 0))), hash(n + dot(step, float3(1, 0, 0))), u.x), lerp(hash(n + dot(step, float3(0, 1, 0))), hash(n + dot(step, float3(1, 1, 0))), u.x), u.y), lerp(lerp(hash(n + dot(step, float3(0, 0, 1))), hash(n + dot(step, float3(1, 0, 1))), u.x), lerp(hash(n + dot(step, float3(0, 1, 1))), hash(n + dot(step, float3(1, 1, 1))), u.x), u.y), u.z); }


			// digged out of "Unity 2017.4.15f1 builtin shaders/DefaultResourcesExtra/Skybox-Procedural.shader"
			half calcSunAttenuation(half3 lightPos, half3 ray)
			{
				half _SunSizeConvergence = 10;
				half eyeCos = -pow(saturate(dot(lightPos, ray)), _SunSizeConvergence);
				#define MIE_G (-0.990)
				#define MIE_G2 0.9801
				half temp = 1.0 + MIE_G2 - 2.0 * MIE_G * eyeCos;
				temp = pow(temp, pow(_SunSize, 0.65) * 10);
				temp = max(temp, 1.0e-4);
				temp = 1.5 * ((1.0 - MIE_G2) / (2.0 + MIE_G2)) * (1.0 + eyeCos * eyeCos) / temp;
				#if defined(UNITY_COLORSPACE_GAMMA)
				temp = pow(temp, .454545);
				#endif
				return temp;
			}


			float4 frag (v2f i) : SV_Target
			{
				float3 ray = normalize(mul((float3x3)unity_ObjectToWorld, i.vertex));

				// sun
				float3 sunDir = _WorldSpaceLightPos0.xyz;
				//float sunWeight = pow((1 - smoothstep(0, _SunSize, length(sunDir - ray))), 1);
				//float sunBloomWeight = 0.02 * (1 - length(sunDir - ray));
				float sunWeight = calcSunAttenuation(sunDir, ray);

				// planet
				float3 planetDir = normalize(sunDir + float3(0.5, 0.5, 0.5));
				float3 coronaDir = normalize(planetDir + sunDir * _PlanetSize * 0.03);
				float planetWeight = smoothstep(0, 0.001, 1 - smoothstep(0, _PlanetSize, length(planetDir - ray)));
				float planetCoronaWeight = saturate(2 * smoothstep(0, 0.015, 1 - smoothstep(0, _PlanetSize, length(coronaDir - ray))));
				planetCoronaWeight = saturate(planetCoronaWeight - planetWeight);

				// stars
				float starsWeight = smoothstep(0.96, 1, noise(ray * 100));

				// combinations
				sunWeight = saturate(sunWeight - planetWeight);
				starsWeight = saturate(starsWeight - planetWeight);

				float3 color =
					sunWeight * _LightColor0 +
					planetCoronaWeight * _LightColor0 +
					starsWeight;

				return float4(color, 1.0);

			}
			ENDCG
		}
	}

	Fallback Off
}
