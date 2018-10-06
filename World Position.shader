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

		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#include "UnityCG.cginc"

			// based on https://gamedev.stackexchange.com/a/132845/41980
			// and Unity built in shader "Particle Add.shader" https://unity3d.com/get-unity/download/archive

			struct appdata
			{
				float4 vertex : POSITION;
			};
			struct v2f
			{
				float4 vertex : SV_POSITION;
				float4 projPos : TEXCOORD1;
				float3 ray : TEXCOORD2;
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
				float sceneZ = LinearEyeDepth (SAMPLE_DEPTH_TEXTURE_PROJ(_CameraDepthTexture, UNITY_PROJ_COORD(i.projPos)));
				float3 worldSpacePosition = sceneZ * i.ray / i.projPos.z + _WorldSpaceCameraPos;

				return float4(frac(worldSpacePosition), 1.0f);
			}

			ENDCG
		}
	}
}
