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

struct VertexInput {
	float3 vertex : POSITION;
	float3 normal : NORMAL;
	float4 color : COLOR;
	float4 tangent : TANGENT;
	float2 texcoord0 : TEXCOORD0;
};
struct VertexOutput {
	float4 pos : SV_POSITION;
	float4 color : COLOR;
	float4 uv0 : TEXCOORD0; // TODO: uv.w == isOutline, 0 for no, 1 for yes
	float4 posWorld : TEXCOORD1;
	float3 normal : TEXCOORD2;
	LIGHTING_COORDS(3,4) // shadow coords
	UNITY_FOG_COORDS(5) 
	#ifdef UNITY_PASS_FORWARDBASE
		#if defined(LIGHTMAP_ON) || defined(UNITY_SHOULD_SAMPLE_SH)
			float4 vertexLightsReal : TEXCOORD7;
			float4 vertexLightsAverage : TEXCOORD8;
		#endif
	#endif
	#ifdef USE_TANGENT_BITANGENT
		float3 tangentDir : TEXCOORD9;
		float3 bitangentDir : TEXCOORD10;
	#endif
};


// based off Shade4PointLights from "\Unity\builtin_shaders-5.6.5f1\CGIncludes\UnityCG.cginc"
float3 AverageShade4PointLights (
	float4 lightPosX, float4 lightPosY, float4 lightPosZ,
	float3 lightColor0, float3 lightColor1, float3 lightColor2, float3 lightColor3,
	float4 lightAttenSq,
	float3 pos)
{
	// BAD: does not take into account distance to lights
	//return (lightColor0 + lightColor1 + lightColor2 + lightColor3) * 0.25;

	// to light vectors
	float4 toLightX = lightPosX - pos.x;
	float4 toLightY = lightPosY - pos.y;
	float4 toLightZ = lightPosZ - pos.z;
	// squared lengths
	float4 lengthSq = 0;
	lengthSq += toLightX * toLightX;
	lengthSq += toLightY * toLightY;
	lengthSq += toLightZ * toLightZ;
	// don't produce NaNs if some vertex position overlaps with the light
	lengthSq = max(lengthSq, 0.000001);
	// attenuation
	float4 atten = 1.0 / (1.0 + lengthSq * lightAttenSq);
	float4 diff = atten;
	// final color
	float3 col = 0;
	col += lightColor0 * diff.x;
	col += lightColor1 * diff.y;
	col += lightColor2 * diff.z;
	col += lightColor3 * diff.w;
	return col;
}

#ifdef _MESH_DEFORMATION_ON
	UNITY_DECLARE_DEPTH_TEXTURE(_CameraDepthTexture);
#endif


VertexOutput vert (VertexInput v) 
{
	VertexOutput o = (VertexOutput)0;
	o.uv0.xy = v.texcoord0;
	o.color = v.color;
	o.normal = UnityObjectToWorldNormal(v.normal);
	#ifdef USE_TANGENT_BITANGENT
		o.tangentDir = normalize(mul(unity_ObjectToWorld, float4(v.tangent.xyz, 0.0)).xyz);
		o.bitangentDir = normalize(cross(o.normal, o.tangentDir) * v.tangent.w);
	#endif
	o.posWorld = mul(unity_ObjectToWorld, float4(v.vertex, 1.0));
	o.pos = mul(UNITY_MATRIX_VP, o.posWorld);


	
#ifdef _MESH_DEFORMATION_ON

	float4 projPos = ComputeScreenPos(o.pos);
	float4 pcoord = float4(projPos.xy / projPos.w, 0, 0);
	float sceneDepth = LinearEyeDepth (tex2Dlod(_CameraDepthTexture, pcoord));
	float vertexDepth = mul(UNITY_MATRIX_V, o.posWorld).z;

	float value = (vertexDepth - sceneDepth) / _ProjectionParams.z * 0.1;
	value = value * (abs(value) > 0.1);
	v.vertex += v.normal * value;
	
	o.normal.z += value;
	o.normal.z = normalize(o.normal.z);

	o.posWorld = mul(unity_ObjectToWorld, float4(v.vertex, 1.0));
	o.pos = mul(UNITY_MATRIX_VP, o.posWorld);

#endif

	float3 posModel = mul(unity_ObjectToWorld, float4(0, 0, 0, 1));

	
	// vertex lights are a cheap way to calculate 4 lights without shadows at once	
	// Unity renders first few lights as pixel lights with shadows in base/delta pass
	// next 4 are calculated using vertex lights
	// next are added to light probes
	// you can force light to be in vertex lights by setting Render Mode: Not Important
	#ifdef UNITY_PASS_FORWARDBASE
		#ifdef VERTEXLIGHT_ON
			// Approximated illumination from non-important point lights
			o.vertexLightsReal.rgb = Shade4PointLights (
				unity_4LightPosX0, unity_4LightPosY0, unity_4LightPosZ0,
				unity_LightColor[0].rgb, unity_LightColor[1].rgb, unity_LightColor[2].rgb, unity_LightColor[3].rgb,
				unity_4LightAtten0, o.posWorld, o.normal);
			o.vertexLightsAverage.rgb = AverageShade4PointLights (
				unity_4LightPosX0, unity_4LightPosY0, unity_4LightPosZ0,
				unity_LightColor[0].rgb, unity_LightColor[1].rgb, unity_LightColor[2].rgb, unity_LightColor[3].rgb,
				unity_4LightAtten0, posModel);		
		#endif
	#endif

	float3 lightColor = _LightColor0.rgb;
	UNITY_TRANSFER_FOG(o,o.pos); // transfer fog coords
	TRANSFER_VERTEX_TO_FRAGMENT(o) // transfer shadow coords
	return o;
}

