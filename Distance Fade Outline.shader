// by Neitri, free of charge, free to redistribute
// downloaded from https://github.com/netri/Neitri-Unity-Shaders

// Fades outline based on how far it is behind objects and how far it is from camera
// Add it to bottom of material list in Renderer component, so whole object is rendered again with this material

Shader "Neitri/Distance Fade Outline"
{
	Properties
	{
		_OutlineColor ("Outline Color", Color) = (1, 1, 1, 1)
		_OutlineWidth ("Outline Width", Range(0, 1)) = 0.8
		_OutlineSmoothness ("Outline Smoothness", Range(0, 1)) = 0.1
		_FadeInBehindObjectsDistance ("Fade In Behind Objects Distance", Float) = 2
		_FadeOutBehindObjectsDistance ("Fade Out Behind Objects Distance", Float) = 4
		_FadeInCameraDistance ("Fade In Camera Distance", Float) = 10
		_FadeOutCameraDistance ("Fade Out Camera Distance", Float) = 15
		[Toggle] _ShowOutlineInFrontOfObjects ("Show Outline In Front Of Objects", Float) = 1
	}
	SubShader
	{
		Tags {
			"Queue"="Transparent"
			"RenderType"="Overlay" 
			"ForceNoShadowCasting"="True"
			"IgnoreProjector"="True"
		}
		LOD 300
		ZWrite Off
		ZTest Always
		Cull Back
		Blend SrcAlpha OneMinusSrcAlpha 

		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			
			#include "UnityCG.cginc"

			float4 _OutlineColor;
			float _OutlineWidth;
			float _OutlineSmoothness;
			float _FadeInBehindObjectsDistance;
			float _FadeOutBehindObjectsDistance;
			float _ShowOutlineInFrontOfObjects;
			float _FadeInCameraDistance;
			float _FadeOutCameraDistance;

			UNITY_DECLARE_DEPTH_TEXTURE(_CameraDepthTexture);

			struct appdata
			{
				float3 vertex : POSITION;
				float3 normal : NORMAL;
			};

			struct v2f
			{
				float4 vertex : SV_POSITION;
				float3 normal : TEXCOORD1;
				float4 worldPos : TEXCOORD2;
				float4 projPos : TEXCOORD3;
			};

			float3 getCameraPosition()
			{
				#ifdef USING_STEREO_MATRICES
					return lerp(unity_StereoWorldSpaceCameraPos[0], unity_StereoWorldSpaceCameraPos[1], 0.5);
				#endif
				return _WorldSpaceCameraPos;
			}
			
			v2f vert (appdata v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.normal = UnityObjectToWorldNormal(v.normal);
				o.worldPos = mul(unity_ObjectToWorld, float4(v.vertex, 1));
				o.projPos = ComputeScreenPos (o.vertex);
				o.projPos.z = -mul(UNITY_MATRIX_V, o.worldPos).z;
				return o;
			}
			
			fixed4 frag (v2f i) : SV_Target
			{
				float3 cameraPos = getCameraPosition();
				float3 viewDir = normalize(cameraPos - i.worldPos.xyz);
				
				// rim lighting taken from Poiyomi's shader
				float rim = 1 - max(dot(viewDir, i.normal), 0);
				rim = pow(rim, (1 - _OutlineWidth) * 10);
				_OutlineSmoothness /= 2;
				rim = smoothstep(_OutlineSmoothness, 1 - _OutlineSmoothness, rim);

				// fade based on distance from depth buffer
				float sceneDepth = LinearEyeDepth (SAMPLE_DEPTH_TEXTURE_PROJ(_CameraDepthTexture, UNITY_PROJ_COORD(i.projPos)));
				float objectDepth = i.projPos.z - 0.01; // little offset in case we dont want outlines in front of objects
				float behindObjectsDistance = objectDepth - sceneDepth;
				float behindObjectsFade = smoothstep(_FadeOutBehindObjectsDistance, _FadeInBehindObjectsDistance, behindObjectsDistance);

				// fade based on distance to camera
				float distanceToCamera = distance(cameraPos.xyz, i.worldPos.xyz);
				float cameraDistanceFade = smoothstep(_FadeOutCameraDistance, _FadeInCameraDistance, distanceToCamera);

				// optionally show outlines if in front of other objects
				float hideOutlinesIfInFrontOfObjects = min(1, step(0, behindObjectsDistance) + _ShowOutlineInFrontOfObjects);

				fixed4 result = _OutlineColor;
				result.a *= saturate(rim *  behindObjectsFade * cameraDistanceFade * hideOutlinesIfInFrontOfObjects);

				return result;
			}
			ENDCG
		}
	}
}
