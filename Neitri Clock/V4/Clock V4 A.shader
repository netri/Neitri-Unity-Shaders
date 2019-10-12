// Created by Neitri, free of charge, free to redistribute

Shader "Neitri/Clock V4 A"
{
	Properties
	{
		_MainTex ("_MainTex", 2D) = "white" {}
		_Color("_Color", Color) = (1,1,1,1)
		_Color2("_Color2", Color) = (1,1,1,1)
		_Color3("_Color3", Color) = (1,1,1,1)
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
				float3 model : TEXCOORD2;
				float4 color : COLOR;
				UNITY_FOG_COORDS(1)
			};

			sampler2D _MainTex;
			float4 _MainTex_ST;
			float4 _Color;
			float4 _Color2;
			float4 _Color3;
			
			float2 _CompassUvCenter;

			v2f vert (appdata v)
			{
				v2f o;
				o.uv = TRANSFORM_TEX(v.uv, _MainTex);
				o.color = _Color;
				o.progress = 0;
				o.model = v.vertex;

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
						uint fps1 = unity_DeltaTime.w;
						uint fps10 = floor(fps1 / 10);
						fps1 -= fps10 * 10;
						if (v.color.b == 0) {
							// fps
							o.uv.x += fps1 / 10.0f;
						} else {
							// 10 fps
							o.uv.x += fps10 / 10.0f;
							if (fps10 == 0) o.color *= 0.5;
						}
					}
				} else { // v.color.r == 0.5
					if (v.color.g == 0) {
						o.color = _Color2;
						if (v.color.b == 0) {
							// 10 seconds progress circle
							float d = fmod(_Time.y, 10) / 10;
							o.progress = float3(d, 1, 0);
						} else {
							// minute progress circle
							float d = fmod(_Time.y, 60) / 60;
							o.progress = float3(d, 1, 0);
						}
					} else { // v.color.g != 0
						o.color = _Color3;
						if (v.color.b == 0) {
							// fps circle
							float d = clamp(0, unity_DeltaTime.w / 90.0, 1);
							o.progress = float3(d, 1, 0);
						} else {
							// compass circle
							float3 objectForward = normalize(UnityObjectToWorldNormal(float3(1, 0, 0)));
							objectForward = normalize(objectForward - float3(0, 1, 0) * dot(objectForward, float3(0, 1, 0)));
							float dotToXPlus = dot(float3(1, 0, 0), objectForward);
							float a = acos(dotToXPlus) * sign(objectForward.z); // +PI..-PI
							a = a / 3.14159265359 / 2;
							a += 0.5; // 0..1

							a += 0.25; // rotate to point to X+
							a = 1 - frac(a);

							o.progress = float3(a, 0.07, 0.07);
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
					float a = atan2(i.model.x, i.model.y) / 3.14 * 0.5;
					if (i.model.x < 0) a = atan2(-i.model.x, -i.model.y) / 3.14 * 0.5 + 0.5;
					clip(i.progress.x - a + i.progress.z);
					clip(a - i.progress.x + i.progress.y);
				}
				clip(col.a - 0.01);
				// apply fog
				UNITY_APPLY_FOG(i.fogCoord, col);
				return col;
			}
			ENDCG
		}
	}
}
