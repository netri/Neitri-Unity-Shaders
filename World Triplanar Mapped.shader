// by Neitri, free of charge, free to redistribute
// downloaded from https://github.com/netri/Neitri-Unity-Shaders

Shader "Neitri/World Triplanar Mapped"
{
	Properties
	{
		_MainTex ("_MainTex", 2D) = "black" {}
		_Scale ("_Scale", Range(0.1, 10)) = 0.2
		_Range ("_Range", Range(0, 10)) = 10
	}
	SubShader
	{
		Tags 
		{
			"Queue" = "Transparent+1000"
			"RenderType" = "Transparent"
		}

		Cull Off
		Blend SrcAlpha OneMinusSrcAlpha

		Pass
		{
			// based on "Neitri/World Normal Ugly Fast"

			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#include "UnityCG.cginc"

			struct appdata
			{
				float4 vertex : POSITION;
			};
			struct v2f
			{
				float4 vertex : SV_POSITION;
				float4 modelPos : TEXCOORD1;
				float4 projPos : TEXCOORD2;
				float3 ray : TEXCOORD3;
			};

			UNITY_DECLARE_DEPTH_TEXTURE(_CameraDepthTexture);

			sampler2D _MainTex; float4 _MainTex_ST;
			float _Scale;
			float _Range;

			float4 neitriTriPlanar1(sampler2D tex, float3 position, float3 modelPos, float3 normal, float scale) 
			{
				position = (position - modelPos) / scale + 0.5;
							
				float3 blendWeights = pow(abs(normal), 3);
				blendWeights /= blendWeights.x + blendWeights.y + blendWeights.z;

				return	blendWeights.x * tex2D(tex, position.zy) +
						blendWeights.y * tex2D(tex, position.xz) +
						blendWeights.z * tex2D(tex, position.xy);
			}
			
			float4 neitriTriPlanar2(sampler2D tex, float3 position, float3 modelPos, float3 normal, float scale) 
			{
				position = (position - modelPos) / scale + 0.5;

				float3 blendWeights = pow(abs(normal), 3);
				blendWeights /= blendWeights.x + blendWeights.y + blendWeights.z;

				const float threshold = 0.05;

				float3 finalWeights = 0;
				if(blendWeights.x > threshold) finalWeights.x = blendWeights.x;
				if(blendWeights.y > threshold) finalWeights.y = blendWeights.y;
				if(blendWeights.z > threshold) finalWeights.z = blendWeights.z;
				finalWeights /= finalWeights.x + finalWeights.y + finalWeights.z;

				float4 result = 0;
				if(finalWeights.x > 0) result += finalWeights.x * tex2D(tex, position.zy);
				if(finalWeights.y > 0) result += finalWeights.y * tex2D(tex, position.xz);
				if(finalWeights.z > 0) result += finalWeights.z * tex2D(tex, position.xy);
				return result;
			}

			float4 errorTriPlanar(sampler2D tex, float3 position, float3 modelPos, float3 normal, float scale) 
			{
				position = (position - modelPos) / scale + 0.5;
				normal = abs(normal);

				float2 coords = 
					step(normal.y,normal.x) * step(normal.z,normal.x) * position.zy +
					step(normal.x,normal.y) * step(normal.z,normal.y) * position.xz +
					step(normal.x,normal.z) * step(normal.y,normal.z) * position.xy;    

				return tex2D(tex, coords);
			}
			

			v2f vert (appdata v)
			{
				v2f o;
				o.modelPos = mul(unity_ObjectToWorld, float4(0, 0, 0, 1));
				o.ray = mul(unity_ObjectToWorld, v.vertex) - _WorldSpaceCameraPos;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.projPos = ComputeScreenPos (o.vertex);
				COMPUTE_EYEDEPTH(o.projPos.z);
				return o;
			}

			float4 frag (v2f i) : SV_Target
			{
				float sceneZ = LinearEyeDepth (SAMPLE_DEPTH_TEXTURE_PROJ(_CameraDepthTexture, UNITY_PROJ_COORD(i.projPos)));
				float3 worldPosition = sceneZ * i.ray / i.projPos.z + _WorldSpaceCameraPos;

				fixed3 worldNormal = normalize(cross(-ddx(worldPosition), ddy(worldPosition)));

				clip(_Range - distance(worldPosition, i.modelPos));

				//fixed4 color = neitriTriPlanar1(_MainTex, worldPosition, i.modelPos, worldNormal, _Scale);
				//fixed4 color = neitriTriPlanar2(_MainTex, worldPosition, i.modelPos, worldNormal, _Scale);
				fixed4 color = errorTriPlanar(_MainTex, worldPosition, i.modelPos, worldNormal, _Scale);

				clip(color.a - 0.01);

				return color;
			}

			ENDCG
		}
	}
}
