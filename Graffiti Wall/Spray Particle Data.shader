Shader "Neitri/Graffiti Wall/Spray Particle Data"
{
	Properties
	{
		_Color("Color", Color) = (1,1,1,1)
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
				float4 vertex : POSITION;
				fixed4 color : COLOR;
				float2 uv : TEXCOORD0;
			};

			struct v2f
			{
				float4 vertex : SV_POSITION;
				fixed4 color : COLOR;
				float2 uv : TEXCOORD0;
			};


			fixed4 _Color;
			
			v2f vert (appdata v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.color = v.color;
				o.uv = v.uv;
				return o;
			}
			
			fixed4 frag(v2f i) : SV_Target
			{
				float progress = distance(i.uv, float2(0.5, 0.5));
				clip(0.5 - progress);
				float alpha = smoothstep(0.5, 0, progress);
				return fixed4(_Color.rgb * i.color.rgb, alpha * i.color.a * _Color.a);
			}
			ENDCG
		}
	}
	FallBack Off
}
