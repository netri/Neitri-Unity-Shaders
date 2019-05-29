Shader "Neitri/Graffiti Wall/Combine"
{
	Properties
	{
		_ColorToAdd ("_ColorToAdd", 2D) = "white" {}
		_PreviousAccomulatedColor("_PreviousAccomulatedColor", 2D) = "white" {}
	}
	SubShader
	{
		Tags { 
			"Queue" = "Transparent+100"
			"RenderType"="Transparent" 
		}
		Blend One Zero
		ZWrite Off
		LOD 100

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
			sampler2D _ColorToAdd;
			sampler2D _PreviousAccomulatedColor;

			v2f vert (appdata v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.uv = v.uv;
				return o;
			}
			
			fixed4 frag(v2f i) : SV_Target
			{
				fixed4 previous = tex2D(_PreviousAccomulatedColor, i.uv);
				fixed4 spray = tex2D(_ColorToAdd, float2(1 - i.uv.x, i.uv.y));

				fixed4 combined = 0;

				if (spray.a > 0.1)
				{
					float similarity = 1.7 - min(1.7, distance(previous.rgb, spray.rgb)); // 0.01 ... 1.7
					similarity = min(1, similarity * unity_DeltaTime.x * 100);
					float alpha = spray.a + previous.a * similarity;
					alpha = min(1, alpha);
					combined = fixed4(spray.rgb, alpha);

					//combined = fixed4(spray.rgb, spray.a); //DEBUG
				}
				else
				{
					combined = previous;
				}

				return combined;
				//return fixed4(col.a, col.a, col.a, 1); //DEBUG
			}
			ENDCG
		}
	}
	FallBack Off
}