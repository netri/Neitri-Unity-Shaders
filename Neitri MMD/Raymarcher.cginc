// by Neitri, free of charge, free to redistribute
// downloaded from https://github.com/netri/Neitri-Unity-Shaders

#define MAX_RAY_STEPS 20 //20
#define MIN_RAY_DISTANCE 0.0002
#define MAX_RAY_DISTANCE 0.05 // 0.05


float distanceMap_spheres(float3 p)
{
	#define SPHERES_SIZE (0.012 * _Raymarcher_Scale)
	p.x = fmod(p.x, SPHERES_SIZE * 2);
	p.y = fmod(p.y, SPHERES_SIZE * 2);
	p.z = fmod(p.z, SPHERES_SIZE * 2);
	p = abs(p) - SPHERES_SIZE;
	return length(p) - SPHERES_SIZE * 0.8;
}


float distanceMap_hearts(float3 p)
{
	// https://www.shadertoy.com/view/4lK3Rc Heart - 3D 
	// https://www.youtube.com/watch?v=aNR4n0i2ZlM formulanimations tutorial :: making a heart with maths
	// http://iquilezles.org/www/articles/distfunctions/distfunctions.htm

	//#define HEART_SCALE_DOWN 24.45
	//#define HEART_REPEAT 0.55 / HEART_SCALE_DOWN
	
	#define HEART_SCALE_DOWN (10.15 / _Raymarcher_Scale)
	#define HEART_REPEAT (0.45 / HEART_SCALE_DOWN)

	p += 10; // hearts are upside down with p = abs(p);

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

//#define RAYMARCHER_DISTANCE_FIELD_FUNCTION distanceMap_spheres
//#define RAYMARCHER_DISTANCE_FIELD_FUNCTION distanceMap_hearts


float2 traceDistanceField(float3 from, float3 direction) 
{
	float4 f = mul(unity_WorldToObject, float4(from, 1));
	from = f.xyz/f.w;
	direction = mul(unity_WorldToObject, direction).xyz;

	float totalDistance = 0.0;
	float3 p;
	int steps = 0;
#if defined(RAYMARCHER_DISTANCE_FIELD_FUNCTION)
	for (steps = 0; steps < MAX_RAY_STEPS; steps++) {
		p = from + totalDistance * direction;
		float distance = RAYMARCHER_DISTANCE_FIELD_FUNCTION(p);
		totalDistance += distance;
		if (distance < MIN_RAY_DISTANCE) return float2(totalDistance, steps);
		if (totalDistance > MAX_RAY_DISTANCE) return float2(MAX_RAY_DISTANCE, MAX_RAY_STEPS);
	}
#endif
	return float2(totalDistance, steps);
}


void raymarch(float3 worldRayStart, inout float3 color, out float screenDepth)
{
	screenDepth = 1;
	float3 worldRayDir = normalize(worldRayStart - _WorldSpaceCameraPos);
	float2 data = traceDistanceField(worldRayStart, worldRayDir);
	float totalDistance = data.x;
	float steps = data.y;
	color *= 1 - steps / MAX_RAY_STEPS;
	//color *= 1 - steps / MAX_RAY_STEPS;// - totalDistance / MAX_RAY_DISTANCE * 0.2f;
	//color *= 1 - min(0.3, saturate((steps * 3) / MAX_RAY_STEPS));
	float4 clipPos = mul(UNITY_MATRIX_VP, float4(worldRayStart + worldRayDir * totalDistance, 1.0));
	screenDepth = clipPos.z / clipPos.w;
}


