// by Neitri, free of charge, free to redistribute
// downloaded from https://github.com/netri/Neitri-Unity-Shaders

Shader "Neitri/Normalized Color"
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

		GrabPass 
		{ 
			"_ScreenTex"
		}
		
		Pass
		{
			// based on "Neitri/World Normal Nice Slow"

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
				float4 projPos : TEXCOORD1;
				float3 ray : TEXCOORD2;
				float4 grabPos : TEXCOORD3;
			};

			UNITY_DECLARE_DEPTH_TEXTURE(_CameraDepthTexture);

			v2f vert (appdata v)
			{
				v2f o;
				o.ray = mul(unity_ObjectToWorld, v.vertex).xyz - _WorldSpaceCameraPos;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.grabPos = ComputeGrabScreenPos(o.vertex);
				o.projPos = ComputeScreenPos (o.vertex);
				COMPUTE_EYEDEPTH(o.projPos.z);
				return o;
			}
				
			sampler2D _ScreenTex;

			float grayness(float3 color)
			{
				const float3 greyScale = float3(0.3, 0.59, 0.11);
				return dot(color, greyScale);
			}

			float4 frag (v2f i) : SV_Target
			{
				float sceneZ = LinearEyeDepth (SAMPLE_DEPTH_TEXTURE_PROJ(_CameraDepthTexture, UNITY_PROJ_COORD(i.projPos)));
				float3 worldPosition = sceneZ * i.ray / i.projPos.z + _WorldSpaceCameraPos;
				fixed3 worldNormal = normalize(cross(-ddx(worldPosition), ddy(worldPosition)));

				float3 fakeLightDirection = normalize(float3(1,1,1));

				fixed4 color = tex2Dproj(_ScreenTex, i.grabPos);
				fixed g = grayness(color.rgb);
				color.rgb /= g + 0.02;

				float3 lighting = lerp(0.4, 1, saturate(dot(worldNormal, fakeLightDirection))) + ShadeSH9(half4(worldNormal, 1));
				color.rgb *= lighting;

				return color;
			}

			ENDCG
		}
	}
}