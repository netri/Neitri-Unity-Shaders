// by Neitri, free of charge, free to redistribute
// downloaded from https://github.com/netri/Neitri-Unity-Shaders

// Credits
// error.mdl - First Depth Mirror

Shader "Neitri/Depth Mirror" 
{
	Properties 
	{
		_MainTex ("_MainTex", 2D) = "white" {}
		_DepthTex ("_DepthTex", 2D) = "white" {}
		_DepthRange ("_DepthRange", Float) = 1
	}
	SubShader 
	{
		Tags 
		{
			"IgnoreProjector"="True"
			"Queue"="Geometry"
			"RenderType"="Opaque"
			"DisableBatching"="True"
		}
		Pass 
		{
			Tags 
			{
				"LightMode" = "Always"
			}
			Blend SrcAlpha OneMinusSrcAlpha
			Cull Off
			
			CGPROGRAM
			#pragma vertex vert
			#pragma geometry geom
			#pragma fragment frag
			#include "UnityCG.cginc"

			#pragma multi_compile_fwdbase
			#pragma only_renderers d3d9 d3d11 glcore gles 
			#pragma target 5.0

			sampler2D _MainTex;
			sampler2D _DepthTex; 
			float4 _DepthTex_TexelSize;
			float _DepthRange;
			
			struct appdata
			{
			};

			struct fragIn
			{
				float4 position : SV_POSITION;
				float2 uv : TEXCOORD0;
			};

			appdata vert (appdata v)
			{
				return v;
			}

			[maxvertexcount(4)]
			void geom(uint primitiveId : SV_PrimitiveID, point appdata IN[1], inout TriangleStream<fragIn> tristream)
			{
				float off = 1.0 / _DepthTex_TexelSize.z;

				// uv coordinates in the middle of depth texture texels
				float2 uv1 = float2(
					fmod(primitiveId, _DepthTex_TexelSize.z),
					floor(primitiveId / _DepthTex_TexelSize.z)
				) / _DepthTex_TexelSize.z + off/2;
				float2 uv0 = uv1 + float2(off, 0);
				float2 uv2 = uv1 + float2(off, off);
				float2 uv3 = uv1 + float2(0, off);
				
				// if nothing rendered into depth texture it has depth 0
				float depth0 = tex2Dlod(_DepthTex, float4(uv0.x, uv0.y, 0, 0));
				float depth1 = tex2Dlod(_DepthTex, float4(uv1.x, uv1.y, 0, 0));
				float depth2 = tex2Dlod(_DepthTex, float4(uv2.x, uv2.y, 0, 0));
				float depth3 = tex2Dlod(_DepthTex, float4(uv3.x, uv3.y, 0, 0));
				
				float4 depths = float4(depth0, depth1, depth2, depth3);

				// discard quad if depth was not rendered at all
				if (dot(depths, 1) <= 0)
				{
					return;
				}
		
				float depthMax = 0; // closest to camera renderd depth
				float depthMin = 1; // furthest from camera rendered depth

				// find min and max rendered depth
				#define FIND_DEPTH_DATA(INDEX) \
					if (depth##INDEX > 0) { \
						depthMin = min(depth##INDEX, depthMin); \
						depthMax = max(depth##INDEX, depthMax); \
					}
				FIND_DEPTH_DATA(0)
				FIND_DEPTH_DATA(1)
				FIND_DEPTH_DATA(2)
				FIND_DEPTH_DATA(3)

				// if some vertice doesnt have rendered depth, clamp it to furthest rendered depth
				#define ADJUST_DEPTH(INDEX) \
					if (depth##INDEX <= 0) depth##INDEX = depthMin;
				ADJUST_DEPTH(0)
				ADJUST_DEPTH(1)
				ADJUST_DEPTH(2)
				ADJUST_DEPTH(3)


				// if quad has too big normal, move all 4 vertices to closest rendered depth
				depths = float4(depth0, depth1, depth2, depth3);
				if(dot(abs(depths.wzxy - depths.zxyw), 1) > 0.4 / _DepthRange)
				{
					depth0 = depth1 = depth2 = depth3 = depthMax;
				}

				// 3______2
				//	|   /|
				//  |  / |
				//  | /  |
				//  |/___| 
				// 1      0

				fragIn o;
				
				#define APPEND(INDEX) \
					o.uv = uv##INDEX; \
					o.position = UnityObjectToClipPos(float4(uv##INDEX.x - 0.5, uv##INDEX.y - 0.5, _DepthRange * 0.5 * depth##INDEX, 1)); \
					tristream.Append(o); \
				
				APPEND(3)
				APPEND(1)
				APPEND(2)
				APPEND(0)
			}
			
			fixed4 frag(fragIn i) : SV_Target 
			{
				fixed4 color = tex2D(_MainTex, i.uv);
				clip (color.a - 0.1);

				return fixed4(color.rgb, 1);
			}

			ENDCG
		}
	}

	Fallback Off
}
