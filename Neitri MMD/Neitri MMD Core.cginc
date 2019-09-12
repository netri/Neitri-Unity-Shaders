// by Neitri, free of charge, free to redistribute
// downloaded from https://github.com/netri/Neitri-Unity-Shaders

// Some ideas are from:
// Cubed's https://github.com/cubedparadox/Cubeds-Unity-Shaders
// Xiexe's https://github.com/Xiexe/Xiexes-Unity-Shaders



#include "UnityCG.cginc"

#include "AutoLight.cginc"
#include "Lighting.cginc" // _LightColor0

#include "UnityPBSLighting.cginc"
#include "UnityStandardBRDF.cginc"




#define USE_NORMAL_MAP

#ifdef USE_NORMAL_MAP
#define USE_TANGENT_BITANGENT
#endif

#ifdef IS_OUTLINE_SHADER
#define USE_GEOMETRY_STAGE
#endif

#ifdef _MESH_DEFORMATION_ON
UNITY_DECLARE_DEPTH_TEXTURE(_CameraDepthTexture);
#endif



int _EmissionType;

float3 _ShadowColor;
float3 _ShadowRim;

float _BakedLightingFlatness;
float _ApproximateFakeLight;

float _Shadow; // name from Cubed's
Texture2D _Ramp; // name from Xiexe's

int _MatcapType;
float4 _MatcapTint; // name from Xiexe's
float _MatcapWeight;
int _MatcapAnchor;
Texture2D _Matcap;

#ifdef IS_OUTLINE_SHADER
float4 _OutlineColor;
float _OutlineWidth;
#endif

float _AlphaCutout;
int _ShowInMirror;
int _DitheredTransparencyType;
float3 _LightSkew; // name from Silent's

// DEBUG
int _DebugInt1;
int _DebugInt2;
float _DebugFloat1;


// ensure we sample with linar clamp sampler settings regardless of texture import settings
// useful for ramp or matcap textures to prevent user errors
// https://docs.unity3d.com/Manual/SL-SamplerStates.html
SamplerState Sampler_Linear_Clamp;


struct VertexIn {
	float4 vertex : POSITION;
	float3 normal : NORMAL;
	float3 tangent : TANGENT;
	float2 texcoord0 : TEXCOORD0;
};

struct GeometryIn {
	float4 vertex : SV_POSITION;
	float3 normal : TEXCOORD0;
	float3 tangent : TEXCOORD1;
	float2 texcoord0 : TEXCOORD2;
};

void CopyVertex(in VertexIn from, out GeometryIn to)
{
	to.vertex = from.vertex;
	to.normal = from.normal;
	to.tangent = from.tangent;
	to.texcoord0 = from.texcoord0;
}


struct FragmentIn {
	float4 pos : SV_POSITION; // must be called pos, because TRANSFER_VERTEX_TO_FRAGMENT expects pos
	float4 uv0 : TEXCOORD0; // w == 1 marks outline pixel
	float4 worldPos : TEXCOORD1;
	float3 normal : TEXCOORD2;
	LIGHTING_COORDS(3, 4) // shadow coords
	UNITY_FOG_COORDS(5) 
	float3 modelPos : TEXCOORD6;
	#ifdef UNITY_PASS_FORWARDBASE
		float4 vertexLightsReal : TEXCOORD7;
		float4 vertexLightsAverage : TEXCOORD8;
	#endif
	#ifdef USE_TANGENT_BITANGENT
		float3 tangentDir : TEXCOORD9;
		float3 bitangentDir : TEXCOORD10;
	#endif
};


