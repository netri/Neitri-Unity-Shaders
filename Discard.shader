Shader "Neitri/Discard"
{
	Properties
	{
	}
	SubShader
	{
		Tags { "RenderType"="Opaque" }
		LOD 100

		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			
			struct appdata
			{
			};

			struct v2f
			{
			};

			v2f vert (appdata v)
			{
				v2f o;
				return o;
			}
			
			fixed4 frag (v2f i) : SV_Target
			{
				clip(-1);
				return fixed4(0,0,0,0);
			}
			ENDCG
		}
	}
}
