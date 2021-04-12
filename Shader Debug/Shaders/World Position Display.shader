// based on Digital Display by Snail downloaded from https://github.com/theepicsnail/Shaders/tree/master/DigitalDisplay

Shader "Neitri/Debug/World Position Display"
{
	Properties
	{
		_MainTex("DigitTex", 2D) = "white" {}
		_Digits("Digits", Float) = 10
		_Precision("Precision", Float) = 3
	}
	SubShader
	{
		Blend SrcAlpha OneMinusSrcAlpha
		Tags { "RenderType"="Transparent" "Queue"="Transparent" "IgnoreProjector"="True" }
		Cull Back

		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			
			#include "UnityCG.cginc"

			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
				float4 color : COLOR;
			};

			struct v2f
			{
				float4 vertex : SV_POSITION;
				float2 uv : TEXCOORD0;
				float4 color : TEXCOORD1;
				float4 worldPos : TEXCOORD2;
			};
			
			sampler2D _MainTex;
			float _Digits;
			fixed _Precision;
		
			v2f vert (appdata v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.uv = v.uv;
				o.color = v.color;
				o.worldPos = mul(unity_ObjectToWorld, float4(0, 0, 0, 1));
				return o;
			}

			float2 DigitCalculator(float2 uv , float digits, float precision, float value)
			{

				return uv;
			}

			fixed4 frag (v2f i) : SV_Target
			{
				float value = 2;
				
				// vertex -> fragment interpolation causes artefacts on 0.001 digit, so it has to be calculated here
				float4 worldPos = mul(unity_ObjectToWorld, float4(0, 0, 0, 1));

				value = lerp(value, worldPos.x, step(0.1, i.color.r));
				value = lerp(value, worldPos.y, step(0.1, i.color.g));
				value = lerp(value, worldPos.z, step(0.1, i.color.b));


				// 0 1 2 ... Digits-1
				// index of this digit on display, 0 is left most digit, 1 is second from left digit
				float displayDigitIndex = floor(i.uv.x * _Digits);

				// leanup/fix precision.
				float precision = _Precision;
				//precision = (precision+1)*saturate(precision)-1;
				
				// same for all pixels
				float decimalDotIndex = _Digits-precision-1;

				float x = displayDigitIndex - decimalDotIndex;
				float e = 1-saturate(x)+x;

				float adjustedValue = abs(value);
				//value += .000001;

				adjustedValue *= pow(10, e);

		
				
				float isNegative = value < 0;
				float firstDigitIndex = _Digits - ceil(log10(max(1, ceil(abs(value)))));
				firstDigitIndex -= floor(abs(value)) == 0; // make sure 0. digit is shown if value is under 1

				// should the digit be hidden, to prevent displaying digits like 00000.001, we just need 0.001
				float digitAlpha = displayDigitIndex + _Precision + 2 + isNegative > firstDigitIndex;

				float textureCharIndex = floor(fmod(adjustedValue,10));
				
				// if this is decimal dot, force dot character index
				textureCharIndex = lerp(textureCharIndex, 10, x == 0);

				// if this is negative sign, force negative sign character index
				textureCharIndex = lerp(textureCharIndex, 11, isNegative && firstDigitIndex == displayDigitIndex + _Precision + 2);

				i.uv.x = (frac(i.uv.x*_Digits)+textureCharIndex)/12;

				fixed4 col = tex2D( _MainTex, i.uv);
				col.a *= digitAlpha;
				return 
					col *
					lerp(1, i.color, col.a); // ignore vertex color with increased transparency, so transparent border can have gray color
			}

			ENDCG
		}		
	}

	Fallback Off
}