// by Neitri, free of charge, free to redistribute
// downloaded from https://github.com/netri/Neitri-Unity-Shaders

// Some ideas are from:
// Cubed's https://github.com/cubedparadox/Cubeds-Unity-Shaders
// Xiexe's https://github.com/Xiexe/Xiexes-Unity-Shaders



#include "UnityCG.cginc"

#include "AutoLight.cginc"
#include "Lighting.cginc"

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





sampler2D _MainTex; float4 _MainTex_ST;
fixed4 _Color;
float _Glossiness; // name from Unity's standard

sampler2D _EmissionMap; float4 _EmissionMap_ST;
fixed4 _EmissionColor;

#ifdef USE_NORMAL_MAP
sampler2D _BumpMap; float4 _BumpMap_ST;
float _BumpScale;
#endif

float3 _ShadowColor;
float _BakedLightingFlatness;
int _ApproximateFakeLight;

float3 _RampColorAdjustment;
sampler2D _Ramp; // name from Xiexe's
float _ShadingRampStretch;

int _MatcapType;
float3 _MatcapColorAdjustment;
int _MatcapAnchor;
sampler2D _Matcap;

#ifdef IS_OUTLINE_SHADER
float4 _OutlineColor;
float _OutlineWidth;
#endif

float _AlphaCutout;
int _DitheredTransparencyType;


// DEBUG
int _DebugInt1;
int _DebugInt2;



struct VertexInput {
	float4 vertex : POSITION;
	float3 normal : NORMAL;
	float4 tangent : TANGENT;
	float2 texcoord0 : TEXCOORD0;
};

struct GeometryInput {
	float4 vertex : SV_POSITION;
	float3 normal : TEXCOORD0;
	float4 tangent : TEXCOORD1;
	float2 texcoord0 : TEXCOORD2;
};

void CopyVertexInput(in VertexInput from, out GeometryInput to)
{
	to.vertex = from.vertex;
	to.normal = from.normal;
	to.tangent = from.tangent;
	to.texcoord0 = from.texcoord0;
}


