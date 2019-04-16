// by Neitri, free of charge, free to redistribute
// downloaded from https://github.com/netri/Neitri-Unity-Shaders

Shader "Neitri/World Position"
{
	Properties
	{
	}
	SubShader
	{
		Tags 
		{
			"Queue" = "Transparent+1000"
			"RenderType" = "Transparent"
		}

		Cull Off

		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#include "UnityCG.cginc"

			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
			};

			struct v2f
			{
				float4 vertex : SV_POSITION;
				float4 screenPos : TEXCOORD1;
				float4 direction : TEXCOORD2;
			};

			UNITY_DECLARE_DEPTH_TEXTURE(_CameraDepthTexture);

			// Dj Lukis.LT's correction for oblique view frustrum (happens in VRChat mirrors)
			// https://github.com/lukis101/VRCUnityStuffs/blob/master/Shaders/DJL/Overlays/WorldPosOblique.shader
			#define UMP UNITY_MATRIX_P
			inline float4 CalculateFrustumCorrection()
			{
				float x1 = -UMP._31 / (UMP._11 * UMP._34);
				float x2 = -UMP._32 / (UMP._22 * UMP._34);
				return float4(x1, x2, 0, UMP._33 / UMP._34 + x1 * UMP._13 + x2 * UMP._23);
			}
			static float4 FrustumCorrection = CalculateFrustumCorrection();
			inline float CorrectedLinearEyeDepth(float z, float correctionFactor)
			{
				return 1.f / (z / UMP._34 + correctionFactor);
			}
			// Merlin's mirror detection
			inline bool IsInMirror()
			{
				return UMP._31 != 0.f || UMP._32 != 0.f;
			}
			#undef UMP

			v2f vert(appdata v)
			{
				float4 worldPosition = mul(UNITY_MATRIX_M, v.vertex);
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.screenPos = ComputeGrabScreenPos(o.vertex);
				o.direction.xyz = worldPosition.xyz - _WorldSpaceCameraPos.xyz;
				o.direction.w = dot(o.vertex, FrustumCorrection); // correction factor
				return o;
			}

			float4 frag(v2f i) : SV_Target
			{
				float perspectiveDivide = 1.f / i.vertex.w;
				float4 direction = i.direction * perspectiveDivide;
				float2 screenPos = i.screenPos.xy * perspectiveDivide;

				float z = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, screenPos);

				#if UNITY_REVERSED_Z
				if (z == 0.f) {
				#else
				if (z == 1.f) {
				#endif
					// this is skybox, depth texture has default value
					return float4(0.f, 0.f, 0.f, 1.f);
				}

				// linearize depth and use it to calculate background world position
				float depth = CorrectedLinearEyeDepth(z, direction.w);
				float3 worldPosition = direction.xyz * depth + _WorldSpaceCameraPos.xyz;

				// demonstrate on tartan pattern
				return float4(frac(worldPosition), 1.0f);
			}

			ENDCG
		}
	}
}