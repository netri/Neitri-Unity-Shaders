// by Neitri, free of charge, free to redistribute
// downloaded from https://github.com/netri/Neitri-Unity-Shaders

Shader "Neitri/Contact Deformation"
{
	Properties
	{
		_MainTex ("Texture", 2D) = "white" {}
		_Color("Color", Color) = (1,1,1,0.5)
	}
	SubShader
	{
		Tags 
		{
			"Queue" = "Transparent"
			"RenderType" = "Transparent" 
		}

		Blend SrcAlpha OneMinusSrcAlpha

		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			
			#include "UnityCG.cginc"

			struct appdata
			{
				float4 vertex : POSITION;
				float3 normal : NORMAL;
				float2 uv : TEXCOORD0;
			};

			struct v2f
			{
				float4 vertex : SV_POSITION;
				float2 uv : TEXCOORD0;
				float3 normal : TEXCOORD1;
			};

			sampler2D _MainTex;
			float4 _MainTex_ST;
			float4 _Color;

			UNITY_DECLARE_DEPTH_TEXTURE(_CameraDepthTexture);

			v2f vert (appdata v)
			{
				v2f o;
				o.normal = UnityObjectToWorldNormal(v.normal);
				o.uv = TRANSFORM_TEX(v.uv, _MainTex);

				// contact deformation
				{
					float4 worldPos = mul(unity_ObjectToWorld, float4(v.vertex.xyz, 1.0));
					float value;

					#if defined(UNITY_SINGLE_PASS_STEREO)
					// special case for single pass VR rendering, we want "value" to be the same in both eyes
					// se we calculate it for both eyes and take average
					// could take only left eye "value" for both eyes if you want to squeeze out extra performance
					{
						float4 vertex0 = mul(unity_StereoMatrixVP[0], worldPos);
						float4 vertex1 = mul(unity_StereoMatrixVP[1], worldPos);

						// ComputeScreenPos
						float4 screenPos0 = ComputeNonStereoScreenPos(vertex0);
						float4 screenPos1 = ComputeNonStereoScreenPos(vertex1);
						float4 scaleOffset0 = unity_StereoScaleOffset[0];
						float4 scaleOffset1 = unity_StereoScaleOffset[1];
						screenPos0.xy = screenPos0.xy * scaleOffset0.xy + scaleOffset0.zw * screenPos0.w;
						screenPos1.xy = screenPos1.xy * scaleOffset1.xy + scaleOffset1.zw * screenPos1.w;

						float sceneDepth0 = LinearEyeDepth(tex2Dlod(_CameraDepthTexture, float4(screenPos0.xy / vertex0.w, 0, 0)));
						float sceneDepth1 = LinearEyeDepth(tex2Dlod(_CameraDepthTexture, float4(screenPos1.xy / vertex1.w, 0, 0)));
						float vertexDepth0 = -mul(unity_StereoMatrixV[0], worldPos).z;
						float vertexDepth1 = -mul(unity_StereoMatrixV[1], worldPos).z;

						value = ((vertexDepth0 - sceneDepth0) + (vertexDepth1 - sceneDepth1)) * 0.5;
					}
					#else
					{
						float4 vertex = mul(unity_MatrixVP, worldPos);
						float4 screenPos = ComputeScreenPos(vertex);
						float sceneDepth = LinearEyeDepth(tex2Dlod(_CameraDepthTexture, float4(screenPos.xy / vertex.w, 0, 0)));
						float vertexDepth = -mul(unity_MatrixV, worldPos).z;
						value = vertexDepth - sceneDepth;
					}
					#endif

					if (value > -0.1 && value < 0.1)
					{
						worldPos.xyz += o.normal * value * 0.5;
					}
					
					o.vertex = mul(UNITY_MATRIX_VP, worldPos);
				}

				return o;
			}
			
			fixed4 frag (v2f i) : SV_Target
			{
				fixed4 col = tex2D(_MainTex, i.uv) * _Color;
				return col;
			}
			ENDCG
		}
	}
}