// based off Shade4PointLights from "\Unity\builtin_shaders-5.6.5f1\CGIncludes\UnityCG.cginc"
float3 NeitriAverageVertexLights(float3 modelCenterPos)
{
	// BAD: does not take into account distance to lights
	//return (lightColor0 + lightColor1 + lightColor2 + lightColor3) * 0.25;

	// to light vectors
	float4 toLightX = unity_4LightPosX0 - modelCenterPos.x;
	float4 toLightY = unity_4LightPosY0 - modelCenterPos.y;
	float4 toLightZ = unity_4LightPosZ0 - modelCenterPos.z;
	// squared lengths
	float4 lengthSq = 0;
	lengthSq += toLightX * toLightX;
	lengthSq += toLightY * toLightY;
	lengthSq += toLightZ * toLightZ;
	// don't produce NaNs if some vertex position overlaps with the light
	lengthSq = max(lengthSq, 0.000001);
	// attenuation
	// original: float4 atten = 1.0 / (1 + lengthSq * unity_4LightAtten0);
	float4 atten = 1.0 / (1.0 + lengthSq * unity_4LightAtten0 * 2.0);
	//atten = 1.0 / (1 + lengthSq * unity_4LightAtten0);
	float4 diff = atten;
	// final color
	float3 col = 0;
	col += unity_LightColor[0].rgb * diff.x;
	col += unity_LightColor[1].rgb * diff.y;
	col += unity_LightColor[2].rgb * diff.z;
	col += unity_LightColor[3].rgb * diff.w;
	return col;
}

// based off Shade4PointLights from "\Unity\builtin_shaders-5.6.5f1\CGIncludes\UnityCG.cginc"
float3 NeitriRealVertexLights(float3 pos, float3 normal)
{
	// to light vectors
	float4 toLightX = unity_4LightPosX0 - pos.x;
	float4 toLightY = unity_4LightPosY0 - pos.y;
	float4 toLightZ = unity_4LightPosZ0 - pos.z;
	// squared lengths
	float4 lengthSq = 0;
	lengthSq += toLightX * toLightX;
	lengthSq += toLightY * toLightY;
	lengthSq += toLightZ * toLightZ;
	// don't produce NaNs if some vertex position overlaps with the light
	lengthSq = max(lengthSq, 0.000001);
	// NdotL
	float4 ndotl = 0;
	ndotl += toLightX * normal.x;
	ndotl += toLightY * normal.y;
	ndotl += toLightZ * normal.z;
	// correct NdotL
	float4 corr = rsqrt(lengthSq);
	ndotl = max(float4(0, 0, 0, 0), ndotl * corr);
	// attenuation
	float4 atten = 1.0 / (1 + lengthSq * unity_4LightAtten0);
	float4 diff = ndotl * atten;
	// final color
	float3 col = 0;
	col += unity_LightColor[0].rgb * diff.x;
	col += unity_LightColor[1].rgb * diff.y;
	col += unity_LightColor[2].rgb * diff.z;
	col += unity_LightColor[3].rgb * diff.w;
	return col;
}





float3 GetCameraPosition()
{
#ifdef USING_STEREO_MATRICES
	//return lerp(unity_StereoWorldSpaceCameraPos[0], unity_StereoWorldSpaceCameraPos[1], 0.5);
	return unity_StereoWorldSpaceCameraPos[0];
#else
	return _WorldSpaceCameraPos;
#endif
}

float3 GetCameraForward()
{
#if UNITY_SINGLE_PASS_STEREO
	float3 p1 = mul(unity_StereoCameraToWorld[0], float4(0, 0, 1, 0));
#else
	float3 p1 = mul(unity_CameraToWorld, float4(0, 0, 1, 0));
#endif
	return normalize(p1);
}

float3 GetCameraRight()
{
#if UNITY_SINGLE_PASS_STEREO
	float3 p1 = mul(unity_StereoCameraToWorld[0], float4(1, 0, 0, 0));
#else
	float3 p1 = mul(unity_CameraToWorld, float4(1, 0, 0, 0));
#endif
	return normalize(p1);
}

float3 GetCameraUp()
{
#if UNITY_SINGLE_PASS_STEREO
	float3 p1 = mul(unity_StereoCameraToWorld[0], float4(0, 1, 0, 0));
#else
	float3 p1 = mul(unity_CameraToWorld, float4(0, 1, 0, 0));
#endif
	return normalize(p1);
}

// Merlin's mirror detection
inline bool IsInMirror()
{
	return UNITY_MATRIX_P._31 != 0.f || UNITY_MATRIX_P._32 != 0.f;
}

