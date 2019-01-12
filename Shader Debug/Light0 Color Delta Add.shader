Shader "Neitri/Debug/Light0 Color Delta Add"
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
			float4 vert (float4 vertex : POSITION) : POSITION { return UnityObjectToClipPos(vertex); }
			float4 frag (float4 pos : SV_POSITION) : SV_Target { return float4(0, 0, 0, 1); }
			ENDCG
		}

		Pass
		{
			Name "FORWARD_DELTA"
            Tags { "LightMode"="ForwardAdd" }
            Cull Off
			Blend One Zero

			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			
			#include "UnityCG.cginc"
			#include "AutoLight.cginc"
			#include "Lighting.cginc"

			#pragma multi_compile_fwdadd_fullshadows

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
				return _LightColor0;
			}
			ENDCG
		}
	}

}
