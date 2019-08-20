// by Neitri, free of charge, free to redistribute
// downloaded from https://github.com/netri/Neitri-Unity-Shaders

Shader "Neitri/Normals Projector"
{
	Properties
	{
		[Enum(Local Space,0,World Space,1)] _NormalsSpace("Normals Space", Range(0, 2)) = 1
	}

		SubShader
	{
		Tags
		{
			"IgnoreProjector" = "True"
			"Queue" = "Transparent+1000"
			"RenderType" = "Transparent"
		}

		Pass
		{
			//Blend SrcAlpha OneMinusSrcAlpha
			Blend One Zero
			ZWrite Off
			Cull Off
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			#include "UnityCG.cginc"

			int _NormalsSpace;

			float4x4 unity_Projector;
			float4x4 unity_ProjectorClip;

			struct appdata
			{
				float4 vertex : POSITION;
				float3 normal : NORMAL;
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};

			struct v2f
			{
				float4 screenPos : SV_POSITION;
				float3 normal : TEXCOORD0;
				float4 projectorPos : TEXCOORD1;
				float4 projectorClip : TEXCOORD2;
				UNITY_VERTEX_OUTPUT_STEREO
			};

			v2f vert(appdata v)
			{
				v2f o;
				UNITY_SETUP_INSTANCE_ID(v);
				UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
				o.screenPos = UnityObjectToClipPos(v.vertex);
				o.normal = _NormalsSpace == 0 ? v.normal : UnityObjectToWorldNormal(v.normal);
				o.projectorPos = mul(unity_Projector, v.vertex);
				o.projectorClip = mul(unity_ProjectorClip, v.vertex);
				return o;
			}


			float4 frag(v2f i) : SV_Target
			{
				float z = i.projectorClip.x;
				clip(z);
				clip(1 - z);
				float strength = 0.5 - distance(i.projectorPos.xy / i.projectorPos.w, float2(0.5, 0.5));
				//strength = smoothstep(0, 0.1, strength);
				clip(strength);
				float3 color = normalize(i.normal);
				return float4(color, 1);
			}


			ENDCG
		}
	}
	
	FallBack Off

}
