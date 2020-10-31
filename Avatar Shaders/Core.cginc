// by Neitri, free of charge, free to redistribute
// downloaded from https://github.com/netri/Neitri-Unity-Shaders

// Some ideas are from:
// Cubed's https://github.com/cubedparadox/Cubeds-Unity-Shaders
// Xiexe's https://github.com/Xiexe/Xiexes-Unity-Shaders
// uses Disney's BRDF https://raw.githubusercontent.com/wdas/brdf/master/src/brdfs/disney.brdf


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



int _EmissionType;

float3 _ShadowColor;
float3 _ShadowRim;

float _BakedLightingFlatness;
float _ApproximateFakeLight;

float _Shadow; // name & idea from Cubed's
sampler2D _Ramp; // name from Xiexe's

int _MatcapType;
float4 _MatcapTint; // name from Xiexe's
float _MatcapWeight;
int _MatcapAnchor;
sampler2D _Matcap;

#ifdef IS_OUTLINE_SHADER
float4 _OutlineColor;
float _OutlineWidth;
#endif

float _AlphaCutout;
int _ShowInMirror;
int _IgnoreMirrorClipPlane;
float _ContactDeformRange;
float _DitheredTransparency;
float3 _LightSkew; // name & idea from Silent's

UNITY_DECLARE_DEPTH_TEXTURE(_CameraDepthTexture);



// DEBUG
int _DebugInt1;
int _DebugInt2;
float _DebugFloat1;




#define PI 3.14159265358979323846

float sqr(float x) { return x * x; }

float InverseLerp(float min, float max, float x) { return saturate(min + x * (max - min)); }

float SchlickFresnel(float u)
{
	float m = saturate(1 - u);
	float m2 = m * m;
	return m2 * m2 * m; // pow(m,5)
}

float GTR1(float NdotH, float a)
{
	if (a >= 1) return 1 / PI;
	float a2 = a * a;
	float t = 1 + (a2 - 1) * NdotH * NdotH;
	return (a2 - 1) / (PI * log(a2) * t);
}

float GTR2(float NdotH, float a)
{
	float a2 = a * a;
	float t = 1 + (a2 - 1) * NdotH * NdotH;
	return a2 / (PI * t * t);
}

float GTR2_aniso(float NdotH, float HdotX, float HdotY, float ax, float ay)
{
	return 1 / (PI * ax * ay * sqr(sqr(HdotX / ax) + sqr(HdotY / ay) + NdotH * NdotH));
}

float smithG_GGX(float NdotV, float alphaG)
{
	float a = alphaG * alphaG;
	float b = NdotV * NdotV;
	return 1 / (NdotV + sqrt(a + b - a * b));
}

float smithG_GGX_aniso(float NdotV, float VdotX, float VdotY, float ax, float ay)
{
	return 1 / (NdotV + sqrt(sqr(VdotX * ax) + sqr(VdotY * ay) + sqr(NdotV)));
}















// ensure we sample with linar clamp sampler settings regardless of texture import settings
// useful for ramp or matcap textures to prevent user errors
// https://docs.unity3d.com/Manual/SL-SamplerStates.html
SamplerState Sampler_Linear_Clamp;


struct VertexIn {
	float4 vertex : POSITION;
	float3 normal : NORMAL;
	float3 tangent : TANGENT;
	float2 texcoord0 : TEXCOORD0;
	float4 color : COLOR;
};

struct GeometryIn {
	float4 vertex : SV_POSITION;
	float3 normal : TEXCOORD0;
	float3 tangent : TEXCOORD1;
	float2 texcoord0 : TEXCOORD2;
	float4 color : TEXCOORD3;
};

void CopyVertex(in VertexIn from, out GeometryIn to)
{
	to.vertex = from.vertex;
	to.normal = from.normal;
	to.tangent = from.tangent;
	to.texcoord0 = from.texcoord0;
	to.color = from.color;
}


struct FragmentIn {
	float4 pos : SV_POSITION; // must be called pos, because TRANSFER_VERTEX_TO_FRAGMENT expects pos
	float4 uv0 : TEXCOORD0; // w == 1 marks outline pixel
	float4 worldPos : TEXCOORD1;
	float3 normal : TEXCOORD2;
	LIGHTING_COORDS(3, 4) // shadow coords
	UNITY_FOG_COORDS(5) 
	float4 color : TEXCOORD6;
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
	return unity_StereoWorldSpaceCameraPos[0];
#else
	return _WorldSpaceCameraPos;
#endif
}

