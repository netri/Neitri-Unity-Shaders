// by Neitri, free of charge, free to redistribute
// downloaded from https://github.com/netri/Neitri-Unity-Shaders

Shader "Neitri/World Normal Ugly Fast"
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
				float4 vertex : POSITION;
			};
			struct v2f
			{
				float4 vertex : SV_POSITION;
				float4 projPos : TEXCOORD0;
				float3 ray : TEXCOORD1;
			};

			UNITY_DECLARE_DEPTH_TEXTURE(_CameraDepthTexture);

			v2f vert (appdata v)
			{
				v2f o;
				o.ray = mul(unity_ObjectToWorld, v.vertex).xyz - _WorldSpaceCameraPos;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.projPos = ComputeScreenPos (o.vertex);
				COMPUTE_EYEDEPTH(o.projPos.z);
				return o;
			}

			float4 frag (v2f i) : SV_Target
			{
				float sceneDepth = LinearEyeDepth (SAMPLE_DEPTH_TEXTURE_PROJ(_CameraDepthTexture, UNITY_PROJ_COORD(i.projPos)));
				float3 worldPosition = sceneDepth * i.ray / i.projPos.z + _WorldSpaceCameraPos;
				fixed3 worldNormal = normalize(cross(-ddx(worldPosition), ddy(worldPosition)));
				return float4(worldNormal, 1.0f);
			}

			ENDCG
		}
	}
}