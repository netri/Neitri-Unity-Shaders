Shader "Neitri/Debug/Light0 Direction Delta Add"
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
			float4 vert (float4 vertex : POSITION) : POSITION { return UnityObjectToClipPos(vertex); }
			float4 frag () : SV_Target { discard; return 0; }
			ENDCG
		}

		Pass
		{
			Name "FORWARD_DELTA"
			Tags { "LightMode"="ForwardAdd" }
			Blend One Zero
			Cull Back

			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			
			#include "UnityCG.cginc"
			#include "AutoLight.cginc"
			#include "Lighting.cginc"

			#pragma multi_compile_fwdadd_fullshadows

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
			};
			
			v2f vert (appdata v)
			{
				v2f o;
				o.pos = UnityObjectToClipPos(v.vertex);
				o.normalDir = UnityObjectToWorldNormal(v.normal);
				o.worldPos = mul(unity_ObjectToWorld, v.vertex);
				return o;
			}
			
			float4 frag (v2f i) : SV_Target
			{
				float3 normalDir = normalize(i.normalDir);
				float3 lightDirection = normalize(lerp(_WorldSpaceLightPos0.xyz, _WorldSpaceLightPos0.xyz - i.worldPos.xyz, _WorldSpaceLightPos0.w));
				float NdotL = saturate(dot(normalDir, lightDirection));
				return float4(NdotL, NdotL, NdotL, 1);
			}
			ENDCG
		}
	}

	FallBack Off
}
