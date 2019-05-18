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
		Blend One OneMinusSrcAlpha
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
				float2 uv : TEXCOORD0;
			};

			struct v2f
			{
				float2 uv : TEXCOORD0;
				float4 vertex : SV_POSITION;
			};


			fixed4 _Color;
			
			v2f vert (appdata v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.uv = v.uv;
				return o;
			}
			
			fixed4 frag(v2f i) : SV_Target
			{
				float progress = smoothstep(0.5, 0, distance(i.uv, float2(0.5, 0.50)));
				//fixed3 col = lerp(fixed3(1,1,1), _Color.rgb, progress);
				//clip(progress - 0.01);
				//return fixed4(col, 1);
				return fixed4(_Color.rgb, progress);
			}
			ENDCG
		}
	}
	FallBack Off
}
