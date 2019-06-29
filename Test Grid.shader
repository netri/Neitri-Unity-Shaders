Shader "Neitri/Test Grid" {
	Properties {
		_Color ("Color", Color) = (1,1,1,1)
		_MainTex ("Albedo (RGB)", 2D) = "white" {}
		_Glossiness ("Smoothness", Range(0,1)) = 0.5
		_Metallic ("Metallic", Range(0,1)) = 0.0
	}
	SubShader {
		Tags { "RenderType"="Opaque" }
		LOD 200

		CGPROGRAM
		#pragma surface surf Standard fullforwardshadows
		#pragma target 3.0

		sampler2D _MainTex;

		struct Input {
			float2 uv_MainTex;
			float3 worldPos;
		};

		half _Glossiness;
		half _Metallic;
		fixed4 _Color;

		void surf (Input IN, inout SurfaceOutputStandard o) {
			float3 pos = abs(IN.worldPos);
			float3 gray = float3(0.3, 0.59, 0.11);
			float3 color =
				frac(pos * 10) * 0.1 +
				frac(pos) * 0.6 +
				frac(pos * 0.1) * 0.3;
			color = dot(color, gray);
			color *= smoothstep(0, 1, length(pos));

			float3 c = fmod(round(pos), 2);
			float checkboard = c.x * c.z;

			o.Albedo = color * _Color;
			o.Metallic = _Metallic * checkboard;
			o.Smoothness = _Glossiness;
			o.Alpha = 1;
		}
		ENDCG
	}
	FallBack "Diffuse"
}
