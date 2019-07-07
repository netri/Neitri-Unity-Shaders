Shader "Neitri/Graffiti Wall/Spray Particle Visual"
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
		Blend SrcAlpha OneMinusSrcAlpha
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
				float alpha = smoothstep(0.5, 0, progress);
				return fixed4(i.color.rgb, alpha * i.color.a);
			}
			ENDCG
		}
	}
		FallBack Off
}
