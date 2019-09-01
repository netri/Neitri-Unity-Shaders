Shader "Neitri/Graffiti Wall/Spray Particle Data"
{
	Properties
	{
		_DepthMask("_DepthMask", 2D) = "white" {}
	}
	SubShader
	{
		Tags {
			"Queue" = "Transparent+100"
			"RenderType" = "Transparent"
		}
		Blend One Zero
		ZWrite Off
		Cull Off

		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			#include "UnityCG.cginc"

			struct appdata
			{
				float3 vertex : POSITION;
				fixed4 color : COLOR;
				float4 uv : TEXCOORD0;
			};

			struct v2f
			{
				float4 vertex : SV_POSITION;
				fixed4 color : COLOR;
				float4 uv : TEXCOORD0;
			};

			sampler2D _DepthMask;

			v2f vert(appdata v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.color = v.color;
				o.uv = v.uv;
				return o;
			}

			fixed4 frag(v2f i) : SV_Target
			{
				// wall data camera has has near plane 0 and far plane 0.01
				// we want this shader to be visible only in wall data camera
				bool isWallCamera = (_ProjectionParams.z - _ProjectionParams.y) < 0.1;
				clip(isWallCamera - 0.5);

				float agePrecentage = i.uv.z;

				float depthMask = tex2Dlod(_DepthMask, float4(i.uv.x, i.uv.y, 0, 0)).r;
				if (depthMask > 0)
				{
					float zfar = 1;
					float znear = 0.1;
					depthMask = znear / (depthMask + znear);
					clip(depthMask - agePrecentage);
				}

				float progress = distance(i.uv, float2(0.5, 0.5));
				clip(0.5 - progress);
				float alpha = smoothstep(0.5, 0, progress - i.color.a / 5) * i.color.a;
				return fixed4(i.color.rgb, alpha);
			}
			ENDCG
		}
	}
	FallBack Off
}
