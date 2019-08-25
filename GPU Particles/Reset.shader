// created by Neitri, free of charge, free to redistribute

Shader "Neitri/GPU Particles/Reset"
{
	Properties
	{
		[Enum(Plane,0,Cube,1,Noise,2,DepthTexture,3)] _Shape ("_Shape", Int) =2 
		_Scale ("_Scale", Float) = 1
		[Toggle] _ClampToSphere ("_ClampToSphere", Int) = 1
		_DepthTexture ("_DepthTexture", 2D) = "white" {}
		_DepthTextureRange ("_DepthTextureRange", Float) = 1
	}
	SubShader
	{
		Tags 
		{
			"RenderType"="Opaque" 
			"IgnoreProjector"="True"
			"DisableBatching"="True"
		}

		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			#include "UnityCG.cginc"
			#include "Common.cginc"

			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
			};

			struct v2f
			{
				float2 uv : TEXCOORD0;
				float4 vertex : SV_POSITION;
			};

			v2f vert (appdata v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.uv = v.uv;
				return o;
			}
			
			float _Shape;
			float _Scale;
			int _ClampToSphere;
			sampler2D _DepthTexture;
			float _DepthTextureRange;

			float4 frag (v2f i) : SV_Target
			{
				float3 position;
				float3 velocity = float3(0, 0, 0);

				float2 uv = i.uv;

				// PLANE
				if (_Shape == 0)
				{
					position = float3(i.uv.x, i.uv.y, 0);
				}
				
				// CUBE
				if (_Shape == 1)
				{
					float slices = 0.1;
					position = float3(
						fmod(uv.x, slices), 
						fmod(uv.y, slices), 
						(ceil(uv.x / slices) * slices + ceil(uv.y / slices)) * slices * slices
					) / slices;
				}

				// RANDOM NOISE
				if (_Shape == 2)
				{
					float n = snoise(float2(uv.x, uv.y)*100) * 0.5f;
					float nx = snoise(float2(uv.x, uv.y)*5) + n;
					float ny = snoise(float2(uv.x*10, uv.y)) + n;
					float nz = snoise(float2(uv.x, uv.y*10)) - n;
					position = float3(nx, ny, nz);
				}
		
				// DEPTH TEXTURE
				if (_Shape == 3)
				{
					float depth = tex2Dlod(_DepthTexture, float4(uv.x * 2, uv.y, 0, 0)).r;
					position = float3(uv.x, uv.y, depth * _DepthTextureRange);
				}		

				//DEBUG
				//position = float3(i.uv.x, 0, i.uv.y) * 10;

				if (_ClampToSphere)
				{
					float l = length(position);
					if (l > 1) position = position / l;
				}

				// scale up
				position *= _Scale;

				// move to position of this object
				float4 modelPos = mul(unity_ObjectToWorld, float4(0,0,0,1));
				position += modelPos.xyz / modelPos.w;

				
				
				float2 parent;
				{
					float nx = snoise(float2(uv.x, uv.y * 3));
					float ny = snoise(float2(uv.x * 3, uv.y));
					parent = abs(float2(nx, ny));
					if (parent.x + parent.y < 0.8) parent = 0;
				}


				return DataSave(float4(position, parent.x), float4(velocity, parent.y), uv);
			}
			ENDCG
		}
	}
	FallBack Off
}

