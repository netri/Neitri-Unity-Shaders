Shader "Neitri/Debug/HDR Detector"
{
	Properties
	{
		_MainTex("Texture", 2D) = "white" {}
	}
	
	SubShader
	{
		Tags { "Queue" = "Geometry" "RenderType" = "Opaque" "IgnoreProjector" = "True" }
		Cull Back

		Pass
		{
			Blend One Zero
			Cull Back
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

			sampler2D _MainTex;
			float4 _MainTex_ST;

			v2f vert(appdata v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.uv = TRANSFORM_TEX(v.uv, _MainTex);
				return o;
			}

			fixed4 frag(v2f i) : SV_Target
			{
				fixed4 colorOff = tex2D(_MainTex, i.uv);
				fixed4 colorOn = tex2D(_MainTex, i.uv - float2(0.5f, 0.f));
				clip(colorOff.a + colorOn.a - 0.1);

				return float4(colorOff.a, 0, 0, 1001);
			}

			ENDCG
		}

		Pass
		{
			Blend OneMinusDstAlpha One
			Cull Back
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

			sampler2D _MainTex;
			float4 _MainTex_ST;

			v2f vert(appdata v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.uv = TRANSFORM_TEX(v.uv, _MainTex);
				return o;
			}

			fixed4 frag(v2f i) : SV_Target
			{
				fixed4 colorOff = tex2D(_MainTex, i.uv);
				fixed4 colorOn = tex2D(_MainTex, i.uv - float2(0.5f, 0.f));
				clip(colorOff.a + colorOn.a - 0.1);

				return float4(colorOff.a * 0.001, colorOn.a * -0.001, 0, 0);
			}

			ENDCG
		}

		/*
		// Version that uses only red green color, no texture
		Pass
		{
			Blend One Zero
			Cull Off
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#include "UnityCG.cginc"
			float4 vert(float4 vertex : POSITION) : POSITION { return UnityObjectToClipPos(vertex); }
			float4 frag() : SV_Target { return float4(1, 0, 0, 1001); }
			ENDCG
		}

		Pass
		{
			Blend OneMinusDstAlpha One
			Cull Off
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#include "UnityCG.cginc"
			float4 vert(float4 vertex : POSITION) : POSITION { return UnityObjectToClipPos(vertex); }
			float4 frag() : SV_Target { return float4(0.001, -0.001, 0, 0); }
			ENDCG
		}
		*/
	}

	FallBack Off
}
