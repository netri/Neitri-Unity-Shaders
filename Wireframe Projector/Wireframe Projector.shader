// MIT license
// Modified by Neitri
// Original: https://github.com/Chaser324/unity-wireframe
// Which is based on: http://developer.download.nvidia.com/SDK/10/direct3d/Source/SolidWireframe/Doc/SolidWireframe.pdf

Shader "Neitri/Wireframe Projector"
{
	Properties
	{
		_WireThickness("Wire Thickness", RANGE(0, 800)) = 100
		_WireSmoothness("Wire Smoothness", RANGE(0, 20)) = 3
		_Color("Color", Color) = (0.0, 1.0, 0.0, 1.0)
		//_MaxTriSize("Max Tri Size", RANGE(0, 200)) = 25
	}

	SubShader
	{
		Tags
		{
			"IgnoreProjector" = "True"
			"Queue" = "Transparent"
			"RenderType" = "Transparent"
		}

		Pass
		{
			Blend SrcAlpha OneMinusSrcAlpha
			ZWrite Off
			Cull Off
			CGPROGRAM
			#pragma vertex vert
			#pragma geometry geom
			#pragma fragment frag

			#include "UnityCG.cginc"


			uniform float _WireThickness = 100;
			uniform float _WireSmoothness = 3;
			uniform float4 _Color = float4(0.0, 1.0, 0.0, 1.0);
			//uniform float _MaxTriSize = 25.0;


			float4x4 unity_Projector;
			float4x4 unity_ProjectorClip;

			struct appdata
			{
				float4 vertex : POSITION;
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};

			struct v2g
			{
				float4 screenPos : SV_POSITION;
				float4 worlPos : TEXCOORD1;
				float4 projectorPos : TEXCOORD2;
				float4 projectorClip : TEXCOORD4;
				UNITY_VERTEX_OUTPUT_STEREO
			};

			struct g2f
			{
				float4 screenPos : SV_POSITION;
				float4 worlPos : TEXCOORD0;
				float4 projectorPos : TEXCOORD1;
				float4 projectorClip : TEXCOORD2;
				float4 dist : TEXCOORD3;
				float4 area : TEXCOORD4;
				UNITY_VERTEX_OUTPUT_STEREO
			};

			v2g vert(appdata v)
			{
				v2g o;
				UNITY_SETUP_INSTANCE_ID(v);
				UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
				o.screenPos = UnityObjectToClipPos(v.vertex);
				o.worlPos = mul(unity_ObjectToWorld, v.vertex);
				o.projectorPos = mul(unity_Projector, v.vertex);
				o.projectorClip = mul(unity_ProjectorClip, v.vertex);
				return o;
			}

			[maxvertexcount(3)]
			void geom(triangle v2g i[3], inout TriangleStream<g2f> triangleStream)
			{
				float2 p0 = i[0].screenPos.xy / i[0].screenPos.w;
				float2 p1 = i[1].screenPos.xy / i[1].screenPos.w;
				float2 p2 = i[2].screenPos.xy / i[2].screenPos.w;

				float2 edge0 = p2 - p1;
				float2 edge1 = p2 - p0;
				float2 edge2 = p1 - p0;

				float4 worldEdge0 = i[0].worlPos - i[1].worlPos;
				float4 worldEdge1 = i[1].worlPos - i[2].worlPos;
				float4 worldEdge2 = i[0].worlPos - i[2].worlPos;

				// To find the distance to the opposite edge, we take the
				// formula for finding the area of a triangle Area = Base/2 * Height, 
				// and solve for the Height = (Area * 2)/Base.
				// We can get the area of a triangle by taking its cross product
				// divided by 2. However we can avoid dividing our area/base by 2
				// since our cross product will already be double our area.
				float area = abs(edge1.x * edge2.y - edge1.y * edge2.x);
				float wireThickness = 800 - _WireThickness;

				g2f o;

				o.area = float4(0, 0, 0, 0);
				o.area.x = max(length(worldEdge0), max(length(worldEdge1), length(worldEdge2)));

				o.worlPos = i[0].worlPos;
				o.screenPos = i[0].screenPos;
				o.projectorPos = i[0].projectorPos;
				o.projectorClip = i[0].projectorClip;
				o.dist.xyz = float3((area / length(edge0)), 0.0, 0.0) * o.screenPos.w * wireThickness;
				o.dist.w = 1.0 / o.screenPos.w;
				UNITY_TRANSFER_VERTEX_OUTPUT_STEREO(i[0], o);
				triangleStream.Append(o);

				o.worlPos = i[1].worlPos;
				o.screenPos = i[1].screenPos;
				o.projectorPos = i[1].projectorPos;
				o.projectorClip = i[1].projectorClip;
				o.dist.xyz = float3(0.0, (area / length(edge1)), 0.0) * o.screenPos.w * wireThickness;
				o.dist.w = 1.0 / o.screenPos.w;
				UNITY_TRANSFER_VERTEX_OUTPUT_STEREO(i[1], o);
				triangleStream.Append(o);

				o.worlPos = i[2].worlPos;
				o.screenPos = i[2].screenPos;
				o.projectorPos = i[2].projectorPos;
				o.projectorClip = i[2].projectorClip;
				o.dist.xyz = float3(0.0, 0.0, (area / length(edge2))) * o.screenPos.w * wireThickness;
				o.dist.w = 1.0 / o.screenPos.w;
				UNITY_TRANSFER_VERTEX_OUTPUT_STEREO(i[2], o);
				triangleStream.Append(o);
			}

			fixed4 frag(g2f i) : SV_Target
			{
				fixed z = i.projectorClip.x;
				clip(z);
				clip(1 - z);
				fixed strength = 0.5 - distance(i.projectorPos.xy / i.projectorPos.w, float2(0.5, 0.5));
				clip(strength);

				 float r = i.dist[3];
				 r = max(r, 1);

				float minDistanceToEdge = min(i.dist[0], min(i.dist[1], i.dist[2])) * r;

				// Early out if we know we are not on a line segment.
				if (minDistanceToEdge > 0.9) //|| i.area.x > _MaxTriSize
				{
					discard;
				}

				// Smooth our line out
				//float t = exp2(_WireSmoothness * -1.0 * minDistanceToEdge * minDistanceToEdge);
				strength = smoothstep(0, 0.2, strength);
				strength *= smoothstep(0.9, 0, minDistanceToEdge);
				fixed4 finalColor = fixed4(_Color.xyz, strength);

				
				return finalColor;
			}


			ENDCG
		}
	}

	FallBack Off
}