float3 GetCameraRight()
{
#if UNITY_SINGLE_PASS_STEREO
	return unity_StereoCameraToWorld[0]._m00_m10_m20;
#else
	return unity_CameraToWorld._m00_m10_m20;
#endif
}

float3 GetCameraUp()
{
#if UNITY_SINGLE_PASS_STEREO
	return unity_StereoCameraToWorld[0]._m01_m11_m21;
#else
	return unity_CameraToWorld._m01_m11_m21;
#endif
}

float3 GetCameraForward()
{
#if UNITY_SINGLE_PASS_STEREO
	return unity_StereoCameraToWorld[0]._m02_m12_m22;
#else
	return unity_CameraToWorld._m02_m12_m22;
#endif
}

half3 DistanceFromAABB(half3 p, half3 aabbMin, half3 aabbMax)
{
	return max(max(p - aabbMax, aabbMin - p), half3(0.0, 0.0, 0.0));
}


// Merlin's mirror detection
inline bool IsInMirror()
{
	return UNITY_MATRIX_P._31 != 0.f || UNITY_MATRIX_P._32 != 0.f;
}

// Calculates depth differene between vertex and worlPos and current value in depth buffer
float CalculateDepthDifference(float3 worldPos)
{
#if defined(UNITY_SINGLE_PASS_STEREO)
	// special case for single pass VR rendering, we want "depthDifference" to be the same in both eyes
	// se we calculate it for both eyes and take average
	// could take left eye "depthDifference" for both eyes if you want to squeeze out extra performance
	{
		float4 vertex0 = mul(unity_StereoMatrixVP[0], worldPos);
		float4 vertex1 = mul(unity_StereoMatrixVP[1], worldPos);

		// ComputeScreenPos
		float4 screenPos0 = ComputeNonStereoScreenPos(vertex0);
		float4 scaleOffset0 = unity_StereoScaleOffset[0];
		screenPos0.xy = screenPos0.xy * scaleOffset0.xy + scaleOffset0.zw * screenPos0.w;
		float sceneDepth0 = LinearEyeDepth(tex2Dlod(_CameraDepthTexture, float4(screenPos0.xy / vertex0.w, 0, 0)));
		if (abs(sceneDepth0 - GammaToLinearSpaceExact(0.5)) < 0.0025) return 0; // no depth texture
		float vertexDepth0 = -mul(unity_StereoMatrixV[0], worldPos).z;

		float4 screenPos1 = ComputeNonStereoScreenPos(vertex1);
		float4 scaleOffset1 = unity_StereoScaleOffset[1];
		screenPos1.xy = screenPos1.xy * scaleOffset1.xy + scaleOffset1.zw * screenPos1.w;
		float sceneDepth1 = LinearEyeDepth(tex2Dlod(_CameraDepthTexture, float4(screenPos1.xy / vertex1.w, 0, 0)));
		float vertexDepth1 = -mul(unity_StereoMatrixV[1], worldPos).z;

		return ((vertexDepth0 - sceneDepth0) + (vertexDepth1 - sceneDepth1)) * 0.5;
	}
#else
	{
		float4 vertex = mul(UNITY_MATRIX_VP, worldPos);
		float4 screenPos = ComputeScreenPos(vertex);
		float sceneDepth = LinearEyeDepth(tex2Dlod(_CameraDepthTexture, float4(screenPos.xy / vertex.w, 0, 0)));
		if (abs(sceneDepth - GammaToLinearSpaceExact(0.5)) < 0.0025) return 0; // no depth texture
		float vertexDepth = -mul(UNITY_MATRIX_V, worldPos).z;
		return vertexDepth - sceneDepth;
	}
#endif
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
	o.color = v.color;

	// attempts to simulate deformation when you touch skin/hair
	// moves mesh avay from current value in depth buffer along vertex normal
	UNITY_BRANCH
	if (_ContactDeformRange > 0)
	{
		float depthDifference = CalculateDepthDifference(o.worldPos);
		if (abs(depthDifference) > 0)
		{
			//depthDifference += 0.02; // simulate finger thickness, people usually touch with their hands, but we get depth of back side of hand, we want front
			const float range = _ContactDeformRange;
			depthDifference = abs(depthDifference) < range ? (depthDifference > 0 ? depthDifference - range : range + depthDifference) : 0;
			depthDifference *= saturate(dot(o.normal, -GetCameraForward()));
			depthDifference *= _ContactDeformRange;
			o.worldPos.xyz += o.normal * depthDifference;
		}
	}

	o.pos = mul(UNITY_MATRIX_VP, o.worldPos);


	UNITY_BRANCH
	if (_IgnoreMirrorClipPlane && IsInMirror())
	{
		// https://docs.microsoft.com/en-us/windows/win32/direct3d9/viewports-and-clipping
		o.pos.z = min(o.pos.z, o.pos.w);
	}
	
	// vertex lights are a cheap way to calculate 4 lights without shadows at once
	// Unity renders first few lights as pixel lights with shadows in base/delta pass
	// next 4 are calculated using vertex lights
	// next are added to light probes
	// you can force light to be in vertex lights by setting Render Mode: Not Important
	#ifdef UNITY_PASS_FORWARDBASE
		#ifdef VERTEXLIGHT_ON // defined only in frgament shader
			// Approximated illumination from non-important point lights
			float3 objectWorldPos = mul(unity_ObjectToWorld, float4(0, 0, 0, 1));
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
#ifdef IS_OUTLINE_SHADER
[maxvertexcount(6)]
#else
[maxvertexcount(3)]
#endif
void GeometryProgram(triangle GeometryIn v[3], inout TriangleStream<FragmentIn> tristream)
{
	// passthru data
	{
		[unroll]
		for (int i = 0; i < 3; i++)
		{
			FragmentIn o = VertexProgramProxy(v[i]);
			tristream.Append(o);
		}
	}

#ifdef IS_OUTLINE_SHADER
	// add outline triangles
	UNITY_BRANCH
	if (_OutlineWidth > 0)
	{
		tristream.RestartStrip();

		[unroll]
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

sampler3D _DitherMaskLOD;
float GetDithering(float2 pos, float alpha)
{
	//return alpha - GetTriangularPDFNoiseDithering(pos);
	return tex3D(_DitherMaskLOD, float3(pos.xy * 0.25, alpha * 0.9375)).a - 0.01;
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


	SurfaceIn surfaceIn;
	surfaceIn.uv0 = i.uv0.xy;
	surfaceIn.worldPos = i.worldPos;
	surfaceIn.screenPos = i.pos;
	surfaceIn.color = i.color;

	SurfaceOut surfaceOut = (SurfaceOut)0;
	surfaceOut.Occlusion = 1;

	Surface(surfaceIn, surfaceOut);

	clip(surfaceOut.Alpha - _AlphaCutout);

	#ifndef IS_TRANSPARENT_SHADER
	// dithering makes sense only in opaque shader
	UNITY_BRANCH
	if (_DitheredTransparency > 0)
	{
		// alpha 1 is fully visible, 0 is fully invisible
		float adjustedAlpha = saturate((surfaceOut.Alpha - _AlphaCutout) / (1 - _AlphaCutout)); // remap _AlphaCutout..1 to 0..1
		adjustedAlpha = saturate(adjustedAlpha / _DitheredTransparency); // remap 0.._DitheredTransparency to 0..1
		clip(GetDithering(i.pos.xy, adjustedAlpha)); // Anchored to camera
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
	
	// slightly dither normal to hide obvious normal interpolation
	i.normal += GetScreenSpaceDither(i.pos.xy) * 0.01;

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
		normal = normalize(i.normal);
	}

	float3 worldSpaceCameraPos = GetCameraPosition();

	// direction from pixel towards camera
	float3 viewDir = normalize(worldSpaceCameraPos - i.worldPos.xyz);	
	
	// shadows, spot/point light distance calculations, light cookies
	UNITY_LIGHT_ATTENUATION(lightAttenuation, i, i.worldPos.xyz);

	/// ACIIL's fix: lightAtten is random in scenes without directional lights.
	if (!any(_LightColor0.rgb)) 
	{
		lightAttenuation = 1;
	}

	fixed3 lightColor = _LightColor0.rgb;

	// direction from pixel towards light
	// BAD: don't normalize, stay 0 if no light direction so we can detect it in other lighting code
	float3 lightDir = UnityWorldSpaceLightDir(i.worldPos.xyz);
	float lighrDirLength = length(lightDir);
	lightDir = lighrDirLength > 0 ? (lightDir * _LightSkew) / lighrDirLength : 0;

	float3 finalRGB = 0;

	#ifdef UNITY_PASS_FORWARDBASE
	
		float3 occlusionRamp;
		{
			float occlusionAdjusted = surfaceOut.Occlusion * 0.5 + 0.5;
			occlusionRamp = tex2D(_Ramp, float2(occlusionAdjusted, occlusionAdjusted)).rgb;
			UNITY_BRANCH
			if (_Shadow < 1)
			{
				occlusionRamp = lerp(1, occlusionRamp, _Shadow);
			}
		}

		// non cookie directional light

		// environment (ambient) lighting + light probes
		half3 averageLightProbes = half3(unity_SHAr.w, unity_SHAg.w, unity_SHAb.w);
		half3 realLightProbes = ShadeSH9(half4(normal, 1));
		
		half3 lightProbes = lerp(realLightProbes, averageLightProbes, _BakedLightingFlatness);
		float3 vertexLights = lerp(i.vertexLightsReal.rgb, i.vertexLightsAverage.rgb, _BakedLightingFlatness); // BAD: don't use #ifdef VERTEXLIGHT_ON, it's defined only in fragment shader
		float ambientWeight = 1;

		// light color and light dir falls back to baked light color and light dir in case there is no realtime directional light
		UNITY_BRANCH
		if (!any(lightColor) && !any(lightDir))
		{
			ambientWeight -= _ApproximateFakeLight;
			// integral/volume of unit sphere is 4*PI
			// integral of clamped cosine over unit hemisphere is PI
			// that means fake light intensity has to be 4 times bigger to compensate for ambient light, however 4 looks too bright
			lightDir = normalize(GetLightDirectionFromSphericalHarmonics() * _LightSkew);
			lightColor = 2 * _ApproximateFakeLight * (averageLightProbes + i.vertexLightsAverage.rgb);
		}

		float3 ambientRGB = ambientWeight * (lightProbes + vertexLights) * surfaceOut.Albedo * occlusionRamp;
		finalRGB += ambientRGB;
		//return float4(finalRGB, 0); // DEBUG

		// BAD: we cant tell where is complete darkness
		// issue: if we are in complete dark we dont want to artifiaclly lighten up shadowed parts
		// bool isInCompleteDark = unityLightAttenuation < 0.05 && Grayness(diffuseLightRGB) < 0.01;

	#else
		
		// all spot lights, all point lights, cookie directional lights

	#endif

	#ifdef UNITY_PASS_FORWARDBASE
	UNITY_BRANCH
	if (_Shadow < 1)
	{
		// issue: sometimes entire play area is in shadow and there is no ambient light
		lightAttenuation = lerp(1, lightAttenuation, _Shadow);
	}
	#endif


	float3 L = lightDir;
	float3 V = viewDir;
	float3 N = normal;
	float3 X = i.tangentDir;
	float3 Y = i.bitangentDir;
	float3 H = normalize(L + V);

	float NdotL = dot(N, L);
	float NdotV = dot(N, V);
	float NdotH = dot(N, H);
	float LdotH = dot(L, H);

	//NdotL = NdotL * 0.5 + 0.5;
	//NdotH = NdotH * 0.5 + 0.5;

	{
		float diffuseWeight = 0;
		float3 specularWeight = 0;
		float reflectionProbeWeight = 0;

		// Disney's BRDF, calculate diffuse and specular weight with crazy physicaly based math based on real life measurements
		{
			// Disney's BRDF
			// https://raw.githubusercontent.com/wdas/brdf/master/src/brdfs/disney.brdf
			// 
			// Copyright Disney Enterprises, Inc.All rights reserved.
			//
			// Licensed under the Apache License, Version 2.0 (the "License");
			// you may not use this file except in compliance with the License
			// and the following modification to it : Section 6 Trademarks.
			// deleted and replaced with :
			//
			// 6. Trademarks.This License does not grant permission to use the
			// trade names, trademarks, service marks, or product names of the
			// Licensor and its affiliates, except as required for reproducing
			// the content of the NOTICE file.
			//
			// You may obtain a copy of the License at
			// http://www.apache.org/licenses/LICENSE-2.0

			float3 baseColor = surfaceOut.Albedo;
			float metallic = surfaceOut.Metallic * 0.5;
			float subsurface = 0;
			float specular = 0.5;
			float roughness = 1 - surfaceOut.Smoothness;
			float specularTint = 0;
			float anisotropic = surfaceOut.Anisotropic;
			float sheen = 0;
			float sheenTint = 0.5;
			float clearcoat = 0;
			float clearcoatGloss = 1;

			float3 Cdlin = baseColor;
			float Cdlum = .3 * Cdlin.r + .6 * Cdlin.g + .1 * Cdlin, b; // luminance approx.
			float3 Ctint = Cdlum > 0 ? Cdlin / Cdlum : float3(1, 1, 1); // normalize lum. to isolate hue+sat
			float3 Cspec0 = lerp(specular * .08 * lerp(float3(1, 1, 1), Ctint, specularTint), Cdlin, metallic);
			float3 Csheen = lerp(float3(1, 1, 1), Ctint, sheenTint);

			// Diffuse fresnel - go from 1 at normal incidence to .5 at grazing
			// and mix in diffuse retro-reflection based on roughness
			float FL = SchlickFresnel(NdotL);
			float FV = SchlickFresnel(NdotV);
			float Fd90 = 0.5 + 2 * LdotH * LdotH * roughness;
			float Fd = lerp(1.0, Fd90, FL) * lerp(1.0, Fd90, FV);

			// Based on Hanrahan-Krueger brdf approximation of isotropic bssrdf
			// 1.25 scale is used to (roughly) preserve albedo
			// Fss90 used to "flatten" retroreflection based on roughness
			float Fss90 = LdotH * LdotH * roughness;
			float Fss = lerp(1.0, Fss90, FL) * lerp(1.0, Fss90, FV);
			float ss = 1.25 * (Fss * (1 / (NdotL + NdotV) - .5) + .5);

			//diffuseWeight = lerp(Fd, ss, subsurface) * NdotL;
			diffuseWeight = Fd * NdotL;

			// TODO: not correct
			//reflectionProbeWeight = 1 - (diffuseWeight * (1 - metallic));
			reflectionProbeWeight = surfaceOut.Smoothness *  metallic;

			if (NdotL > 0 && NdotV > 0)
			{
				// specular

				float Ds; // amount of microfacets facing camera
				float Gs; // geometry self shadowing
				// anisotropic
				UNITY_BRANCH
				if (anisotropic != 0)
				{
					float aspect = sqrt(1 - anisotropic * .9);
					float ax = max(.001, sqr(roughness) / aspect);
					float ay = max(.001, sqr(roughness) * aspect);
					Ds = GTR2_aniso(NdotH, dot(H, X), dot(H, Y), ax, ay); // amount of microfacets facing camera
					// geometry self shadowing
					Gs = smithG_GGX_aniso(NdotL, dot(L, X), dot(L, Y), ax, ay);
					Gs *= smithG_GGX_aniso(NdotV, dot(V, X), dot(V, Y), ax, ay);
				}
				else
				{
					// not anisotropic
					Ds = GTR2(NdotH, roughness * roughness); // amount of microfacets facing camera
					Gs = smithG_GGX(NdotV, roughness); // geometry self shadowing
				}

				float FH = SchlickFresnel(LdotH);
				float3 Fs = lerp(Cspec0, float3(1, 1, 1), FH);

				// sheen
				//float3 Fsheen = FH * sheen * Csheen;

				// clearcoat (ior = 1.5 -> F0 = 0.04)
				//float Dr = GTR1(NdotH, lerp(.1, .001, clearcoatGloss));
				//float Fr = lerp(.04, 1.0, FH);
				//float Gr = smithG_GGX(NdotL, .25) * smithG_GGX(NdotV, .25);

				specularWeight = (Gs * Fs * Ds) * PI * NdotL;
			}
		}

		// specular
		{
			finalRGB += specularWeight * lightColor * lightAttenuation;

			#ifdef UNITY_PASS_FORWARDBASE
				float specCubeMip = lerp(10, 0, surfaceOut.Smoothness); // 10 is blurry, 0 is sharp
				finalRGB += reflectionProbeWeight * DecodeHDR(UNITY_SAMPLE_TEXCUBE_LOD(unity_SpecCube0, reflect(-viewDir, normal), specCubeMip), unity_SpecCube0_HDR);
			#endif
		}

		// diffuse
		{
			float rampU = diffuseWeight * 0.5 + 0.5; // remap -1..1 to 0..1
			rampU *= 1 - surfaceOut.Metallic;
			float3 diffuseColor;
			#ifdef UNITY_PASS_FORWARDBASE
				rampU *= lightAttenuation;
				// issue: sometimes world has no ambient lighting to show occlusion on, lets show little of it on first direct light
				rampU *= lerp(0.5, 1, surfaceOut.Occlusion);
				float3 shadowRamp = tex2D(_Ramp, float2(rampU, rampU)).rgb;
				UNITY_BRANCH
				if (_Shadow < 1) shadowRamp = lerp(1, shadowRamp, _Shadow);
				diffuseColor = lightColor * shadowRamp * surfaceOut.Albedo;
			#else
				// issue: sometimes delta pass light is too bright, lets make sure its not too bright
				diffuseColor = lightColor;
				float g = Grayness(diffuseColor);
				UNITY_BRANCH
				if (g > 1) diffuseColor /= g;
				float3 shadowRamp = tex2D(_Ramp, float2(rampU, rampU)).rgb;
				diffuseColor = diffuseColor * shadowRamp * surfaceOut.Albedo * lightAttenuation;
				//return float4(diffuseColor * lightAttenuation* diffuseWeight, 1);
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

			float3 matcap = tex2D(_Matcap, matcapUv).rgb * _MatcapTint.rgb * _MatcapTint.a;

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
	UNITY_BRANCH
	if (any(lightColor) && any(_ShadowRim))
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
				fixed weight = Grayness(ambientRGB);
				weight = 1 - clamp(0, 1, weight);
				finalRGB += surfaceOut.Emission * weight;
			}
		}
	#else
	#endif

	#ifdef IS_TRANSPARENT_SHADER
		fixed4 finalRGBA = fixed4(finalRGB, surfaceOut.Alpha);
	#else
		fixed4 finalRGBA = fixed4(finalRGB, 1);
	#endif

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
	TRANSFER_SHADOW_CASTER_NOPOS(o, opos)
	o.uv0 = v.uv0;
	#ifdef UNITY_STANDARD_USE_STEREO_SHADOW_OUTPUT_STRUCT
		UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(os);
	#endif

	UNITY_BRANCH
	if (_ContactDeformRange > 0)
	{
		// make depth seems as if mesh is further away from mesh
		// so camera depth texture does not collide with surface contact deformation
		opos.z -= _ContactDeformRange * 0.1 * opos.w;
	}
}

half4 FragmentProgramShadowCaster(float4 vpos : SV_POSITION, VertexShadowCasterOut i) : SV_Target
{
	SurfaceOut surfaceOut = (SurfaceOut)0;
	SurfaceIn surfaceIn;
	surfaceIn.uv0 = i.uv0.xy;
	Surface(surfaceIn, surfaceOut);

	clip(surfaceOut.Alpha - _AlphaCutout);

	UNITY_BRANCH
	if (_DitheredTransparency > 0)
	{
		// alpha 1 is fully visible, 0 is fully invisible
		float adjustedAlpha = saturate((surfaceOut.Alpha - _AlphaCutout) / (1 - _AlphaCutout)); // remap _AlphaCutout..1 to 0..1
		adjustedAlpha = saturate(adjustedAlpha / _DitheredTransparency); // remap 0.._DitheredTransparency to 0..1
		clip(GetDithering(vpos.xy, adjustedAlpha)); // Anchored to camera
	}

	SHADOW_CASTER_FRAGMENT(i)
}
