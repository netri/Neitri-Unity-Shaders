// Created by Neitri, free of charge, free to redistribute

Shader "Neitri/Clock V1"
{
	Properties
	{
		_MainTex ("_MainTex", 2D) = "white" {}
		_Color("_Color", Color) = (1,1,1,1)
		_Offset("_Offset", Range(0, 0.5)) = 0.085
	}
	SubShader
	{
		Tags{
			"Queue" = "Transparent"
			"RenderType" = "Transparent"
		}
		LOD 100
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
			float4 _Color;
			float _Offset;
			
			v2f vert (appdata v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.uv = TRANSFORM_TEX(v.uv, _MainTex);
				o.color = _Color;
				UNITY_TRANSFER_FOG(o,o.vertex);


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
							o.uv.x += s1 * _Offset;
						} else {
							o.uv.x += s10 * _Offset;
						}
					} else {
						if (v.color.b == 0) {
							o.uv.x += m1 * _Offset;
						} else {
							o.uv.x += m10 * _Offset;
						}
					}
				} else {
					if (v.color.g == 0) {
						if (v.color.b == 0) {
							o.uv.x += h1 * _Offset;
						} else {
							o.uv.x += h10 * _Offset;
						}
					} else {
						if (v.color.b == 0) {
							o.uv.x += fmod(floor(_Time.y * 2), 2) * _Offset;
						} else {

						}
					}
				}

				return o;
			}
			
			fixed4 frag (v2f i) : SV_Target
			{
				fixed4 col = tex2D(_MainTex, i.uv) * i.color;
				// apply fog
				UNITY_APPLY_FOG(i.fogCoord, col);
				return col * col.a;
			}
			ENDCG
		}
	}
}
