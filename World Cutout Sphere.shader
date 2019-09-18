// by Neitri, free of charge, free to redistribute
// downloaded from https://github.com/netri/Neitri-Unity-Shaders

Shader "Neitri/World Cutout Sphere"
{
	Properties
	{
		_MainTex ("_MainTex", 2D) = "black" {}
	}
	SubShader
	{
		Tags 
		{
			"Queue" = "Geometry+1"
			"RenderType" = "Opaque"
			"IgnoreProjector"="True"
			"DisableBatching"="True"
		}

		Cull Front
		ZTest Off
		ZWrite On

		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#include "UnityCG.cginc"

			struct appdata
			{
				float3 vertex : POSITION;
				float2 uv: TEXCOORD0;
			};
			struct v2f
			{
				float4 vertex : SV_POSITION;
				float2 uv : TEXCOORD0;
				float4 modelPosWS : TEXCOORD1;
				float4 projPosCS : TEXCOORD2;
				float3 objectPosLS : TEXCOORD3;
			};

			sampler2D _MainTex; float4 _MainTex_ST;

			UNITY_DECLARE_DEPTH_TEXTURE(_CameraDepthTexture);

			v2f vert (appdata v)
			{
				v2f o;
				o.uv = v.uv;
				o.modelPosWS = mul(unity_ObjectToWorld, float4(v.vertex, 1));
				o.vertex = mul(UNITY_MATRIX_VP, o.modelPosWS);
				o.objectPosLS = v.vertex;
				o.projPosCS = ComputeScreenPos (o.vertex);
				o.projPosCS.z = -mul(UNITY_MATRIX_V, o.modelPosWS).z;
				return o;
			}

			float4 frag (v2f i) : SV_Target
			{
				float sceneDepth = LinearEyeDepth (SAMPLE_DEPTH_TEXTURE_PROJ(_CameraDepthTexture, UNITY_PROJ_COORD(i.projPosCS)));
				float objectDepth = i.projPosCS.z;
				clip(objectDepth - sceneDepth);
	
				// cast ray from camera towards pixel, and find oposite sphere edge of pixel
				// discard if the edge is bellow scene

				float3 r0 = _WorldSpaceCameraPos;
				float3 rd = normalize(i.modelPosWS - r0);
				float3 s0 = mul(unity_ObjectToWorld, float4(0,0,0,1));
				float sr = 0.5 * length(mul(unity_ObjectToWorld, float4(1,0,0,0)));

				// ray sphere intersection from https://gist.githubusercontent.com/wwwtyro/beecc31d65d1004f5a9d/raw/8da8bb7b986f48b94ce9163d539b49eb7a5d4478/gistfile1.glsl
				// - r0: ray origin
				// - rd: normalized ray direction
				// - s0: sphere center
				// - sr: sphere radius
				// - Returns distance from r0 to first intersecion with sphere,
				//   or -1.0 if no intersection.
				float a = dot(rd, rd);
				float3 s0_r0 = r0 - s0;
				float b = 2.0 * dot(rd, s0_r0);
				float c = dot(s0_r0, s0_r0) - (sr * sr);
				float d = b*b - 4.0*a*c;
				clip(d);

				float t = (-b - sqrt(d))/(2.0*a);
				float3 intersectionPosWS = r0 + rd * t;
				float intersectDepth = -mul(UNITY_MATRIX_V, float4(intersectionPosWS, 1.0)).z;
				clip(sceneDepth-intersectDepth);

				return float4(i.uv, 0, 1);
				return tex2D(_MainTex, i.uv);
			}

			ENDCG
		}
	}
}