#if defined(_RAYMARCHER_TYPE_SPHERES) || defined(_RAYMARCHER_TYPE_HEARTS)
	#define OUTPUT_DEPTH
	#define ENABLE_RAYMARCHER
	#ifdef _RAYMARCHER_TYPE_SPHERES
		#define RAYMARCHER_DISTANCE_FIELD_FUNCTION distanceMap_spheres
	#endif	
	#ifdef _RAYMARCHER_TYPE_HEARTS
		#define RAYMARCHER_DISTANCE_FIELD_FUNCTION distanceMap_hearts
	#endif
	float _Raymarcher_Scale;
	#include "RayMarcher.cginc"
#endif	




sampler2D _MainTex; float4 _MainTex_ST;
fixed4 _Color;

sampler2D _EmissionMap; float4 _EmissionMap_ST;
fixed4 _EmissionColor;



#ifdef USE_NORMAL_MAP
	sampler2D _BumpMap; float4 _BumpMap_ST;
	float _BumpScale;
#endif

sampler2D _Ramp; // name from Xiexe's
float _Shadow; // name from Cubed's
float _DirectionShadingSmoothness;
float _LightCastedShadowDarkness;
float _Glossiness; // name from Unity's standard
float _BakedLightingFlatness;


#ifdef _COLOR_OVER_TIME_ON
	sampler2D _ColorOverTime_Ramp;
	float _ColorOverTime_Speed;
#endif

sampler3D _DitherMaskLOD;

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

float3 getCameraPosition()
{
	#ifdef USING_STEREO_MATRICES
		return lerp(unity_StereoWorldSpaceCameraPos[0], unity_StereoWorldSpaceCameraPos[1], 0.5);
	#endif
	return _WorldSpaceCameraPos;
}

