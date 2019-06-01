// Created by Neitri, free of charge, free to redistribute

Shader "Neitri/Clock V3"
{
	Properties
	{
		_MainTex ("_MainTex", 2D) = "white" {}
		_Color("_Color", Color) = (1,1,1,1)
		_CompassUvCenter("_CompassUvCenter", Vector) = (0.8,0.395,0,0)
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
				float3 progress : TEXCOORD1;
				float4 color : COLOR;
				UNITY_FOG_COORDS(2)
			};

			sampler2D _MainTex;
			float4 _MainTex_ST;
			float4 _Color;
			
			float2 _CompassUvCenter;

			v2f vert (appdata v)
			{
				v2f o;
				o.uv = TRANSFORM_TEX(v.uv, _MainTex);
				o.color = _Color;
				o.progress = 0;

				uint s1 = floor(_Time.y);
				uint s10 = floor(s1 / 10);
				uint m1 = floor(s10 / 6);
				uint m10 = floor(m1 / 10);
				uint h1 = floor(m10 / 6);
				uint h10 = floor(h1 / 10);

				s1 -= s10 * 10;
				s10 -= m1 * 6;
				m1 -= m10 * 10;
				m10 -= h1 * 6;
				h1 -= h10 * 10;

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
					} else {
						if (v.color.b == 0) {
							// compass
							float3 objectForward = normalize(UnityObjectToWorldNormal(float3(1, 0, 0)));
							objectForward = normalize(objectForward - float3(0, 1, 0) * dot(objectForward, float3(0, 1, 0)));
							float dotToXPlus = dot(float3(1,0,0), objectForward);
							float a = acos(dotToXPlus) * sign(objectForward.z);
							a -= 3.14/2; // 90 degress to fix teexture rotation to face X+
							float2x2 rot = float2x2(cos(a), -sin(a), sin(a), cos(a));
							float2 uv =  v.uv - _CompassUvCenter.xy;
							uv.y /= 2;
							uv = mul(rot, uv);
							uv.y *= 2;
							uv += _CompassUvCenter.xy;
							o.uv = uv;
						} else {
							// empty
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
