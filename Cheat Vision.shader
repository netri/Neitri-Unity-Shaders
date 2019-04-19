// by Neitri, free of charge, free to redistribute
// downloaded from https://github.com/netri/Neitri-Unity-Shaders

Shader "Neitri/Cheat Vision"
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
			
			float3 hsvToRgb(float3 c)
			{
				float4 K = float4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
				float3 p = abs(frac(c.xxx + K.xyz) * 6.0 - K.www);
				return c.z * lerp(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
			}

			float4 frag (v2f i) : SV_Target
			{
				float depthSample = SAMPLE_DEPTH_TEXTURE_PROJ(_CameraDepthTexture, UNITY_PROJ_COORD(i.projPos));
				
				bool isSkyBox = depthSample == 0;
			
				fixed4 color = tex2Dproj(_ScreenTex, i.grabPos);

				if (!isSkyBox)
				{
					fixed g = grayness(color.rgb);
					color.rgb /= g + 0.02;

					bool depthDisabled = depthSample > 0.215 && depthSample < 0.216;
		
					if (!depthDisabled)
					{
						// only if we can read depth texture
						float sceneZ = LinearEyeDepth (depthSample);
			
						float3 depthBasedColor = hsvToRgb(float3(sceneZ/10,1,1));
						color.rgb = lerp(color.rgb, depthBasedColor, 0.5);

						float3 worldPosition = sceneZ * i.ray / i.projPos.z + _WorldSpaceCameraPos;
						fixed3 worldNormal = normalize(cross(-ddx(worldPosition), ddy(worldPosition)));
						float3 fakeLightDirection = normalize(float3(1,1,1));

						float3 shading = lerp(0, 1, saturate(dot(worldNormal, fakeLightDirection)));
						color.rgb *= shading;
					}
				}

				return color;
			}

			ENDCG
		}
	}
}