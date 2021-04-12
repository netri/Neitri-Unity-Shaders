Shader "Neitri/Debug/Reflection Probe"
{
	Properties
	{
		_MipLevel ("_MipLevel", Int) = 0
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
			};

			struct v2f
			{
				float4 pos : SV_POSITION;
				float3 normalDir : TEXCOORD0;
			};

			int _MipLevel;

			v2f vert (appdata v)
			{
				v2f o;
				o.pos = UnityObjectToClipPos(v.vertex);
				o.normalDir = UnityObjectToWorldNormal(v.normal);
				return o;
			}
			
			float4 frag (v2f i) : SV_Target
			{
				float3 reflectionProbe = DecodeHDR(UNITY_SAMPLE_TEXCUBE_LOD(unity_SpecCube0, i.normalDir, _MipLevel), unity_SpecCube0_HDR);
				return float4(reflectionProbe, 1);
			}
			ENDCG
		}
	}

	FallBack Off
}