// from poiyomi's shader
float3 getCameraForward()
{
	#if UNITY_SINGLE_PASS_STEREO
		float3 p1 = mul(unity_StereoCameraToWorld[0], float4(0, 0, 1, 1));
		float3 p2 = mul(unity_StereoCameraToWorld[0], float4(0, 0, 0, 1));
	#else
		float3 p1 = mul(unity_CameraToWorld, float4(0, 0, 1, 1));
		float3 p2 = mul(unity_CameraToWorld, float4(0, 0, 0, 1));
	#endif
	return normalize(p2 - p1);
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

#ifdef OUTPUT_DEPTH
struct FragOut
{
	float depth : SV_Depth;
	float4 color : SV_Target;
};
FragOut frag(VertexOutput i)
{
	FragOut fragOut;
#else
float4 frag(VertexOutput i) : SV_Target 
{
#endif

	float4 mainTexture = tex2D(_MainTex,TRANSFORM_TEX(i.uv0, _MainTex));

	#ifdef IS_TRANSPARENT_SHADER
	// because people expect color alpha to work only on transparent shaders
	mainTexture *= _Color;
	#else
	mainTexture.rgb *= _Color.rgb;
	#endif

	#ifdef _COLOR_OVER_TIME_ON
		float4 adjustColor = tex2Dlod(_ColorOverTime_Ramp, float4(_Time.x * _ColorOverTime_Speed, _Time.x * _ColorOverTime_Speed, 0, 0));
		#ifdef IS_TRANSPARENT_SHADER
			mainTexture *= adjustColor;
		#else
			mainTexture.rgb *= adjustColor.rgb;
		#endif
	#endif

	#ifdef ENABLE_RAYMARCHER
		float raymarchedScreenDepth;
		raymarch(i.posWorld.xyz, mainTexture.rgb, raymarchedScreenDepth);
		#ifdef OUTPUT_DEPTH
			float realDepthWeight = i.color.r;
			fragOut.depth = lerp(raymarchedScreenDepth, i.pos.z, realDepthWeight);
		#endif
	#endif


	#ifdef _DITHERED_TRANSPARENCY_ON
		clip(mainTexture.a - triangularPDFNoiseDithering(i.pos.xy));
	#else
		#ifdef IS_TRANSPARENT_SHADER
			// cutout support, discard current pixel if alpha is less than 0.05
			clip(mainTexture.a - 0.05);
		#endif
	#endif



	float3 normal = i.normal;

#ifdef USE_NORMAL_MAP
	UNITY_BRANCH
	if (_BumpScale != 0)
	{
		float3x3 tangentToWorld = float3x3(i.tangentDir, i.bitangentDir, normal);
		float3 normalTangentSpace = UnpackNormal(tex2D(_BumpMap, TRANSFORM_TEX(i.uv0, _BumpMap)));
		normalTangentSpace = lerp(float3(0, 0, 1), normalTangentSpace, _BumpScale);
		normal = normalize(mul(normalTangentSpace, tangentToWorld));
	}
#endif

	float3 worldSpaceCameraPos = getCameraPosition();

	// slightly dither normal over time to hide obvious normal interpolation
	normal = normalize(normal + getScreenSpaceDither(i.pos.xy) / 50.0);
	//normal = normalize(normal);

	// direction from pixel towards camera
	float3 viewDir = normalize(worldSpaceCameraPos - i.posWorld.xyz);

	// direction from pixel towards light
	float3 lightDir = UnityWorldSpaceLightDir(i.posWorld.xyz);

	// shadows, spot/point light distance calculations, light cookies
	UNITY_LIGHT_ATTENUATION(lightAttenuation, i, i.posWorld.xyz);
	lightAttenuation = lerp(1, lightAttenuation, _LightCastedShadowDarkness);

	fixed3 specularLightColor = _LightColor0.rgb;
	fixed3 diffuseLightColor = _LightColor0.rgb;

	// prevent bloom if light color is over 1
	// BAD: some maps intentonally use lights over 1, then compensate it with tonemapping
	//fixed lightColorMax = max(lightColor.x, max(lightColor.y, lightColor.z));
	//if(lightColorMax > 1) lightColor /= lightColorMax;

	float3 diffuseLightRGB = 0;

	#ifdef UNITY_PASS_FORWARDBASE
		// non cookie directional light, or no lights at all (just ambient, light probes and vertex lights)
		
		// TODO: proxy volume support, see: ShadeSHPerPixel

		// ambient color, skybox, light probes are baked in spherical harmonics in ShadeSH9
		//half3 averageLightProbes = ShadeSH9(half4(0, 0, 0, 1));
		//half3 averageLightProbes = (ShadeSH9(half4(1, 0, 0, 1))+ShadeSH9(half4(0, 1, 0, 1))+ShadeSH9(half4(0, 0, 1, 1))+ShadeSH9(half4(-1, 0, 0, 1))+ShadeSH9(half4(0, -1, 0, 1))+ShadeSH9(half4(0, 0, -1, 1))) / 6.0;
		//half3 averageLightProbes = ShadeSH9Average();

		half3 lightProbes = ShadeSH9(half4(lerp(normal, half3(0, 0, 0), _BakedLightingFlatness), 1));
		//half3 lightProbes = lerp(ShadeSH9(half4(normal, 1)), ShadeSH9(half4(0, 0, 0, 1)), _BakedLightingFlatness);

		float3 vertexLights = lerp(i.vertexLightsReal.rgb, i.vertexLightsAverage.rgb, _BakedLightingFlatness);

		diffuseLightRGB += vertexLights + lightProbes;

		// DEBUG
		//return float4(1, 0, 0, 1);
		//return float4(lightProbes, 1);

		// normally unlit color is black, but we want to show some color there to be closer to Cubed's toon
		// so we we averge all ambient like sources that are used
		float3 unlit = lightProbes + i.vertexLightsAverage + _LightColor0.rgb;
		// then adjust the grayness so it's equal to (lightColor grayness - _Shadow)
		float unlitTargetGrayness = max(0, grayness(_LightColor0.rgb) - _Shadow);
		unlit *= unlitTargetGrayness / max(0.001, grayness(unlit));

		
		UNITY_BRANCH
		if (!any(specularLightColor))
		{
			specularLightColor = (1 + lightProbes + i.vertexLightsAverage) * 0.3f;
		}

		UNITY_BRANCH
		if (!any(lightDir))
		{
			lightDir = getLightDirectionFromSphericalHarmonics();
		}

	#else
		
		// all spot lights, all point lights, cookie directional lights

	#endif

	fixed3 finalRGB = fixed3(0, 0, 0);
	
	lightDir = normalize(lightDir);
	float3 halfDir = normalize(lightDir + viewDir);

	float NdotL = dot(normal, lightDir);
	float NdotV = dot(normal, viewDir);
	float NdotH = saturate(dot(normal, halfDir));

	UNITY_BRANCH
	if (any(lightDir)) 
	{
		// specular
		UNITY_BRANCH
		if (any(specularLightColor))
		{
			float gloss = _Glossiness;
			float specPow = exp2(gloss * 10.0);
			float specularReflection = pow(max(NdotH, 0), specPow) * (specPow + 10) / (10 * UNITY_PI) * gloss;
			finalRGB += lightAttenuation * specularLightColor * specularReflection;
		}

		// diffuse
		UNITY_BRANCH
		if (any(diffuseLightColor))
		{
			float rampNdotL = NdotL * 0.5 + 0.5;
			float3 shadowRamp = tex2D( _Ramp, float2(rampNdotL, rampNdotL)).rgb;

			float3 diffuseColor = lightAttenuation * diffuseLightColor * shadowRamp;
			#ifdef UNITY_PASS_FORWARDBASE
			#else
				// issue: sometimes delta pass light is too bright and there is no unlit color to compensate it with
				// lets make sure its not too bright
				float g = grayness(diffuseColor);
				if (g > 1) diffuseColor /= g;
			#endif

			diffuseLightRGB += diffuseColor;
		}
	}

	finalRGB += diffuseLightRGB * mainTexture.rgb;
	
	#ifdef UNITY_PASS_FORWARDBASE
	#else
	#endif
	// can use following defines DIRECTIONAL || POINT || SPOT || DIRECTIONAL_COOKIE || POINT_COOKIE || SPOT_COOKIE


	// prevent bloom, final failsafe
	// BAD: some maps intentonally use lights over 1, then compensate it with tonemapping
	//finalRGB = saturate(finalRGB);

	#ifdef UNITY_PASS_FORWARDBASE
		fixed4 emissive = tex2D(_EmissionMap,TRANSFORM_TEX(i.uv0.xy, _EmissionMap)) * _EmissionColor;
		float emissiveWeight = smoothstep(-1, 1, grayness(emissive.rgb) - grayness(finalRGB));
		finalRGB = lerp(finalRGB, emissive.rgb, emissiveWeight);
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

half4 fragShadowCaster (UNITY_POSITION(vpos)
	, VertexOutputShadowCaster i
) : SV_Target
{
	half alpha = tex2D(_MainTex, i.tex).a * _Color.a;
	clip(alpha - 0.05);
	#if defined(IS_TRANSPARENT_SHADER) || defined(_DITHERED_TRANSPARENCY_ON)
		clip(alpha - triangularPDFNoiseDithering(vpos.xy));
	#endif

	SHADOW_CASTER_FRAGMENT(i)
}
