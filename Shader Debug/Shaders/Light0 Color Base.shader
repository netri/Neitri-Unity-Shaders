Shader "Neitri/Debug/Light0 Color Base"
{
	Properties
	{
		_MainTex ("Texture", 2D) = "white" {}
	}
	SubShader
	{
		Tags { "Queue" = "Geometry" "RenderType" = "Opaque" "IgnoreProjector" = "True" }
		Cull Back

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

			float4 vert (float4 vertex : POSITION) : POSITION { return UnityObjectToClipPos(vertex); }

			float4 frag () : SV_Target
			{
				return _LightColor0;
			}
			ENDCG
		}
	}

	FallBack Off
}
