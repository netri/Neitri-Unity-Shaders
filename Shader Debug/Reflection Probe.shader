Shader "Neitri/Debug/Reflection Probe"
{
	Properties
	{
		_MainTex ("Texture", 2D) = "white" {}
		_MipLevel ("_MipLevel", Int) = 0
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

			int _MipLevel;

			FragmentInput vert (VertexInput v)
			{
				FragmentInput o;
				o.uv0 = TRANSFORM_TEX(v.uv0, _MainTex);
				o.pos = UnityObjectToClipPos(v.vertex);
				o.normalDir = UnityObjectToWorldNormal(v.normal);
				o.posWorld = mul(unity_ObjectToWorld, v.vertex);
				return o;
			}
			
			float4 frag (FragmentInput i) : SV_Target
			{
				float3 reflectionProbe = DecodeHDR(UNITY_SAMPLE_TEXCUBE_LOD(unity_SpecCube0, i.normalDir, _MipLevel), unity_SpecCube0_HDR);
				return float4(reflectionProbe, 1);
			}
			ENDCG
		}
	}

}
