// by Neitri, free of charge, free to redistribute
// downloaded from https://github.com/netri/Neitri-Unity-Shaders

Shader "Neitri/Distance Fade Cube Volume"
{
	Properties
	{
		[HDR] _Color("Color", Color) = (0,0,0,1)
		[Enum(Alpha Blended,0,Dithered,1)] _FadeType("Fade type", Range(0, 1)) = 0
	}
		SubShader
	{
		Tags
		{
			"Queue" = "Transparent+1000"
			"RenderType" = "Transparent"
		}

		Blend SrcAlpha OneMinusSrcAlpha
		Cull Back
		ZWrite Off

		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#include "UnityCG.cginc"

			float4 _Color;
			int _FadeType;

			struct appdata
			{
				float4 vertex : POSITION;
			};

			struct v2f
			{
				float4 vertex : SV_POSITION;
				float4 depthTextureUv : TEXCOORD1;
				float4 rayFromCamera : TEXCOORD2;
			};

			UNITY_DECLARE_DEPTH_TEXTURE(_CameraDepthTexture);

			// Dj Lukis.LT's oblique view frustum correction (VRChat mirrors use such view frustum)
			// https://github.com/lukis101/VRCUnityStuffs/blob/master/Shaders/DJL/Overlays/WorldPosOblique.shader
			inline float4 CalculateObliqueFrustumCorrection()
			{
				float x1 = -UNITY_MATRIX_P._31 / (UNITY_MATRIX_P._11 * UNITY_MATRIX_P._34);
				float x2 = -UNITY_MATRIX_P._32 / (UNITY_MATRIX_P._22 * UNITY_MATRIX_P._34);
				return float4(x1, x2, 0, UNITY_MATRIX_P._33 / UNITY_MATRIX_P._34 + x1 * UNITY_MATRIX_P._13 + x2 * UNITY_MATRIX_P._23);
			}
			inline float CorrectedLinearEyeDepth(float z, float correctionFactor)
			{
				return 1.f / (z / UNITY_MATRIX_P._34 + correctionFactor);
			}

			bool SceneZDefaultValue()
			{
				#if UNITY_REVERSED_Z
					return 0.f;
				#else
					return 1.f;
				#endif
			}

			// from https://www.shadertoy.com/view/Mllczf
			float GetTriangularPDFNoiseDithering(float3 pos)
			{
				float3 p3 = frac(pos * float3(.1031, .1030, .0973));
				p3 += dot(p3, p3.yzx + 19.19);
				float2 rand = frac((p3.xx + p3.yz) * p3.zy);
				return (rand.x + rand.y) * 0.5;
			}

			v2f vert(appdata v)
			{
				float4 worldPosition = mul(unity_ObjectToWorld, v.vertex);
				v2f o;
				o.vertex = mul(UNITY_MATRIX_VP, worldPosition);
				o.depthTextureUv = ComputeGrabScreenPos(o.vertex);
				o.rayFromCamera.xyz = worldPosition.xyz - _WorldSpaceCameraPos.xyz;
				o.rayFromCamera.w = dot(o.vertex, CalculateObliqueFrustumCorrection()); // oblique frustrum correction factor
				return o;
			}

			float4 frag(v2f i) : SV_Target
			{
				float perspectiveDivide = 1.f / i.vertex.w;
				float4 rayFromCamera = i.rayFromCamera * perspectiveDivide;
				float2 depthTextureUv = i.depthTextureUv.xy * perspectiveDivide;

				float sceneZ = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, depthTextureUv);
				if (sceneZ == SceneZDefaultValue()) 
				{
					// this is skybox, depth texture has default value
					clip(-1);
				}

				// linearize depth and use it to calculate background world position
				float sceneDepth = CorrectedLinearEyeDepth(sceneZ, rayFromCamera.w);
				float3 worldPosition = rayFromCamera.xyz * sceneDepth + _WorldSpaceCameraPos.xyz;
				float4 localPosition = mul(unity_WorldToObject, float4(worldPosition, 1));
				localPosition.xyz /= localPosition.w;


				float fade = max(0, 0.5 - localPosition.z);
				float4 color = _Color;

				UNITY_BRANCH
				if (_FadeType == 0)
				{
					color *= fade;
				}
				else
				{
					clip(fade - GetTriangularPDFNoiseDithering(worldPosition * 100));
				}

				return color;
			}

			ENDCG
		}
	}
	}