struct FragmentInput {
	float4 pos : SV_POSITION; // must be called pos, because TRANSFER_VERTEX_TO_FRAGMENT expects it
	float4 uv0 : TEXCOORD0; // w == 1 marks outline pixel
	float4 worldPos : TEXCOORD1;
	float3 normal : TEXCOORD2;
	LIGHTING_COORDS(3,4) // shadow coords
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





float3 getCameraPosition()
{
#ifdef USING_STEREO_MATRICES
	//return lerp(unity_StereoWorldSpaceCameraPos[0], unity_StereoWorldSpaceCameraPos[1], 0.5);
	return unity_StereoWorldSpaceCameraPos[0];
#else
	return _WorldSpaceCameraPos;
#endif
}

float3 getCameraForward()
{
#if UNITY_SINGLE_PASS_STEREO
	float3 p1 = mul(unity_StereoCameraToWorld[0], float4(0, 0, 1, 0));
#else
	float3 p1 = mul(unity_CameraToWorld, float4(0, 0, 1, 0));
#endif
	return normalize(p1);
}

float3 getCameraRight()
{
#if UNITY_SINGLE_PASS_STEREO
	float3 p1 = mul(unity_StereoCameraToWorld[0], float4(1, 0, 0, 0));
#else
	float3 p1 = mul(unity_CameraToWorld, float4(1, 0, 0, 0));
#endif
	return normalize(p1);
}

float3 getCameraUp()
{
#if UNITY_SINGLE_PASS_STEREO
	float3 p1 = mul(unity_StereoCameraToWorld[0], float4(0, 1, 0, 0));
#else
	float3 p1 = mul(unity_CameraToWorld, float4(0, 1, 0, 0));
#endif
	return normalize(p1);
}






#ifdef USE_GEOMETRY_STAGE
FragmentInput vertReal(in GeometryInput v) 
#else
FragmentInput vertReal(in VertexInput v)
#endif
{
	FragmentInput o = (FragmentInput)0;
	o.uv0.xy = v.texcoord0;
	o.normal = UnityObjectToWorldNormal(v.normal);
	#ifdef USE_TANGENT_BITANGENT
		o.tangentDir = normalize(mul(unity_ObjectToWorld, float4(v.tangent.xyz, 0.0)).xyz);
		o.bitangentDir = normalize(cross(o.normal, o.tangentDir) * v.tangent.w);
	#endif
	o.worldPos = mul(unity_ObjectToWorld, float4(v.vertex.xyz, 1.0));
	o.pos = mul(UNITY_MATRIX_VP, o.worldPos);
	o.modelPos = v.vertex;

	
#ifdef _MESH_DEFORMATION_ON
	// TODO, broken now
	// inspiration: https://gumroad.com/naelstrof Contact Shader for VRChat, https://www.youtube.com/watch?v=JAIbjUHZyNg
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

	float3 lightColor = _LightColor0.rgb;
	UNITY_TRANSFER_FOG(o,o.pos); // transfer fog coords
	TRANSFER_VERTEX_TO_FRAGMENT(o) // transfer shadow coords
	return o;
}





#ifdef USE_GEOMETRY_STAGE
	GeometryInput vert(VertexInput v)
	{
		GeometryInput o = (GeometryInput)0;
		CopyVertexInput(v, o);
		return o;
	}
#else
	FragmentInput vert(VertexInput v)
	{
		return vertReal(v);
	}
#endif









[maxvertexcount(6)]
void geom(triangle GeometryInput v[3], inout TriangleStream<FragmentInput> tristream)
{
	{
		for (int i = 0; i < 3; i++)
		{
			FragmentInput o = vertReal(v[i]);
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
			float outlineWorldWidth = 0;
			float4 worldPos = mul(UNITY_MATRIX_M, float4(v[i].vertex.xyz, 1.0));
			float3 worldNormal = normalize(UnityObjectToWorldNormal(v[i].normal));
			float vertexDistanceToCamera = distance(worldPos.xyz / worldPos.w, getCameraPosition());
			outlineWorldWidth = vertexDistanceToCamera / max(_ScreenParams.x, _ScreenParams.y) * _OutlineWidth;
			if (vertexDistanceToCamera > 10)
			{
				return;
			}

			outlineWorldWidth *= smoothstep(10, 3, vertexDistanceToCamera); // decrease outline width, the further we are

			worldPos.xyz += worldNormal * outlineWorldWidth;

			FragmentInput o = (FragmentInput)0;
			o.pos = mul(UNITY_MATRIX_VP, worldPos);
			o.uv0.xy = v[i].texcoord0; // outline should respect alpha cutout and dithering
			o.uv0.w = 1; // mark outline pixel

			tristream.Append(o);
		}
	}
#endif
}














#define GRAYSCALE_VECTOR (float3(0.3, 0.59, 0.11))
float grayness(float3 color) 
{
	return dot(color, GRAYSCALE_VECTOR);
}

// from: https://www.shadertoy.com/view/MslGR8
// note: valve edition
//	   from http://alex.vlachos.com/graphics/Alex_Vlachos_Advanced_VR_Rendering_GDC2015.pdf
// note: input in pixels (ie not normalized uv)
float3 getScreenSpaceDither( float2 vScreenPos )
{
	// Iestyn's RGB dither (7 asm instructions) from Portal 2 X360, slightly modified for VR
	float3 vDither = dot( float2( 171.0, 231.0 ), vScreenPos.xy + _Time.z ).xxx;
	vDither.rgb = frac( vDither.rgb / float3( 103.0, 71.0, 97.0 ) ) - float3( 0.5, 0.5, 0.5 );
	return vDither.rgb;
}

// from: https://www.shadertoy.com/view/Mllczf
float triangularPDFNoiseDithering(float2 pos)
{
	float3 p3 = frac(float3(pos.xyx) * float3(.1031, .1030, .0973));
	p3 += dot(p3, p3.yzx+19.19);
	float2 rand = frac((p3.xx+p3.yz)*p3.zy);
	return (rand.x + rand.y) * 0.5;
}

// unsure if better variant that uses higher order terms
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


// dominant light direction approximation from spherical harmonics
float3 getLightDirectionFromSphericalHarmonics()
{
	// Xiexe's
	//half3 reverseShadeSH9Light = ShadeSH9(float4(-normal,1));
	//half3 noAmbientShadeSH9Light = (realLightProbes - reverseShadeSH9Light)/2;
	//return -normalize(noAmbientShadeSH9Light * 0.5 + 0.533);

	// Neitri's
	// humans perceive colors differently, same amount of green may appear brighter than same amount of blue, that is why we adjust contributions by grayscale vector
	return normalize(unity_SHAr.xyz * 0.3 + unity_SHAg.xyz * 0.59 + unity_SHAb.xyz * 0.11);
}


// based on ShadeSH9 from \Unity\builtin_shaders-2017.4.15f1\CGIncludes\UnityStandardUtils.cginc:
void NeitriShadeSH9(half4 normal, out half3 realLightProbes, out half3 averageLightProbes)
{
	averageLightProbes = half3(unity_SHAr.w, unity_SHAg.w, unity_SHAb.w);


	//realLightProbes = ShadeSH9(normal); return;

	realLightProbes = 0;
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
}



#ifdef OUTPUT_DEPTH

struct FragOut
{
	float depth : SV_Depth;
	float4 color : SV_Target;
};
FragOut frag(FragmentInput i)
{
	FragOut fragOut;
#else

float4 frag(FragmentInput i, fixed facing : VFACE) : SV_Target
{

#endif

	float4 mainTexture = tex2D(_MainTex, TRANSFORM_TEX(i.uv0, _MainTex));

	#ifdef IS_TRANSPARENT_SHADER
	// because people expect color alpha to work only on transparent shaders
	mainTexture *= _Color;
	#else
	mainTexture.rgb *= _Color.rgb;
	#endif

	clip(mainTexture.a - _AlphaCutout);

	#ifndef IS_TRANSPARENT_SHADER
	// dithering makes sense only in opaque shader
	UNITY_BRANCH
	if (_DitheredTransparencyType != 0)
	{
		UNITY_BRANCH
		if (_DitheredTransparencyType == 1)
		{
			// Anchored to camera
			clip(mainTexture.a - triangularPDFNoiseDithering(i.pos.xy));
		}
		else
		{
			// Anchored to texture coordinates
			clip(mainTexture.a - triangularPDFNoiseDithering(i.uv0.xy * 5));
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



	float3 normal = i.normal;

#ifdef USE_NORMAL_MAP
	UNITY_BRANCH
	if (_BumpScale != 0)
	{
		float3x3 tangentSpaceToWorldSpace = float3x3(i.tangentDir, i.bitangentDir, normal);
		float3 normalTangentSpace = UnpackNormal(tex2D(_BumpMap, TRANSFORM_TEX(i.uv0, _BumpMap)));
		normalTangentSpace = lerp(float3(0, 0, 1), normalTangentSpace, _BumpScale);
		normal = normalize(mul(normalTangentSpace, tangentSpaceToWorldSpace));
	}
#endif

	float3 worldSpaceCameraPos = getCameraPosition();

	// slightly dither normal over time to hide obvious normal interpolation
	//normal = normalize(normal + getScreenSpaceDither(i.pos.xy) / 10.0);
	normal = normalize(normal);

	// direction from pixel towards camera
	float3 viewDir = normalize(worldSpaceCameraPos - i.worldPos.xyz);

	// direction from pixel towards light
	float3 lightDir = UnityWorldSpaceLightDir(i.worldPos.xyz); // BAD: don't normalize, stay 0 if no light direction

	// shadows, spot/point light distance calculations, light cookies
	UNITY_LIGHT_ATTENUATION(unityLightAttenuation, i, i.worldPos.xyz);
	float3 lightAttenuation; // assigned later

	fixed3 lightColor = _LightColor0.rgb;

	// prevent bloom if light color is over 1
	// BAD: some maps intentonally use lights over 1, then compensate it with tonemapping
	//fixed lightColorMax = max(lightColor.x, max(lightColor.y, lightColor.z));
	//if(lightColorMax > 1) lightColor /= lightColorMax;

	float3 diffuseLightRGB = 0;

	#ifdef UNITY_PASS_FORWARDBASE

		// non cookie directional light

		// environment (ambient) lighting + light probes
		//half3 averageLightProbes = ShadeSH9(half4(0, 0, 0, 1));
		//half3 averageLightProbes = ShadeSH9Average();
		//half3 realLightProbes = ShadeSH9(half4(normal, 1));

		half3 averageLightProbes;
		half3 realLightProbes;
		NeitriShadeSH9(half4(normal, 1), realLightProbes, averageLightProbes);

		half3 lightProbes = lerp(realLightProbes, averageLightProbes, _BakedLightingFlatness);
		float3 vertexLights = lerp(i.vertexLightsReal.rgb, i.vertexLightsAverage.rgb, _BakedLightingFlatness);

		// vertex lights
		// BAD: #ifdef VERTEXLIGHT_ON, it's defined only in fragment shader
		diffuseLightRGB += lightProbes + vertexLights;
		
		// BAD: we cant tell where is complete darkness
		// issue: if we are in complete dark we dont want to artifiaclly lighten up shadowed parts
		// bool isInCompleteDark = unityLightAttenuation < 0.05 && grayness(diffuseLightRGB) < 0.01;

		lightAttenuation = lerp(_ShadowColor, 1, unityLightAttenuation);

		float3 averageLightColor = (averageLightProbes + i.vertexLightsAverage) * 0.7f;

		UNITY_BRANCH
		if (_ApproximateFakeLight > 0)
		{
			UNITY_BRANCH
			if (!any(lightDir))
			{
				lightDir = getLightDirectionFromSphericalHarmonics();
			}
		}

		UNITY_BRANCH
		if (!any(lightColor))
		{
			lightColor = averageLightColor;
		}

	#else
		
		// all spot lights, all point lights, cookie directional lights

		// don't adjust shadows at all for additional lights
		lightAttenuation = unityLightAttenuation;

	#endif

	float3 finalRGB = 0;

	lightDir = normalize(lightDir);
	float3 halfDir = normalize(lightDir + viewDir);
	float NdotL = dot(normal, lightDir);
	float NdotV = dot(normal, viewDir);
	float NdotH = dot(normal, halfDir);
	
	UNITY_BRANCH
	if (any(lightDir) && any(lightColor))
	{
		// specular
		{
			float gloss = _Glossiness;
			float specPow = exp2(gloss * 10.0);
			float specularReflection = pow(max(NdotH, 0), specPow) * (specPow + 10) / (10 * UNITY_PI) * gloss;
			// specular light does not enter surface, it is reflected off surface so it does not get any surface color
			finalRGB += lightAttenuation * lightColor * specularReflection;
		}

		// diffuse
		{
			#ifdef UNITY_PASS_FORWARDBASE
			#else
				// issue: sometimes delta pass light is too bright and there is no unlit color to compensate it with
				// lets make sure its not too bright
				float g = grayness(lightColor);
				UNITY_BRANCH
				if (g > 1) lightColor /= g;
			#endif

			float rampNdotL = NdotL * 0.5 + 0.5; // remap -1..1 to 0..1
			rampNdotL = lerp(_ShadingRampStretch, 1, rampNdotL); // remap 0..1 to _ShadingRampStretch..1
			float3 shadowRamp = tex2D(_Ramp, float2(rampNdotL, rampNdotL)).rgb * _RampColorAdjustment;
			//shadowRamp = max(0, NdotL + 0.1); // DEBUG, phong
			diffuseLightRGB += 
				shadowRamp *
				lightColor*
				lightAttenuation;
		}
	}

	// diffuse light goes into surface and exits with surface color (mainTexture.rgb is surface color)
	finalRGB += diffuseLightRGB * mainTexture.rgb;

	#ifdef UNITY_PASS_FORWARDBASE
	#else
	#endif
	// can use following defines DIRECTIONAL || POINT || SPOT || DIRECTIONAL_COOKIE || POINT_COOKIE || SPOT_COOKIE


	// prevent bloom, final failsafe
	// BAD: some maps intentonally use lights over 1, then compensate it with tonemapping
	//finalRGB = saturate(finalRGB);

	// matcap
	UNITY_BRANCH
	if (_MatcapType != 0)
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
				float3 up = getCameraUp();
				float3 right = getCameraRight();
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

		float3 matcap = tex2D(_Matcap, matcapUv).rgb * _MatcapColorAdjustment;


		UNITY_BRANCH
		if (_MatcapType == 1)
		{
			// Add to final color
			finalRGB += matcap;
		}
		else
		{
			UNITY_BRANCH
			if (_MatcapType == 2)
			{
				// Multiply final color
				finalRGB *= matcap;
			}
			else
			{
				// Multiply by light color then add to final color
				matcap *= lightColor;
				finalRGB += matcap;
			}
		}


		// GOOD: old _TYPE_SKIN keyword, view based shading, adds MMD like feel
		// it just looks super good, adds more depth just where its needed
		// finalRGB *= lerp(1, max(0, dot(viewDir, normal)), 0.2);
		// now done with matcap, I faced issue where these two curves are not the same: cos(x), 1-abs(cos(x+PI/2)), from 0 to PI/2
		// because above uses dot with viewDir, whereas matcap uses dot with right/up vector, I countered it by creating radial matcap with following values
		// Table[N[round(100*(cos(-(acos((1-((100-x)/100*PI/2)))-PI/2))))],{x,40,100,10}]

		//return float4(matcap, 1); // DEBUG
	}

	#ifdef UNITY_PASS_FORWARDBASE
		UNITY_BRANCH
		if (any(_EmissionColor))
		{
			fixed4 emissive = tex2D(_EmissionMap, TRANSFORM_TEX(i.uv0.xy, _EmissionMap)) * _EmissionColor;
			finalRGB += emissive.rgb;
			/*
			TODO: Eimission type,  Normal,0,Show only in darkness,1
			float emissiveWeight = grayness(emissive.rgb) - grayness(finalRGB);
			// BAD: emissiveWeight = smoothstep(-1, 1, emissiveWeight); causes darker color on not emissive pixel 
			emissiveWeight = smoothstep(0, 1, emissiveWeight);
			//finalRGB = lerp(finalRGB, emissive.rgb, emissive);
			finalRGB = lerp(finalRGB, emissive.rgb, emissive);*/
		}
	#else
	#endif

	fixed4 finalRGBA = fixed4(finalRGB, mainTexture.a);

	#ifdef UNITY_PASS_FORWARDBASE
		UNITY_APPLY_FOG(i.fogCoord, finalRGBA);
	#else
		UNITY_APPLY_FOG_COLOR(i.fogCoord, finalRGBA, half4(0,0,0,0)); // fog towards black in additive pass
	#endif

	#ifdef OUTPUT_DEPTH
	fragOut.color = finalRGBA;
	return fragOut;
	#else
	return finalRGBA;
	#endif

}


























#ifdef UNITY_STEREO_INSTANCING_ENABLED
#define UNITY_STANDARD_USE_STEREO_SHADOW_OUTPUT_STRUCT 1
#endif

struct VertexInputShadowCaster
{
	float4 vertex : POSITION;
	float3 normal : NORMAL;
	float2 uv0 : TEXCOORD0;
	UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct VertexOutputShadowCaster
{
	V2F_SHADOW_CASTER_NOPOS
	float2 tex : TEXCOORD1;
};

#ifdef UNITY_STANDARD_USE_STEREO_SHADOW_OUTPUT_STRUCT
struct VertexOutputStereoShadowCaster
{
	UNITY_VERTEX_OUTPUT_STEREO
};
#endif

void vertShadowCaster (VertexInputShadowCaster v
	, out float4 opos : SV_POSITION
	, out VertexOutputShadowCaster o
	#ifdef UNITY_STANDARD_USE_STEREO_SHADOW_OUTPUT_STRUCT
	, out VertexOutputStereoShadowCaster os
	#endif
)
{
	UNITY_SETUP_INSTANCE_ID(v);
	TRANSFER_SHADOW_CASTER_NOPOS(o,opos)
	o.tex = TRANSFORM_TEX(v.uv0, _MainTex);
	#ifdef UNITY_STANDARD_USE_STEREO_SHADOW_OUTPUT_STRUCT
		UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(os);
	#endif
}

half4 fragShadowCaster(float4 vpos : SV_POSITION, VertexOutputShadowCaster i) : SV_Target
{
	half alpha = tex2D(_MainTex, TRANSFORM_TEX(i.tex, _MainTex)).a;

	#ifdef IS_TRANSPARENT_SHADER
	// because people expect color alpha to work only on transparent shaders
	alpha *= _Color.a;
	#endif

	clip(alpha - _AlphaCutout);

	#ifndef IS_TRANSPARENT_SHADER
	// dithering makes sense only in opaque shader
	UNITY_BRANCH
	if (_DitheredTransparencyType != 0)
	{
		UNITY_BRANCH
		if (_DitheredTransparencyType == 1)
		{
			// Anchored to camera
			clip(alpha - triangularPDFNoiseDithering(vpos.xy));
		}
		else
		{
			// Anchored to texture coordinates
			clip(alpha - triangularPDFNoiseDithering(i.tex.xy * 5));
		}
	}
	#endif

	SHADOW_CASTER_FRAGMENT(i)
}
