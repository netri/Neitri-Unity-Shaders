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
			};

			struct v2f
			{
				float4 vertex : SV_POSITION;
				float4 depthTextureGrabPos : TEXCOORD1;
				float4 rayFromCamera : TEXCOORD2;
			};

			UNITY_DECLARE_DEPTH_TEXTURE(_CameraDepthTexture);

			// Dj Lukis.LT's oblique view frustum correction (VRChat mirrors use such view frustum)
			// https://github.com/lukis101/VRCUnityStuffs/blob/master/Shaders/DJL/Overlays/WorldPosOblique.shader
			#define UMP UNITY_MATRIX_P
			inline float4 CalculateObliqueFrustumCorrection()
			{
				float x1 = -UMP._31 / (UMP._11 * UMP._34);
				float x2 = -UMP._32 / (UMP._22 * UMP._34);
				return float4(x1, x2, 0, UMP._33 / UMP._34 + x1 * UMP._13 + x2 * UMP._23);
			}
			static float4 ObliqueFrustumCorrection = CalculateObliqueFrustumCorrection();
			inline float CorrectedLinearEyeDepth(float z, float correctionFactor)
			{
				return 1.f / (z / UMP._34 + correctionFactor);
			}
			#undef UMP

			v2f vert(appdata v)
			{
				float4 worldPosition = mul(unity_ObjectToWorld, v.vertex);
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.depthTextureGrabPos = ComputeGrabScreenPos(o.vertex);
				o.rayFromCamera.xyz = worldPosition.xyz - _WorldSpaceCameraPos.xyz;
				o.rayFromCamera.w = dot(o.vertex, ObliqueFrustumCorrection); // oblique frustrum correction factor
				return o;
			}

			float4 frag(v2f i) : SV_Target
			{
				float perspectiveDivide = 1.f / i.vertex.w;
				float4 rayFromCamera = i.rayFromCamera * perspectiveDivide;
				float2 depthTextureGrabPos = i.depthTextureGrabPos.xy * perspectiveDivide;

				float z = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, depthTextureGrabPos);

				#if UNITY_REVERSED_Z
				if (z == 0.f) {
				#else
				if (z == 1.f) {
				#endif
					// this is skybox, depth texture has default value
					return float4(0.f, 0.f, 0.f, 1.f);
				}

				// linearize depth and use it to calculate background world position
				float depth = CorrectedLinearEyeDepth(z, rayFromCamera.w);

				float3 worldPosition = rayFromCamera.xyz * depth + _WorldSpaceCameraPos.xyz;

				// demonstrate on tartan pattern
				return float4(frac(worldPosition), 1.0f);
			}

			ENDCG
		}
	}
}