#ifdef USE_GEOMETRY_STAGE
FragmentIn VertexProgramProxy(in GeometryIn v) 
#else
FragmentIn VertexProgramProxy(in VertexIn v)
#endif
{
	FragmentIn o = (FragmentIn)0;
	o.uv0.xy = v.texcoord0;
	o.normal = UnityObjectToWorldNormal(v.normal);
	#ifdef USE_TANGENT_BITANGENT
		o.tangentDir = UnityObjectToWorldNormal(v.tangent);
		o.bitangentDir = normalize(cross(o.normal, o.tangentDir));
	#endif
	o.worldPos = mul(unity_ObjectToWorld, float4(v.vertex.xyz, 1.0));
	o.pos = mul(UNITY_MATRIX_VP, o.worldPos);
	o.modelPos = v.vertex;

	
#ifdef _MESH_DEFORMATION_ON
	// Broken now, inspiration: https://gumroad.com/naelstrof Contact Shader for VRChat, https://www.youtube.com/watch?v=JAIbjUHZyNg
	float4 projPos = ComputeScreenPos(o.pos);
	float4 pcoord = float4(projPos.xy / projPos.w, 0, 0);
	float sceneDepth = LinearEyeDepth (tex2Dlod(_CameraDepthTexture, pcoord));
	float vertexDepth = mul(UNITY_MATRIX_V, o.worldPos).z;
	float value = (vertexDepth - sceneDepth) / _ProjectionParams.z * 0.1;
	value = value * (abs(value) > 0.1);
	v.vertex += v.normal * value;
	o.normal.z += value;
	o.normal.z = normalize(o.normal.z);
	o.worldPos = mul(unity_ObjectToWorld, float4(v.vertex, 1.0));
	o.pos = mul(UNITY_MATRIX_VP, o.worldPos);
#endif

	float3 objectWorldPos = mul(unity_ObjectToWorld, float4(0, 0, 0, 1));
	
	// vertex lights are a cheap way to calculate 4 lights without shadows at once
	// Unity renders first few lights as pixel lights with shadows in base/delta pass
	// next 4 are calculated using vertex lights
	// next are added to light probes
	// you can force light to be in vertex lights by setting Render Mode: Not Important
	#ifdef UNITY_PASS_FORWARDBASE
		#ifdef VERTEXLIGHT_ON // defined only in frgament shader
			// Approximated illumination from non-important point lights
			o.vertexLightsReal.rgb = NeitriRealVertexLights(o.worldPos, o.normal);
			o.vertexLightsAverage.rgb = NeitriAverageVertexLights(objectWorldPos);
		#endif
	#endif

	UNITY_TRANSFER_FOG(o, o.pos); // transfer fog coords
	TRANSFER_VERTEX_TO_FRAGMENT(o) // transfer shadow coords
	return o;
}





#ifdef USE_GEOMETRY_STAGE
	GeometryIn VertexProgram(VertexIn v)
	{
		GeometryIn o = (GeometryIn)0;
		CopyVertex(v, o);
		return o;
	}
#else
	FragmentIn VertexProgram(VertexIn v)
	{
		return VertexProgramProxy(v);
	}
#endif








// geometry shader used to emit extra triangles for outline
[maxvertexcount(6)]
void GeometryProgram(triangle GeometryIn v[3], inout TriangleStream<FragmentIn> tristream)
{
	{
		for (int i = 0; i < 3; i++)
		{
			FragmentIn o = VertexProgramProxy(v[i]);
			tristream.Append(o);
		}
	}

#ifdef IS_OUTLINE_SHADER
	UNITY_BRANCH
	if (_OutlineWidth > 0)
	{
		tristream.RestartStrip();

		for (int i = 2; i >= 0; i--)
		{
			float4 worldPos = mul(UNITY_MATRIX_M, float4(v[i].vertex.xyz, 1.0));
			float3 worldNormal = normalize(UnityObjectToWorldNormal(v[i].normal));
			float vertexDistanceToCamera = distance(worldPos.xyz / worldPos.w, GetCameraPosition());
			if (vertexDistanceToCamera > 10)
			{
				return;
			}

			float outlineWorldWidth = 0;
			outlineWorldWidth = vertexDistanceToCamera / max(_ScreenParams.x, _ScreenParams.y) * _OutlineWidth;
			outlineWorldWidth *= smoothstep(10, 3, vertexDistanceToCamera); // decrease outline width, the further we are

			worldPos.xyz += worldNormal * outlineWorldWidth;

			FragmentIn o = (FragmentIn)0;
			o.pos = mul(UNITY_MATRIX_VP, worldPos);
			o.uv0.xy = v[i].texcoord0; // outline should respect alpha cutout and dithering
			o.uv0.w = 1; // mark outline pixel

			tristream.Append(o);
		}
	}
#endif
}














