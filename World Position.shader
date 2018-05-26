// by Neitri, free of charge, free to redistribute

Shader "Neitri/World Position"
{
	Properties
	{
	}
	SubShader
	{
		Tags {
	        "Queue"="Transparent+10"
            "RenderType"="Transparent"
		}
		LOD 100

		Pass
		{
			Blend One Zero
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag			
			#include "UnityCG.cginc"

			// based on https://gamedev.stackexchange.com/a/132845/41980

			struct appdata
			{
				float4 vertex : POSITION;
			};
			struct v2f
			{
				float4 vertex : SV_POSITION;
				float3 worldDirection : TEXCOORD0;
				float4 screenPosition : TEXCOORD1;
			};

			sampler2D _CameraDepthTexture;

			v2f vert (appdata v)
			{
				v2f o;
				// Subtract camera position from vertex position in world
				// to get a ray pointing from the camera to this vertex.
				o.worldDirection = mul(unity_ObjectToWorld, v.vertex).xyz - _WorldSpaceCameraPos;
				o.vertex = UnityObjectToClipPos(v.vertex);
				// Save the clip space position so we can use it later.
				// but here I'm aiming for the simplest version I can.
				// Optimized versions welcome in additional answers!)
				o.screenPosition = o.vertex;
				return o;
			}

			float4 frag (v2f i) : SV_Target
			{
				// Compute projective scaling factor...
				float perspectiveDivide = 1.0f / i.screenPosition.w;
				// Scale our view ray to unit depth.
				float3 direction = i.worldDirection * perspectiveDivide;
				// Calculate our UV within the screen (for reading depth buffer)
				float2 screenUV = (i.screenPosition.xy * perspectiveDivide) * 0.5f + 0.5f;
				#ifdef UNITY_UV_STARTS_AT_TOP
					screenUV.y = 1 - screenUV.y; 
				#endif
				// VR stereo support
				screenUV = UnityStereoTransformScreenSpaceTex(screenUV);
				// Read depth, linearizing into worldspace units.    
				float depth = LinearEyeDepth(UNITY_SAMPLE_DEPTH(tex2D(_CameraDepthTexture, screenUV)));
				// Advance by depth along our view ray from the camera position.
				// This is the worldspace coordinate of the corresponding fragment
				// we retrieved from the depth buffer.
				float3 worldSpacePosition = direction * depth + _WorldSpaceCameraPos;
				// Draw a worldspace tartan pattern over the scene to demonstrate.
				return float4(frac(worldSpacePosition), 1.0f);
			}

			ENDCG
		}
	}
}
