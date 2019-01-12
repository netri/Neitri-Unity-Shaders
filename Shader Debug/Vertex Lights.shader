Shader "Neitri/Debug/Vertex Light"
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
			Name "FORWARD"
            Tags { "LightMode"="ForwardBase" }
            Cull Off

			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			
			#include "UnityCG.cginc"
			#include "AutoLight.cginc"
			#include "Lighting.cginc"

			#pragma multi_compile_fwdbase

			struct VertexInput
			{
				float4 vertex : POSITION;
				float3 normal : NORMAL;
				float4 tangent : TANGENT;
				float2 uv0 : TEXCOORD0;
			};

			struct FragmentInput
			{
				float4 pos : SV_POSITION;
				float2 uv0 : TEXCOORD0;
				float4 posWorld : TEXCOORD1;
				float3 normalDir : TEXCOORD2;

				float3 ambientOrLightmapUV : TEXCOORD3;
			};

			sampler2D _MainTex;
			float4 _MainTex_ST;
			
			FragmentInput vert (VertexInput v)
			{
				FragmentInput o;
				o.uv0 = TRANSFORM_TEX(v.uv0, _MainTex);
				o.pos = UnityObjectToClipPos(v.vertex);
				o.normalDir = UnityObjectToWorldNormal(v.normal);
				o.posWorld = mul(unity_ObjectToWorld, v.vertex);
				

				#ifdef VERTEXLIGHT_ON
					// Approximated illumination from non-important point lights
					o.ambientOrLightmapUV.rgb = Shade4PointLights (
						unity_4LightPosX0, unity_4LightPosY0, unity_4LightPosZ0,
						unity_LightColor[0].rgb, unity_LightColor[1].rgb, unity_LightColor[2].rgb, unity_LightColor[3].rgb,
						unity_4LightAtten0, o.posWorld, o.normalDir);
				#endif

				return o;
			}
			
			float4 frag (FragmentInput i) : SV_Target
			{
				return float4(i.ambientOrLightmapUV, 1);
			}
			ENDCG
		}

		// to ignore important lights
		Pass
		{
			Name "FORWARD_DELTA"
			Tags { "LightMode" = "ForwardAdd" }
			CGPROGRAM
			#pragma only_renderers d3d11 glcore gles
			#pragma target 4.0
			#pragma multi_compile_fwdadd_fullshadows
			#pragma multi_compile_fog
			#pragma vertex vert
			#pragma fragment frag

			#include "UnityCG.cginc"

			struct appdata
			{
				float4 vertex : POSITION;
			};

			struct v2f
			{
				float4 vertex : SV_POSITION;
			};

			v2f vert(appdata v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				return o;
			}

			fixed4 frag(v2f i) : SV_Target
			{
				discard;
				return fixed4(0,0,0,0);
			}
			ENDCG
		}

	}

}
