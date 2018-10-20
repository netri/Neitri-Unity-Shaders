// by Neitri, free of charge, free to redistribute
// downloaded from https://github.com/netri/Neitri-Unity-Shaders

Shader "Neitri/World Normal Nice Slow"
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
			// based on "Neitri/World Position"

			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			
			#include "UnityCG.cginc"

			struct appdata
			{
				float4 vertex :POSITION;
			};
			struct v2f
			{
				float4 clipPos : SV_POSITION;
				float4 modelPos : TEXCOORD0;
			};

			sampler2D _CameraDepthTexture;


			v2f vert (appdata v)
			{
				v2f o;
				o.clipPos = UnityObjectToClipPos(v.vertex);
				o.modelPos = v.vertex;
				return o;
			}

			// from http://answers.unity.com/answers/641391/view.html
			// creates inverse matrix of input
			float4x4 inverse(float4x4 input)
			{
				#define minor(a,b,c) determinant(float3x3(input.a, input.b, input.c))
				float4x4 cofactors = float4x4(
					minor(_22_23_24, _32_33_34, _42_43_44), 
					-minor(_21_23_24, _31_33_34, _41_43_44),
					minor(_21_22_24, _31_32_34, _41_42_44),
					-minor(_21_22_23, _31_32_33, _41_42_43),

					-minor(_12_13_14, _32_33_34, _42_43_44),
					minor(_11_13_14, _31_33_34, _41_43_44),
					-minor(_11_12_14, _31_32_34, _41_42_44),
					minor(_11_12_13, _31_32_33, _41_42_43),

					minor(_12_13_14, _22_23_24, _42_43_44),
					-minor(_11_13_14, _21_23_24, _41_43_44),
					minor(_11_12_14, _21_22_24, _41_42_44),
					-minor(_11_12_13, _21_22_23, _41_42_43),

					-minor(_12_13_14, _22_23_24, _32_33_34),
					minor(_11_13_14, _21_23_24, _31_33_34),
					-minor(_11_12_14, _21_22_24, _31_32_34),
					minor(_11_12_13, _21_22_23, _31_32_33)
				);
				#undef minor
				return transpose(cofactors) / determinant(input);
			}

			float4x4 INVERSE_UNITY_MATRIX_VP;
			float3 calculateWorldSpace(float4 screenPos)
			{	
				// Transform from adjusted screen pos back to world pos
				float4 worldPos = mul(INVERSE_UNITY_MATRIX_VP, screenPos);
				// Subtract camera position from vertex position in world
				// to get a ray pointing from the camera to this vertex.
				float3 worldDir = worldPos.xyz / worldPos.w - _WorldSpaceCameraPos;
				// Calculate screen UV
				float2 screenUV = screenPos.xy / screenPos.w;
				screenUV.y *= _ProjectionParams.x;
				screenUV = screenUV * 0.5f + 0.5f;
				// Adjust screen UV for VR single pass stereo support
				screenUV = UnityStereoTransformScreenSpaceTex(screenUV);
				// Read depth, linearizing into worldspace units.    
				float depth = LinearEyeDepth(UNITY_SAMPLE_DEPTH(tex2D(_CameraDepthTexture, screenUV))) / screenPos.w;
				// Advance by depth along our view ray from the camera position.
				// This is the worldspace coordinate of the corresponding fragment
				// we retrieved from the depth buffer.
				return worldDir * depth;
			}

			fixed4 frag (v2f i) : SV_Target
			{
				INVERSE_UNITY_MATRIX_VP = inverse(UNITY_MATRIX_VP);
				float4 screenPos = UnityObjectToClipPos(i.modelPos); 
				// Should be 1.0 pixel, but some artefacts appear if we use perfect value
				float2 offset = 1.2 / _ScreenParams.xy * screenPos.w; 
				float3 worldPos1 = calculateWorldSpace(screenPos);
				float3 worldPos2 = calculateWorldSpace(screenPos + float4(0, offset.y, 0, 0));
				float3 worldPos3 = calculateWorldSpace(screenPos + float4(-offset.x, 0, 0, 0));
				float3 worldNormal = normalize(cross(worldPos2 - worldPos1, worldPos3 - worldPos1));
				return float4(worldNormal, 1.0f);

				// Looks nicer if demonstrated on phong shading
				//fixed phong = (dot(worldNormal, float3(1,0,0)) + 1) * 0.5;
				//return fixed4(phong, phong, phong, 1);
			}

			ENDCG
		}
	}
}
