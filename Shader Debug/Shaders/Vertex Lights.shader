Shader "Neitri/Debug/Vertex Light"
{
	Properties
	{
	}
	SubShader
	{
		Tags { "RenderType"="Opaque" "IgnoreProjector"="True" }

		Pass
		{
			Name "FORWARD"
			Tags { "LightMode"="ForwardBase" }
			Cull Back

			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			
			#include "UnityCG.cginc"
			#include "AutoLight.cginc"
			#include "Lighting.cginc"

			#pragma multi_compile_fwdbase

			struct appdata
			{
				float4 vertex : POSITION;
				float3 normal : NORMAL;
				float4 tangent : TANGENT;
			};

			struct v2f
			{
				float4 pos : SV_POSITION;
				float4 worldPos : TEXCOORD0;
				float3 normalDir : TEXCOORD1;
				float3 ambientOrLightmapUV : TEXCOORD2;
			};

			v2f vert (appdata v)
			{
				v2f o;
				o.pos = UnityObjectToClipPos(v.vertex);
				o.normalDir = UnityObjectToWorldNormal(v.normal);
				o.worldPos = mul(unity_ObjectToWorld, v.vertex);
				

				#ifdef VERTEXLIGHT_ON
					// Approximated illumination from non-important point lights
					o.ambientOrLightmapUV.rgb = Shade4PointLights (
						unity_4LightPosX0, unity_4LightPosY0, unity_4LightPosZ0,
						unity_LightColor[0].rgb, unity_LightColor[1].rgb, unity_LightColor[2].rgb, unity_LightColor[3].rgb,
						unity_4LightAtten0, o.worldPos, o.normalDir);
				#endif

				return o;
			}
			
			float4 frag (v2f i) : SV_Target
			{
				return float4(i.ambientOrLightmapUV, 1);
			}
			ENDCG
		}

		// must be here to ignore important lights
		// if this was missing important lights would be rendered as non important in vertex lights above
		Pass
		{
			Name "FORWARD_DELTA"
			Tags { "LightMode" = "ForwardAdd" }
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			float4 vert (float4 vertex : POSITION) : POSITION { return UnityObjectToClipPos(vertex); }
			float4 frag () : SV_Target { discard; return 0; }

			ENDCG
		}
	}

	FallBack Off
}
