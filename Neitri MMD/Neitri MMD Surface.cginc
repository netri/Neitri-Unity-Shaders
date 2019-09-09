
#include "UnityCG.cginc"


struct SurfaceIn
{
	float2 uv0;
};

struct SurfaceOut
{
	fixed3 Albedo; // diffuse color
	fixed3 Normal; // tangent space normal, if written
	fixed3 Emission;
	fixed Glossiness;
	fixed Alpha; // alpha for transparencies
	#ifdef CHANGE_DEPTH
	float Depth;
	#endif
};