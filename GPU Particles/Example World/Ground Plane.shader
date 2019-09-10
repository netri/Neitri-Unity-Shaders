// created by Neitri, free of charge, free to redistribute
// downloaded from https://github.com/netri/Neitri-Unity-Shaders

Shader "Neitri/GPU Particles/Example World/Ground Plane"
{
	Properties
	{
		_Color("Color", Color) = (1,1,1,1)
	}
	SubShader
	{
		Tags { "RenderType" = "Geometry" }
		LOD 100

		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			#include "UnityCG.cginc"

			fixed4 _Color;

			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
			};

			struct v2f
			{
				float4 vertex : SV_POSITION;
				float4 worldPos : TEXCOORD0;
			};

			v2f vert(appdata v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.worldPos = mul(unity_ObjectToWorld, v.vertex);
				return o;
			}

			float3 GetCameraWorldPos()
			{
				#ifdef USING_STEREO_MATRICES
					return lerp(unity_StereoWorldSpaceCameraPos[0], unity_StereoWorldSpaceCameraPos[1], 0.5);
				#else
					return _WorldSpaceCameraPos;
				#endif
			}

			fixed4 frag(v2f i) : SV_Target
			{
				float screen = sqrt(_ScreenParams.x * _ScreenParams.y) * 0.001;

				float3 cam = GetCameraWorldPos();
				float distanceToCam = distance(cam, i.worldPos);
				clip(10 * screen - distanceToCam);

				float3 pos = frac(abs(i.worldPos));
				float weight = 1 - length(pos.xz * 2 - 1);
				clip(weight - 0.96);

				if (distanceToCam < 3 * screen)
				{
					pos = frac(abs(i.worldPos * 300));
					weight = length(pos.xz * 2 - 1);
					clip(weight - 0.95);
				}

				if (distanceToCam < 6 * screen)
				{
					pos = frac(abs(i.worldPos * 30));
					weight = length(pos.xz * 2 - 1);
					clip(weight - 0.95);
				}

				return _Color * smoothstep(10 * screen, 0, distanceToCam);
			}
			ENDCG
		}
	}
}