#define GRAYSCALE_VECTOR (float3(0.3, 0.59, 0.11))
float Grayness(float3 color) 
{
	return dot(color, GRAYSCALE_VECTOR);
}

// from: https://www.shadertoy.com/view/MslGR8
// from: valve edition http://alex.vlachos.com/graphics/Alex_Vlachos_Advanced_VR_Rendering_GDC2015.pdf
// note: input in pixels (ie not normalized uv)
float3 GetScreenSpaceDither(float2 vScreenPos)
{
	// Iestyn's RGB dither (7 asm instructions) from Portal 2 X360, slightly modified for VR
	float3 vDither = dot( float2( 171.0, 231.0 ), vScreenPos.xy + _Time.z ).xxx;
	vDither.rgb = frac( vDither.rgb / float3( 103.0, 71.0, 97.0 ) ) - float3( 0.5, 0.5, 0.5 );
	return vDither.rgb;
}

// from https://www.shadertoy.com/view/Mllczf
float GetTriangularPDFNoiseDithering(float2 pos)
{
	float3 p3 = frac(float3(pos.xyx) * float3(.1031, .1030, .0973));
	p3 += dot(p3, p3.yzx + 19.19);
	float2 rand = frac((p3.xx + p3.yz) * p3.zy);
	return (rand.x + rand.y) * 0.5;
}

// Neitri's spherical harmonics average that uses higher order terms
half3 ShadeSH9Average()
{
	half3x3 mat = half3x3(
		unity_SHAr.w, length(unity_SHAr.rgb), length(unity_SHBr),
		unity_SHAg.w, length(unity_SHAg.rgb), length(unity_SHBg),
		unity_SHAb.w, length(unity_SHAb.rgb), length(unity_SHBb)
	);
	half3 res = mul(mat, half3(0.5, 0.3, 0.2));
	//res += length(unity_SHC) * 0.1;
	#ifdef UNITY_COLORSPACE_GAMMA
		res = LinearToGammaSpace(res);
	#endif
	return res;
}


// Neitri's dominant light direction approximation from spherical harmonics
float3 GetLightDirectionFromSphericalHarmonics()
{
	// humans perceive colors differently, same amount of green may appear brighter than same amount of blue, that is why we adjust contributions by grayscale vector
	return normalize(unity_SHAr.xyz * 0.3 + unity_SHAg.xyz * 0.59 + unity_SHAb.xyz * 0.11);
}


