Shader "Neitri/Debug/Light0 Color Delta Add"
{
	Properties
	{
	}
	SubShader
	{
		Tags { "RenderType"="Opaque" "IgnoreProjector"="True" }
		LOD 100

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
			Cull Back
			Blend One Zero

			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			
			#include "UnityCG.cginc"
			#include "AutoLight.cginc"
			#include "Lighting.cginc"

			#pragma multi_compile_fwdadd_fullshadows

			float4 vert (float4 vertex : POSITION) : POSITION { return UnityObjectToClipPos(vertex); }
			
			float4 frag () : SV_Target
			{
				return _LightColor0;
			}
			ENDCG
		}

		UsePass "VertexLit/SHADOWCASTER"
	}

	FallBack Off
}
