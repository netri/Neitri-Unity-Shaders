// by Neitri, free of charge, free to redistribute
// downloaded from https://github.com/netri/Neitri-Unity-Shaders




float DistanceMap_spheres(float3 p)
{
	#define SPHERES_SIZE (0.012 * _Raymarcher_Scale)
	return length(abs(fmod(p, SPHERES_SIZE * 2)) - SPHERES_SIZE) - SPHERES_SIZE * 0.8;
}


float DistanceMap_hearts(float3 p)
{
	// https://www.shadertoy.com/view/4lK3Rc Heart - 3D 
	// https://www.youtube.com/watch?v=aNR4n0i2ZlM formulanimations tutorial :: making a heart with maths
	// http://iquilezles.org/www/articles/distfunctions/distfunctions.htm

	//#define HEART_SCALE_DOWN 24.45
	//#define HEART_REPEAT 0.55 / HEART_SCALE_DOWN
	
	#define HEART_SCALE_DOWN (10.15 / _Raymarcher_Scale)
	#define HEART_REPEAT (0.45 / HEART_SCALE_DOWN)

	//p += 10; // hearts are upside down with p = abs(p);
	p.y -= 5;
	p = abs(p);

	p = fmod(p, HEART_REPEAT) - 0.5*HEART_REPEAT;

	p *= 100.0 * HEART_SCALE_DOWN;
	float res = 0;
    
	float r = 15.0;
	const float ani = 1;
	p *= 1.0 - 0.2*float3(1.0,0.5,1.0)*ani;
	float x = abs(p.x);        
	float y = p.y;
	float z = p.z;
	y = 4.0 + y*1.2 - x*sqrt(max((20.0-x)/15.0,0.0));
	z *= 2.0 - y/15.0;
	float d = sqrt(x*x+y*y+z*z) - r;
	d = d/3.0;
	res = d;    
	res /= 100.0 * HEART_SCALE_DOWN;
	return res;
}

float2 TraceDistanceField(float3 from, float3 direction) 
{
	float4 f = mul(unity_WorldToObject, float4(from, 1));
	from = f.xyz/f.w;
	direction = mul(unity_WorldToObject, direction).xyz;

	float totalDistance = 0.0;
	float3 currentPos = from;
	int steps = 0;

	const float minRayDistance = 0.0002 * _Raymarcher_Scale;
	const float maxRayDistance = 0.05 * _Raymarcher_Scale; // 0.05

	UNITY_BRANCH
	if (_Raymarcher_Type == 1)
	{
		const int maxRayStep = 10;
		[loop]
		for (steps = 0; steps < maxRayStep; steps++) {
			float distance = DistanceMap_spheres(currentPos);
			currentPos += distance * direction;
			totalDistance += distance;
			if (distance < minRayDistance) return float2(totalDistance, steps/(float)(maxRayStep));
			if (totalDistance > maxRayDistance) return float2(maxRayDistance, 1);
		}
		return float2(totalDistance, steps/(float)(maxRayStep));
	}

	UNITY_BRANCH
	if (_Raymarcher_Type == 2)
	{
		const int maxRayStep = 20;
		[loop]
		for (steps = 0; steps < maxRayStep; steps++) {
			float distance = DistanceMap_hearts(currentPos);
			currentPos += distance * direction;
			totalDistance += distance;
			if (distance < minRayDistance) return float2(totalDistance, steps/(float)(maxRayStep));
			if (totalDistance > maxRayDistance) return float2(maxRayDistance, 1);
		}
		return float2(totalDistance, steps/(float)(maxRayStep));
	}

	return float2(0, 0);
}


void Raymarch(float3 worldRayStart, out float3 tint, out float screenDepth)
{
	float scale = length(mul(unity_ObjectToWorld, float3(0.577, 0.577, 0.577)));
	_Raymarcher_Scale *= scale;

	screenDepth = 1;
	
	float3 worldRayDir;
	if (unity_OrthoParams.w)
	{
		worldRayDir = normalize(-UNITY_MATRIX_I_V._13_23_33);
	}
	else
	{
		worldRayDir = normalize(worldRayStart - _WorldSpaceCameraPos);
	}

	float2 data = TraceDistanceField(worldRayStart, worldRayDir);
	float totalDistance = data.x;
	tint = 1 - data.y;
	//tint= 1 - steps / MAX_RAY_STEPS;// - totalDistance / maxRayDistance * 0.2f;
	//tint= 1 - min(0.3, saturate((steps * 3) / MAX_RAY_STEPS));
	#ifdef CHANGE_DEPTH
		float4 clipPos = mul(UNITY_MATRIX_VP, float4(worldRayStart + worldRayDir * totalDistance, 1.0));
		screenDepth = clipPos.z / clipPos.w;
	#endif
}