// based on ShadeSH9 from \Unity\builtin_shaders-2017.4.15f1\CGIncludes\UnityStandardUtils.cginc:
half3 NeitriShadeSH9(half4 normal)
{
	half3 realLightProbes = 0;

	//normal.w = 0; // DEBUG
	//return average; // DEBUG

	float4 SHAr = unity_SHAr;
	float4 SHAg = unity_SHAg;
	float4 SHAb = unity_SHAb;
	float4 SHBr = unity_SHBr;
	float4 SHBg = unity_SHBg;
	float4 SHBb = unity_SHBb;

	UNITY_BRANCH
	if (_BakedLightingFlatness > 0)
	{
		// issue: sometimes intensity of baked lights is too big, so lets try to normalize their color range here

		half3 thresholdsMax = lerp(1, 0.5, _BakedLightingFlatness);
		
		// BAD: this adds more colors we dont want
		//half3 thresholdsMin = lerp(0, 0.5, _BakedLightingFlatness);

		float len;
#define ADJUST(VECTOR, CHANNEL) \
		len = length(VECTOR); \
		if (len > thresholdsMax.CHANNEL) VECTOR *= thresholdsMax.CHANNEL / len;
		//else if (len < thresholdsMin.CHANNEL) VECTOR *= thresholdsMin.CHANNEL / len;

		ADJUST(SHAr, r);
		ADJUST(SHAg, g);
		ADJUST(SHAb, b);
		ADJUST(SHBr, r);
		ADJUST(SHBg, g);
		ADJUST(SHBb, b);

#undef ADJUST
	}

#define EVALUATE(VECTOR, NORMAL) \
	dot(VECTOR, NORMAL)

	// Linear (L1) + constant (L0) polynomial terms
	realLightProbes.r = EVALUATE(SHAr, normal);
	realLightProbes.g = EVALUATE(SHAg, normal);
	realLightProbes.b = EVALUATE(SHAb, normal);

	half3 x1;
	// 4 of the quadratic (L2) polynomials
	half4 vB = normal.xyzz * normal.yzzx;
	x1.r = EVALUATE(SHBr, vB);
	x1.g = EVALUATE(SHBg, vB);
	x1.b = EVALUATE(SHBb, vB);
	realLightProbes += x1;

	// Final (5th) quadratic (L2) polynomial
	//half vC = normal.x * normal.x - normal.y * normal.y;
	//realLightProbes += unity_SHC.rgb * vC;
	
#undef EVALUATE

#ifdef UNITY_COLORSPACE_GAMMA
	realLightProbes = LinearToGammaSpace(realLightProbes);
#endif

	return realLightProbes;
}



#ifdef CHANGE_DEPTH

