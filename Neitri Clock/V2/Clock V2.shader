// Created by Neitri, free of charge, free to redistribute

Shader "Neitri/Clock V2"
{
	Properties
	{
		_MainTex ("_MainTex", 2D) = "white" {}
		_DigitsOffset("_DigitsOffset", Range(0, 0.5)) = 0.085
		_Color("_Color", Color) = (1,1,1,1)
		_SecondsProgressSize("_SecondsProgressSize", Float) = 0.00011
		_FPSProgressSize("_FPSProgressSize", Float) = 0.00053
	}
	SubShader
	{
		Tags{
			"Queue" = "Transparent"
			"RenderType" = "Transparent"
		}
		LOD 100
		Cull Off
		Blend SrcAlpha OneMinusSrcAlpha // transparent

		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			// make fog work
			#pragma multi_compile_fog
			
			#include "UnityCG.cginc"

			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
				float4 color : COLOR;
			};

			struct v2f
			{
				float4 vertex : SV_POSITION;
				float2 uv : TEXCOORD0;
				float4 color : COLOR;
				UNITY_FOG_COORDS(1)
			};

			sampler2D _MainTex;
			float4 _MainTex_ST;
			float _DigitsOffset;
			float4 _Color;
			float _SecondsProgressSize;
			float _FPSProgressSize;

			
			v2f vert (appdata v)
			{
				v2f o;
				o.uv = TRANSFORM_TEX(v.uv, _MainTex);
				o.color = _Color;

				int s1 = floor(_Time.y);
				int s10 = floor(s1 / 10);
				int m1 = floor(s10 / 6);
				int m10 = floor(m1 / 10);
				int h1 = floor(m10 / 6);
				int h10 = floor(h1 / 10);

				s1 -= s10 * 10;
				s10 -= m1 * 6;
				m1 -= m10 * 10;
				m10 -= h1 * 6;
				h1 -= h10 * 10;

				if (v.color.r == 0) {
					if (v.color.g == 0) {
						if (v.color.b == 0) {
							// seconds
							o.uv.x += s1 * _DigitsOffset;
						} else {
							// 10 seconds
							o.uv.x += s10 * _DigitsOffset;
						}
					} else {
						if (v.color.b == 0) {
							// minutes
							o.uv.x += m1 * _DigitsOffset;
						} else {
							// 10 minutes
							o.uv.x += m10 * _DigitsOffset;
						}
					}
				} else if (v.color.r == 1) {
					if (v.color.g == 0) {
						if (v.color.b == 0) {
							// hours
							o.uv.x += h1 * _DigitsOffset;
						} else {
							// 10 hours
							o.uv.x += h10 * _DigitsOffset;
						}
					} else {
						if (v.color.b == 0) {
							// :
							o.color *= fmod(floor(_Time.y * 2), 2);
						} else {
							// nothing, static texture
						}
					}
				} else {
					if (v.color.g == 0) {
						if (v.color.b == 0) {
							// seconds progress indicator
							if (o.uv.x > 0.5) {
								float d = frac(_Time.y);
								v.vertex.x += _SecondsProgressSize * (1 - d);
							}
						} else {
							// fps indicator
							if (o.uv.x > 0.5) {
								float d = unity_DeltaTime.w/90.0;
								d = saturate(d); 
								v.vertex.x += _FPSProgressSize * (1 - d);
							}
						}
					} 
				}				

				o.vertex = UnityObjectToClipPos(v.vertex);
				UNITY_TRANSFER_FOG(o,o.vertex);
				return o;
			}
			
			fixed4 frag (v2f i) : SV_Target
			{
				fixed4 col = tex2D(_MainTex, i.uv) * i.color;
				//clip(col.a - 0.1);
				// apply fog
				UNITY_APPLY_FOG(i.fogCoord, col);
				return col;
			}
			ENDCG
		}
	}
}
