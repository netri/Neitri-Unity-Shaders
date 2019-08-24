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
				float4 depthTextureGrabPos : TEXCOORD1;
				float4 rayFromCamera : TEXCOORD2;
				float4 modelCenterPos : TEXCOORD3;
			};



			UNITY_DECLARE_DEPTH_TEXTURE(_CameraDepthTexture);

			sampler2D _MainTex; float4 _MainTex_ST;
			float _Scale;
			float _Range;

			// default most naive triplanar
			// 3 texture reads, best blending
			float4 defaultTriplanar(sampler2D tex, float3 position, float3 modelPos, float3 normal, float scale) 
			{
				position = (position - modelPos) / scale + 0.5;

				float3 blendWeights = pow(abs(normal), 3);
				blendWeights /= blendWeights.x + blendWeights.y + blendWeights.z;

				return	blendWeights.x * tex2D(tex, position.zy) +
						blendWeights.y * tex2D(tex, position.xz) +
						blendWeights.z * tex2D(tex, position.xy);
			}
			
			// based on Witcher 3 triplanar terrain mapping GDC presentation
			// reads texture only if it's weight is over threshold, good blending
			float4 witcherTriplanar(sampler2D tex, float3 position, float3 modelPos, float3 normal, float scale) 
			{
				position = (position - modelPos) / scale + 0.5;

				float3 blendWeights = pow(abs(normal), 3);
				blendWeights /= dot(blendWeights, 1);

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

			// error.mdl's approach
			// 1 texture read, no blending
			// good for bullet holes
			float4 errorTriplanar(sampler2D tex, float3 position, float3 modelPos, float3 normal, float scale) 
			{
				position = (position - modelPos) / scale + 0.5;
				normal = abs(normal);

				float2 coords = 
					step(normal.y,normal.x) * step(normal.z,normal.x) * position.zy +
					step(normal.x,normal.y) * step(normal.z,normal.y) * position.xz +
					step(normal.x,normal.z) * step(normal.y,normal.z) * position.xy;    

				return tex2D(tex, coords);
			}
			

			// Dj Lukis.LT's oblique view frustum correction (VRChat mirrors use such view frustum)
			// https://github.com/lukis101/VRCUnityStuffs/blob/master/Shaders/DJL/Overlays/WorldPosOblique.shader
			#define UMP UNITY_MATRIX_P
			inline float4 CalculateObliqueFrustumCorrection()
			{
				float x1 = -UMP._31 / (UMP._11 * UMP._34);
				float x2 = -UMP._32 / (UMP._22 * UMP._34);
				return float4(x1, x2, 0, UMP._33 / UMP._34 + x1 * UMP._13 + x2 * UMP._23);
			}
			static float4 ObliqueFrustumCorrection = CalculateObliqueFrustumCorrection();
			inline float CorrectedLinearEyeDepth(float z, float correctionFactor)
			{
				return 1.f / (z / UMP._34 + correctionFactor);
			}
			// Merlin's mirror detection
			inline bool CalculateIsInMirror()
			{
				return UMP._31 != 0.f || UMP._32 != 0.f;
			}
			static bool IsInMirror = CalculateIsInMirror();
			#undef UMP


			v2f vert(appdata v)
			{
				float4 worldPosition = mul(unity_ObjectToWorld, v.vertex);
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.depthTextureGrabPos = ComputeGrabScreenPos(o.vertex);
				o.rayFromCamera.xyz = worldPosition.xyz - _WorldSpaceCameraPos.xyz;
				o.rayFromCamera.w = dot(o.vertex, ObliqueFrustumCorrection); // oblique frustrum correction factor
				o.modelCenterPos = mul(UNITY_MATRIX_M, float4(0, 0, 0, 1));
				return o;
			}

			float4 frag(v2f i) : SV_Target
			{
				float perspectiveDivide = 1.f / i.vertex.w;
				float4 rayFromCamera = i.rayFromCamera * perspectiveDivide;
				float2 depthTextureGrabPos = i.depthTextureGrabPos.xy * perspectiveDivide;

				float z = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, depthTextureGrabPos);

				#if UNITY_REVERSED_Z
				if (z == 0.f) {
				#else
				if (z == 1.f) {
				#endif
					// this is skybox, depth texture has default value
					discard;
				}

				// linearize depth and use it to calculate background world position
				float depth = CorrectedLinearEyeDepth(z, rayFromCamera.w);

				float3 worldPosition = rayFromCamera.xyz * depth + _WorldSpaceCameraPos.xyz;

				fixed3 worldNormal;
				if (IsInMirror) // VRChat mirrors render with GL.invertCulling = true;
					worldNormal = cross(ddx(worldPosition), ddy(worldPosition));
				else
					worldNormal = cross(-ddx(worldPosition), ddy(worldPosition));

				worldNormal = normalize(worldNormal);

				clip(_Range - distance(worldPosition, i.modelCenterPos));

				//fixed4 color = defaultTriplanar(_MainTex, worldPosition, i.modelCenterPos, worldNormal, _Scale);
				fixed4 color = witcherTriplanar(_MainTex, worldPosition, i.modelCenterPos, worldNormal, _Scale);
				//fixed4 color = errorTriplanar(_MainTex, worldPosition, i.modelCenterPos, worldNormal, _Scale);

				clip(color.a - 0.01);
				return color;
			}

			ENDCG
		}
	}
}