Shader "Neitri/Graffiti Wall/Data Adjust"
{
	Properties
	{
		_Color("_Color", Color) = (1,1,1,1)
	}
	SubShader
	{
		Tags { 
			"Queue" = "Transparent"
			"RenderType"="Transparent" 
		}
		Blend One Zero
		ZWrite Off
		Cull Off

		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			struct appdata
			{
				float4 vertex : POSITION;
			};

			struct v2f
			{
				float4 vertex : SV_POSITION;
			};

			float4 _Color;
			
			v2f vert (appdata v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				return o;
			}
			
			fixed4 frag (v2f i) : SV_Target
			{
				return _Color;
			}
			ENDCG
		}
	}
}