struct FragmentOut
{
	float depth : SV_Depth;
	float4 color : SV_Target;
};
FragmentOut FragmentProgram(FragmentIn i)
{
	FragmentOut FragmentOut;
#else

float4 FragmentProgram(FragmentIn i, fixed facing : VFACE) : SV_Target
{

#endif

	UNITY_BRANCH
	if (_ShowInMirror != 0)
	{
		UNITY_BRANCH
		if (_ShowInMirror == 1) // Show only in mirror
		{
			UNITY_BRANCH
			if (!IsInMirror())
			{
				clip(-1);
			}
		}
		else // 2
		{
			// Dont show in mirror
			UNITY_BRANCH
			if (IsInMirror())
			{
				clip(-1);
			}
		}
	}


	SurfaceOut surfaceOut = (SurfaceOut)0; 
	SurfaceIn surfaceIn;
	surfaceIn.uv0 = i.uv0.xy;
	Surface(surfaceIn, surfaceOut);

	clip(surfaceOut.Alpha - _AlphaCutout);

	#ifndef IS_TRANSPARENT_SHADER
	// dithering makes sense only in opaque shader
	UNITY_BRANCH
	if (_DitheredTransparencyType != 0)
	{
		UNITY_BRANCH
		if (_DitheredTransparencyType == 1)
		{
			// Anchored to camera
			clip(surfaceOut.Alpha - GetTriangularPDFNoiseDithering(i.pos.xy));
		}
		else
		{
			// Anchored to texture coordinates
			clip(surfaceOut.Alpha - GetTriangularPDFNoiseDithering(i.uv0.xy * 5));
		}
	}
	#endif

	// outline should respect alpha cutout and dithering
#ifdef IS_OUTLINE_SHADER
	if (i.uv0.w > 0)
	{
		// this is outline pixel
		clip(facing); // clip backfaces in case cull is off or front
		return _OutlineColor;
	}
#endif

	float3 normal;

#ifdef USE_NORMAL_MAP
	UNITY_BRANCH
	if (any(surfaceOut.Normal))
	{
		float3x3 tangentSpaceToWorldSpace = float3x3(i.tangentDir, i.bitangentDir, i.normal);
		normal = normalize(mul(surfaceOut.Normal, tangentSpaceToWorldSpace));
	}
	else
#endif
	{
		// slightly dither normal over time to hide obvious normal interpolation
		//normal = normalize(i.normal + GetScreenSpaceDither(i.pos.xy) / 10.0);
		normal = normalize(i.normal);
	}

	float3 worldSpaceCameraPos = GetCameraPosition();
	float distanceToCamera = distance(i.worldPos.xyz / i.worldPos.w, worldSpaceCameraPos);


	// direction from pixel towards camera
	float3 viewDir = normalize(worldSpaceCameraPos - i.worldPos.xyz);

	// shadows, spot/point light distance calculations, light cookies
	UNITY_LIGHT_ATTENUATION(lightAttenuation, i, i.worldPos.xyz);

	fixed3 lightColor = _LightColor0.rgb;

	// direction from pixel towards light
	float3 lightDir = UnityWorldSpaceLightDir(i.worldPos.xyz); // BAD: don't normalize, stay 0 if no light direction
	lightDir = normalize(lightDir * _LightSkew);

	float3 finalRGB = 0;

	#ifdef UNITY_PASS_FORWARDBASE

		// non cookie directional light

		// environment (ambient) lighting + light probes
		//half3 averageLightProbes = ShadeSH9(half4(0, 0, 0, 1));
		//half3 averageLightProbes = ShadeSH9Average();

		half3 averageLightProbes = half3(unity_SHAr.w, unity_SHAg.w, unity_SHAb.w);
		half3 realLightProbes = ShadeSH9(half4(normal, 1));
		
		half3 lightProbes = lerp(realLightProbes, averageLightProbes, _BakedLightingFlatness);
		float3 vertexLights = lerp(i.vertexLightsReal.rgb, i.vertexLightsAverage.rgb, _BakedLightingFlatness - _ApproximateFakeLight); // BAD: #ifdef VERTEXLIGHT_ON, it's defined only in fragment shader

		finalRGB += (lightProbes + vertexLights) * surfaceOut.Albedo;

		float3 bakedLightDir = GetLightDirectionFromSphericalHarmonics();
		bakedLightDir = normalize(bakedLightDir * _LightSkew);

		fixed3 bakedLightColor = ShadeSH9(half4(bakedLightDir, 1));

		UNITY_BRANCH
		if (!any(lightDir))
		{
			// we want shadow rim to work acceptably even if there is no real light
			lightDir = bakedLightDir;
		}

		UNITY_BRANCH
		if (_ApproximateFakeLight > 0)
		{
			if (Grayness(bakedLightColor) > 0)
			{
				float NdotL = max(0, dot(normal, bakedLightDir));
				float rampNdotL = NdotL * 0.5 + 0.5; // remap -1..1 to 0..1
				float3 shadowRamp = _Ramp.Sample(Sampler_Linear_Clamp, float2(rampNdotL, rampNdotL)).rgb;

				finalRGB = lerp(finalRGB, bakedLightColor * surfaceOut.Albedo * shadowRamp, _ApproximateFakeLight);
				//finalRGB += bakedLightColor * surfaceOut.Albedo * NdotL * _ApproximateFakeLight;
			}
		}

		// Normalize light color
		// so we are always using maximumum range displays can show
		/*if (any(lightColor))
		{
			float colorMin = Grayness(averageLightProbes + i.vertexLightsAverage.rgb);
			float colorMax = Grayness(colorMin + lightColor);
			float g1 = Grayness(lightColor);
			float g2 = smoothstep(colorMin, colorMax, g1);
			lightColor *= g2 / g1;
		}*/

		// normalize base light colors, so accomulated light colors are always in range 0..1
		// because some maps have areas where only 0..0,5 lighting is used, and it looks good if we use full 0..1 range there
		/*float g1 = Grayness(lightColor); // real light
		float g2 = Grayness(bakedLightColor); // approximate baked light
		float g3 = Grayness(averageLightProbes); // ambient color
		if (g2 > g1)
		{
			bakedLightColor /= 1 - (g3 + g1); // ambient and real light is applied
			float NdotL = max(0, dot(normal, bakedLightDir));
			diffuseLightRGB += bakedLightColor * NdotL;
		}
		else
		{
			lightColor /= 1 - g3; // only ambient is applied
		}*/

		// BAD: we cant tell where is complete darkness
		// issue: if we are in complete dark we dont want to artifiaclly lighten up shadowed parts
		// bool isInCompleteDark = unityLightAttenuation < 0.05 && Grayness(diffuseLightRGB) < 0.01;

	#else
		
		// all spot lights, all point lights, cookie directional lights

	#endif

	float3 halfDir = normalize(lightDir + viewDir);
	float NdotL = dot(normal, lightDir);
	float NdotV = dot(normal, viewDir);
	float NdotH = dot(normal, halfDir);

	{
		// Specular
		UNITY_BRANCH
		if (_Glossiness > 0)
		{
			float gloss = _Glossiness;
			float specPow = exp2(gloss * 10.0);
			float specularReflection = pow(max(NdotH, 0), specPow) * (specPow + 10) / (10 * UNITY_PI) * gloss;
			// specular light does not enter surface, it is reflected off surface so it does not get any surface color
			finalRGB += lightAttenuation * lightColor * specularReflection;
		}

		// Diffuse
		{
			float rampNdotL = NdotL * 0.5 + 0.5; // remap -1..1 to 0..1
			float3 shadowRamp = _Ramp.Sample(Sampler_Linear_Clamp, float2(rampNdotL, rampNdotL)).rgb;

			UNITY_BRANCH
			if (_Shadow < 1)
			{
				float3 maximumLitRamp = _Ramp.Sample(Sampler_Linear_Clamp, float2(1, 1)).rgb;
				shadowRamp = lerp(maximumLitRamp, shadowRamp, _Shadow);
			}

			float3 diffuseColor;
			#ifdef UNITY_PASS_FORWARDBASE
				diffuseColor = lightColor * shadowRamp * surfaceOut.Albedo;
				diffuseColor = lerp(_ShadowColor, diffuseColor, lightAttenuation);
			#else
				// issue: sometimes delta pass light is too bright, lets make sure its not too bright
				diffuseColor = lightColor;
				float g = Grayness(diffuseColor);
				UNITY_BRANCH
				if (g > 1) diffuseColor /= g;
				diffuseColor = diffuseColor * shadowRamp * surfaceOut.Albedo * lightAttenuation;
			#endif
			finalRGB += diffuseColor;
		}
	}


	// can use following defines DIRECTIONAL || POINT || SPOT || DIRECTIONAL_COOKIE || POINT_COOKIE || SPOT_COOKIE


	// Matcap
	#ifdef UNITY_PASS_FORWARDBASE
		UNITY_BRANCH
		if (_MatcapWeight > 0)
		{
			float2 matcapUv;

			UNITY_BRANCH
			if (_MatcapAnchor == 0)
			{
				// Anchored to direction to camera
				const float3 worldUp = float3(0, 1, 0);
				float3 right = normalize(cross(viewDir, worldUp));
				float3 up = -normalize(cross(viewDir, right));
				matcapUv = float2(dot(normal, right), dot(normal, up)) * 0.5 + 0.5;
			}
			else
			{
				UNITY_BRANCH
				if (_MatcapAnchor == 1)
				{
					// Anchored to camera rotation
					float3 up = GetCameraUp();
					float3 right = GetCameraRight();
					matcapUv = float2(dot(normal, right), dot(normal, up)) * 0.5 + 0.5;
				}
				else
				{
					// Anchored to world up
					const float3 up = float3(0, 1, 0);
					float3 adjustedNormal = normalize(float3(normal.x, 0, normal.z));
					float3 adjustedViewDir = normalize(float3(viewDir.x, 0, viewDir.z));
					matcapUv = float2(1 - dot(adjustedNormal, adjustedViewDir), dot(normal, up)) * 0.5 + 0.5;
				}
			}


			float3 matcap = _Matcap.Sample(Sampler_Linear_Clamp, matcapUv).rgb * _MatcapTint.rgb * _MatcapTint.a;


			UNITY_BRANCH
			if (_MatcapType == 1)
			{
				// Add to final color
				finalRGB += matcap * _MatcapWeight;
			}
			else
			{
				UNITY_BRANCH
				if (_MatcapType == 2)
				{
					// Multiply final color
					finalRGB *= lerp(1, matcap, _MatcapWeight);
				}
				else // 3
				{
					// Multiply by light color then add to final color
					matcap *= lightColor;
					finalRGB += matcap * _MatcapWeight;
				}
			}
		}
	#endif


	// Shadow rim
	{
		float3 shadowRim = surfaceOut.Albedo * lightColor * _ShadowRim;

		float3 cameraForward = GetCameraForward();
		float dot1 = dot(cameraForward, normal);
		float dot2 = dot(cameraForward, lightDir);
		float w = (1 - abs(dot1)) * saturate(dot2);
		finalRGB += shadowRim * w * lightAttenuation;
	}

	// Emission
	#ifdef UNITY_PASS_FORWARDBASE
		UNITY_BRANCH
		if (_EmissionType != 0)
		{
			if (_EmissionType == 1)
			{
				// Glow always
				finalRGB += surfaceOut.Emission;
			}
			else
			{
				// Glow only in darkness
				fixed weight = lightAttenuation * dot(averageLightProbes + i.vertexLightsAverage.rgb + lightColor, fixed3(1, 1, 1));
				weight = 1 - clamp(0, 1, weight);
				finalRGB += surfaceOut.Emission * weight;
			}
		}
	#else
	#endif

	fixed4 finalRGBA = fixed4(finalRGB, surfaceOut.Alpha);

	#ifdef UNITY_PASS_FORWARDBASE
		UNITY_APPLY_FOG(i.fogCoord, finalRGBA);
	#else
		UNITY_APPLY_FOG_COLOR(i.fogCoord, finalRGBA, half4(0,0,0,0)); // fog towards black in additive pass
	#endif

	#ifdef CHANGE_DEPTH
	FragmentOut.color = finalRGBA;
	return FragmentOut;
	#else
	return finalRGBA;
	#endif

}


























#ifdef UNITY_STEREO_INSTANCING_ENABLED
#define UNITY_STANDARD_USE_STEREO_SHADOW_OUTPUT_STRUCT 1
#endif

struct VertexShadowCasterIn
{
	float4 vertex : POSITION;
	float3 normal : NORMAL;
	float2 uv0 : TEXCOORD0;
	UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct VertexShadowCasterOut
{
	V2F_SHADOW_CASTER_NOPOS
	float2 uv0 : TEXCOORD1;
};

#ifdef UNITY_STANDARD_USE_STEREO_SHADOW_OUTPUT_STRUCT
struct VertexStereoShadowCasterOut
{
	UNITY_VERTEX_OUTPUT_STEREO
};
#endif

void VertexProgramShadowCaster (VertexShadowCasterIn v
	, out float4 opos : SV_POSITION
	, out VertexShadowCasterOut o
	#ifdef UNITY_STANDARD_USE_STEREO_SHADOW_OUTPUT_STRUCT
	, out VertexStereoShadowCasterOut os
	#endif
)
{
	UNITY_SETUP_INSTANCE_ID(v);
	TRANSFER_SHADOW_CASTER_NOPOS(o,opos)
	o.uv0 = v.uv0;
	#ifdef UNITY_STANDARD_USE_STEREO_SHADOW_OUTPUT_STRUCT
		UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(os);
	#endif
}

half4 FragmentProgramShadowCaster(float4 vpos : SV_POSITION, VertexShadowCasterOut i) : SV_Target
{
	SurfaceOut surfaceOut = (SurfaceOut)0;
	SurfaceIn surfaceIn;
	surfaceIn.uv0 = i.uv0.xy;
	Surface(surfaceIn, surfaceOut);

	clip(surfaceOut.Alpha - _AlphaCutout);

	UNITY_BRANCH
	if (_DitheredTransparencyType != 0)
	{
		UNITY_BRANCH
		if (_DitheredTransparencyType == 1)
		{
			// Anchored to camera
			clip(surfaceOut.Alpha - GetTriangularPDFNoiseDithering(vpos.xy));
		}
		else
		{
			// Anchored to texture coordinates
			clip(surfaceOut.Alpha - GetTriangularPDFNoiseDithering(i.uv0.xy * 5));
		}
	}

	SHADOW_CASTER_FRAGMENT(i)
}
