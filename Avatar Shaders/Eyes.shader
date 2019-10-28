Shader "Neitri/Avatar Shaders/Eyes"
{
	Properties
	{
		_MainTex ("Texture", 2D) = "white" {}
	}
	SubShader
	{
		Tags { "RenderType"="Opaque" }
		LOD 100

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
			};

			struct v2f
			{
				float4 vertex : SV_POSITION;
				float2 uv : TEXCOORD0;
				float4 worldPos : TEXCOORD1;
				UNITY_FOG_COORDS(2)
			};

			sampler2D _MainTex;
			float4 _MainTex_ST;
			
			v2f vert (appdata v)
			{
				v2f o;
				o.worldPos = mul(unity_ObjectToWorld, float4(v.vertex.xyz, 1.0));
				o.vertex = mul(UNITY_MATRIX_VP, o.worldPos);
				o.uv = TRANSFORM_TEX(v.uv, _MainTex);
				UNITY_TRANSFER_FOG(o,o.vertex);
				return o;
			}
			
			fixed4 frag (v2f i) : SV_Target
			{
				// sample the texture
				fixed4 col = tex2D(_MainTex, i.uv) * 1.5;

				float3 snow = 0;
				UNITY_BRANCH
				if (distance(i.worldPos, _WorldSpaceCameraPos) < 0.5)
				{
					float2 uv = i.uv;
					float _WIDTH = 0.79;
					float _DEPTH = 0.35;
					float _Sspeed = 1;
					float dof = 5. * sin(_Time.y * .1);
					//for (int i=0;i<_Snow;i++) {
					[unroll]
					for (int i = 0; i < 30; i++) {
						float fi = float(i);
						float2 q = uv * (1. + fi * _DEPTH);
						q += float2(q.y * (_WIDTH * fmod(fi * 7.238917, 1.) - _WIDTH * .5), _Sspeed * _Time.y / (1. + fi * _DEPTH * .03));
						float3 n = float3(floor(q), 31.189 + fi);
						float3 m = floor(n) * .00001 + frac(n);
						float3 mp = (31415.9 + m);
						float3 r = frac(mp);
						float2 s = abs(fmod(q, 1.) - .5 + .9 * r.xy - .45);
						s += .01 * abs(2. * frac(10. * q.yx) - 1.);
						float d = .6 * max(s.x - s.y, s.x + s.y) + max(s.x, s.y) - .01;
						float edge = .005 + .05 * min(.5 * abs(fi - 5. - dof), 1.);
						snow += (smoothstep(edge, -edge, d) * (r.x / (1. + .02 * fi * _DEPTH)));
					}
				}

				col.rgb += snow * smoothstep(0, 0.1, col.rgb) * 2;

				// apply fog
				UNITY_APPLY_FOG(i.fogCoord, col);
				return col;
			}
			ENDCG
		}
	}
}
