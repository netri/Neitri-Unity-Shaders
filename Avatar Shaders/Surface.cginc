
#include "UnityCG.cginc"

// inspired by https://docs.unity3d.com/Manual/SL-SurfaceShaders.html

struct SurfaceIn
{
	float2 uv0;
	float3 worldPos; // contains world space position
	float4 screenPos; // contains screen space position for reflection or screenspace effects
	float4 color;
};

struct SurfaceOut
{
	fixed3 Albedo; // diffuse color
	fixed3 Normal; // tangent space normal, if written
	fixed3 Emission;
	half Occlusion;
	half Metallic; // 0=non-metal, 1=metal
	half Smoothness; // 0=rough, 1=smooth
	half Anisotropic; // 0=no anisotropy
	fixed Alpha; // alpha for transparencies
	#ifdef CHANGE_DEPTH
		float Depth;
	#endif
};