Shader "Neitri/Debug/Light Probes"
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
			};

			sampler2D _MainTex;
			float4 _MainTex_ST;
			
			FragmentInput vert (VertexInput v)
			{
				FragmentInput o;
				o.pos = UnityObjectToClipPos(v.vertex);
				o.uv0 = TRANSFORM_TEX(v.uv0, _MainTex);
				o.normalDir = UnityObjectToWorldNormal(v.normal);
				o.posWorld = mul(unity_ObjectToWorld, v.vertex);
				return o;
			}
			
			float4 frag (FragmentInput i) : SV_Target
			{
				float3 normalDir = normalize(i.normalDir);
				half3 lightProbes = ShadeSH9(half4(normalDir, 1));
				return float4(lightProbes, 1);
			}
			ENDCG
		}
	}

}
