// Created by Neitri, free of charge, free to redistribute

Shader "Neitri/Clock V3 Realtime World Only"
{
	Properties
	{
		_Texture("Texture", 2D) = "black" {}
		_MainTex("Sync Texture", 2D) = "white" {}
		_Color("Color", Color) = (1,1,1,1)
	}
	SubShader
	{
		Tags
		{
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
				float3 progress : TEXCOORD1;
				float4 color : COLOR;
				UNITY_FOG_COORDS(2)
			};

			sampler2D _Texture;
			float4 _Texture_ST;

			sampler2D _MainTex;
			float4 _MainTex_ST;

			float4 _Color;


			int getHour(float3 textureFloats) {
				return round(((textureFloats.x + textureFloats.y + textureFloats.z) / 3) * 24);
			}

			int getMinSec(float3 textureFloats) {
				return round(((textureFloats.x + textureFloats.y + textureFloats.z) / 3) * 60);
			}

			uint getTime()
			{


			}


			v2f vert (appdata v)
			{
				v2f o;
				o.uv = TRANSFORM_TEX(v.uv, _MainTex);
				o.color = _Color;
				o.progress = 0;


				// from y23586's realtime clock https://github.com/y23586/vrchat-time-shaders
				const float4 x1 = {1.0/8, 0, 0, 0};
				const float4 y1 = {0, 1.0/8, 0, 0};
				const int3 sec0 = round(tex2Dlod(_MainTex, x1*3.5+y1*0.5).rgb);
				const int3 sec1 = round(tex2Dlod(_MainTex, x1*2.5+y1*0.5).rgb);
				const int3 min0 = round(tex2Dlod(_MainTex, x1*5.5+y1*0.5).rgb);
				const int3 min1 = round(tex2Dlod(_MainTex, x1*4.5+y1*0.5).rgb);
				const int3 hour0 = round(tex2Dlod(_MainTex, x1*7.5+y1*0.5).rgb);
				const int3 hour1 = round(tex2Dlod(_MainTex, x1*6.5+y1*0.5).rgb);

				const float secf    =  sec0.r +  sec0.g*2 +  sec0.b*4 +  sec1.r*8 +  sec1.g*16 +  sec1.b*32 + _Time.y;
				const float minutef =  min0.r +  min0.g*2 +  min0.b*4 +  min1.r*8 +  min1.g*16 +  min1.b*32 + secf/60.0;
				const float hourf   = hour0.r + hour0.g*2 + hour0.b*4 + hour1.r*8 + hour1.g*16 + hour1.b*32 + minutef/60.0;

				const uint sec    = ((uint)secf) % 60;
				const uint minute = ((uint)minutef) % 60;
				const uint hour   = ((uint)hourf) % 24;

				uint s1 = sec % 10;
				uint s10 = floor(sec / 10);
				uint m1 = minute % 10;
				uint m10 = floor(minute / 10);
				uint h1 = hour % 10;
				uint h10 = floor(hour / 10);

				if (v.color.r == 0) {
					if (v.color.g == 0) {
						if (v.color.b == 0) {
							// seconds
							o.uv.x += s1 / 10.0f;
						} else {
							// 10 seconds
							o.uv.x += s10 / 10.0f;
						}
					} else {
						if (v.color.b == 0) {
							// minutes
							o.uv.x += m1 / 10.0f;
							if (h10 + h1 + m10 + m1 == 0) o.color *= 0.5;
						} else {
							// 10 minutes
							o.uv.x += m10 / 10.0f;
							if (h10 + h1 + m10 == 0) o.color *= 0.5;
						}
					}
				} else if (v.color.r == 1) {
					if (v.color.g == 0) {
						if (v.color.b == 0) {
							// hours
							o.uv.x += h1 / 10.0f;
							if (h10 + h1 == 0) o.color *= 0.5;
						} else {
							// 10 hours
							o.uv.x += h10 / 10.0f;
							if (h10 == 0) o.color *= 0.5;
						}
					} else {
						if (v.color.b == 0) {
							// :
							o.color *= fmod(floor(_Time.y * 2), 2);
						} else {
							// static texture
						}
					}
				} else { // v.color.r == 0.5
					if (v.color.g == 0) {
						if (v.color.b == 0) {
							// seconds progress indicator
							float d = frac(_Time.y);
							o.progress = float3(d, 0.15, 0.05);
						} else {
							// fps indicator
							float d = unity_DeltaTime.w / 90.0;
							d = saturate(d); 
							o.progress = float3(d, 0.03, 0.01);
						}
					}
				}				

				o.vertex = UnityObjectToClipPos(v.vertex);
				UNITY_TRANSFER_FOG(o,o.vertex);
				return o;
			}
			
			fixed4 frag (v2f i) : SV_Target
			{
				fixed4 col = tex2D(_Texture, i.uv) * i.color;
				
				if (i.progress.x > 0)
				{
					col.a *= step(0, i.progress.x - floor(i.uv.x / i.progress.y) * i.progress.y);
					col.a *= step(-0.5, floor(i.uv.x / i.progress.y) - floor((i.uv.x + i.progress.z) / i.progress.y));
					// DEBUG
					//col.a = step(0, i.progress.x - i.uv.x);
				}
				if (col.a < 0.3) discard;
				// apply fog
				UNITY_APPLY_FOG(i.fogCoord, col);
				return col;
			}
			ENDCG
		}
	}
}
