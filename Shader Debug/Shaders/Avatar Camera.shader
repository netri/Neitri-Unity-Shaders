Shader "Neitri/Debug/Avatar Camera"
{
	Properties
	{
		_MainTex ("Texture", 2D) = "white" {}
	}
	SubShader
	{
		Tags { "RenderType"="Opaque" }
		LOD 100
		Cull Off

		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			#include "UnityCG.cginc"

			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
			};

			struct v2f
			{
				float2 uv : TEXCOORD0;
				float4 vertex : SV_POSITION;
			};

			sampler2D _MainTex;


			v2f vert (appdata v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.uv = v.uv;
				return o;
			}
			
			fixed4 frag (v2f i) : SV_Target
			{
				const int off = 20;
				const int off2 = off * 0.3f;
				const float d = 4/1024.0;
				const float d2 = 1/1024.0;
				fixed v = 0;
				for (int x = -off; x < off; x++)
				{
					float2 uv = i.uv.xy + float2(x * d, 0);
					v = max(v, length(tex2D(_MainTex, uv)));
				}
				for (int y = -off; y < off; y++)
				{
					float2 uv = i.uv.xy + float2(0, y * d);
					v = max(v, length(tex2D(_MainTex, uv)));
				}

				for (int x = -off2; x < off2; x++)
				{
					for (int y = -off2; y < off2; y++)
					{
						float2 uv = i.uv.xy + float2(x, y) * d2;
						v = max(v, length(tex2D(_MainTex, uv)));
					}
				}

				return fixed4(v, 0, 0 ,1);
			}
			ENDCG
		}
	}

}
