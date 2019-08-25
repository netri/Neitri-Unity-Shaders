// created by Neitri, free of charge, free to redistribute
// downloaded from https://github.com/netri/Neitri-Unity-Shaders


#include "SimplexNoise2D.cginc"
#include "SimplexNoise3D.cginc"


// #define PARTICLES_ON_EDGE 1024
#define PARTICLES_ON_EDGE 512

#define DELTA_TIME (unity_DeltaTime.z)


sampler2D _ParticlesData;

float4 DataSave(float4 inPosition, float4 inVelocity, float2 inUv)
{
	if (inUv.x <= 0.5) return inPosition;
	return inVelocity;
}

void DataLoad(out float4 outPosition, out float4 outVelocity, float2 inUv)
{
	inUv.x = fmod(inUv.x, 0.5);
	outPosition = tex2Dlod(_ParticlesData, float4(inUv.x, inUv.y, 0, 0));
	outVelocity = tex2Dlod(_ParticlesData, float4(inUv.x + 0.5, inUv.y, 0, 0));
}