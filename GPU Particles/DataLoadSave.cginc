// created by Neitri, free of charge, free to redistribute


//#define PACK_DATA

#define FRAG_RETURN float4

sampler2D _ParticlesData;

FRAG_RETURN DataSave(float4 inPosition, float4 inVelocity, float2 inUv)
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