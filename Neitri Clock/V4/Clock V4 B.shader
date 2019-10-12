// Created by Neitri, free of charge, free to redistribute

Shader "Neitri/Clock V4 B"
{
	Properties
	{
		_MainTex ("_MainTex", 2D) = "white" {}
		_Color("_Color", Color) = (1,1,1,1)
		_Color2("_Color2", Color) = (1,1,1,1)
		_Color3("_Color3", Color) = (1,1,1,1)
		_CirclesSpacing ("_CirclesSpacing", Range(0, 0.45)) = 0.4
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
				float3 uv : TEXCOORD0;
				float4 color : COLOR;
				UNITY_FOG_COORDS(1)
			};

			sampler2D _MainTex;
			float4 _MainTex_ST;
			float4 _Color;
			float4 _Color2;
			float4 _Color3;
			float _CirclesSpacing;

			v2f vert (appdata v)
			{
				v2f o;
				o.uv.xy = TRANSFORM_TEX(v.uv, _MainTex);
				o.uv.z = 0;
				o.color = _Color;

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
				}
				else { // v.color.r == 0.5
					if (v.color.g == 0) {
						if (v.color.b == 0) {
							o.uv.z = 1; // is progress circles quad
						}
					}
				}
				o.vertex = UnityObjectToClipPos(v.vertex);
				UNITY_TRANSFER_FOG(o,o.vertex);
				return o;
			}
			

			fixed4 frag (v2f i) : SV_Target
			{
				bool isProgressCirclesQuad = i.uv.z > 0.5;

				UNITY_BRANCH
				if (isProgressCirclesQuad)
				{
					const float width = 0.04;
					const float halfWidthRcp = rcp(width) * 2;

					float2 uv = i.uv.xy - 0.5;
					float radius = sqrt(dot(uv, uv));

					float distanceToEdge = 1;

					radius -= 8*width;
					clip(radius);  // inner empty circle
					float e = fmod(radius, width) / width;
					distanceToEdge = min(distanceToEdge, max(0, e)); // distance to circular edges between bars
					distanceToEdge = min(distanceToEdge, max(0, 1 - e));

					float thisPixelAngle = atan2(uv.x, uv.y) / UNITY_PI * 0.5;
					if (uv.x < 0) thisPixelAngle = atan2(-uv.x, -uv.y) / UNITY_PI * 0.5 + 0.5;		
					//         __ 0 __
					//        /       \
					//      /           \
					// 0.75 |           | 0.25
					//      \           /
					//        \_______/
					//           0.5

					fixed4 color;

					int type = ceil(radius / width);
					switch (type)
					{	
						case 4:
						{
							// compass circle
							float3 objectForward = normalize(UnityObjectToWorldNormal(float3(1, 0, 0)));

							objectForward = normalize(objectForward * float3(1, 0, 1)); // remove Y
							float dotToXPlus = dot(float3(1, 0, 0), objectForward);
							float a = acos(dotToXPlus) * sign(objectForward.z); // +PI..-PI
							a = a / UNITY_PI * 0.5; // +PI..-PI -> -0.5..0.5 
							a += 0.5; // -0.5..0.5 -> 0..1

							a += 0.25; // rotate to point to X+

							bool isUpsideDown = UnityObjectToWorldNormal(float3(0, 0, 1)).y < 0;
							a = isUpsideDown ? 0.5-a : a;

							a = frac(a);

							float c;

							c = a - thisPixelAngle + 0.07;
							clip(c);
							distanceToEdge = min(distanceToEdge, c * halfWidthRcp);

							c = thisPixelAngle - a + 0.07;
							clip(c);
							distanceToEdge = min(distanceToEdge, c * halfWidthRcp);
							color = _Color3;
							break;
						}
						case 3:
						{
							// minute progress circle
							float d = fmod(_Time.y, 60) / 60;
							float c = d - thisPixelAngle;
							clip(c);
							distanceToEdge = min(distanceToEdge, thisPixelAngle * halfWidthRcp); // distance to 0 angle
							distanceToEdge = min(distanceToEdge, c * halfWidthRcp);
							color = _Color2;
							break;
						}
						case 2:
						{
							// 10 seconds progress circle
							float d = fmod(_Time.y, 10) / 10;
							float c = d - thisPixelAngle;
							clip(c);
							distanceToEdge = min(distanceToEdge, thisPixelAngle * halfWidthRcp); // distance to 0 angle
							distanceToEdge = min(distanceToEdge, c * halfWidthRcp);
							color = _Color2;
							break;
						}
						case 1:
						{
							// fps circle
							float d = clamp(0, unity_DeltaTime.w / 90.0, 1);
							float c = d - thisPixelAngle;
							clip(c);
							distanceToEdge = min(distanceToEdge, thisPixelAngle * halfWidthRcp); // distance to 0 angle
							distanceToEdge = min(distanceToEdge, c * halfWidthRcp);

							color = _Color3;
							break;
						}
						default:
						{
							clip(-1);
							color = fixed4(0, 0, 0, 0);
							break;
						}
					}

					// DEBUG
					//return distanceToEdge;

					float spacing = _CirclesSpacing;
					const float smoothEdges = 0.05;
					clip(distanceToEdge - spacing);
					color.a *= smoothstep(spacing, spacing + smoothEdges, distanceToEdge);

					return color;
				}
				else
				{
					// number quad
					fixed4 color = tex2D(_MainTex, i.uv);
					clip(color.a - 0.1);

					color *= i.color;

					// apply fog
					UNITY_APPLY_FOG(i.fogCoord, color);
					return color;
				}
		
			}
			ENDCG
		}
	}
}
