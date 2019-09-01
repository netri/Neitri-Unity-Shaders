Shader "Neitri/Graffiti Wall/Combine"
{
	Properties
	{
		_ColorToAdd("_ColorToAdd", 2D) = "white" {}
		_PreviousAccomulatedColor("_PreviousAccomulatedColor", 2D) = "white" {}
	}
	SubShader
	{
		Tags {
			"Queue" = "Transparent+100"
			"RenderType" = "Transparent"
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

			v2f vert(appdata v)
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

				const fixed3 clearColor = fixed3(1, 0, 1);
				if (distance(spray.rgb, clearColor) < 0.01)
				{
					// wipe paint
					combined.rgb = previous.rgb;
					combined.a = min(previous.a, saturate(1 - spray.a));
				}
				else if (spray.a > 0)
				{
					float similarity = (1.7 - min(1.7, distance(previous.rgb, spray.rgb))) / 1.7; // 0.01 ... 1
					float alpha = saturate(spray.a * unity_DeltaTime * 20 + previous.a * similarity);
					combined = fixed4(spray.rgb, alpha);

					//float delta = saturate(spray.a* unity_DeltaTime * 20);
					//combined.rgb = lerp(previous.rgb, spray.rgb, delta);
					//combined.a = lerp(previous.rgb, 1, delta);

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