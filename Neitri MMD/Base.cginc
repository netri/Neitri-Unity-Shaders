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
	float4 vertex : POSITION;
	float3 normal : NORMAL;
	float4 color : COLOR;
	float4 tangent : TANGENT;
	float2 texcoord0 : TEXCOORD0;
};

struct GeometryInput {
	float4 vertex : SV_POSITION;
	float3 normal : TEXCOORD0;
	float4 color : TEXCOORD1;
	float4 tangent : TEXCOORD2;
	float2 texcoord0 : TEXCOORD3;
};

void CopyVertexInput(in VertexInput from, out GeometryInput to)
{
	to.vertex = from.vertex;
	to.normal = from.normal;
	to.color = from.color;
	to.tangent = from.tangent;
	to.texcoord0 = from.texcoord0;
}


struct FragmentInput {
	float4 pos : SV_POSITION; // must be called pos, because TRANSFER_VERTEX_TO_FRAGMENT expects it
	float4 color : COLOR;
	float4 uv0 : TEXCOORD0;
	float4 worldPos : TEXCOORD1;
	float3 normal : TEXCOORD2;
	LIGHTING_COORDS(3,4) // shadow coords
	UNITY_FOG_COORDS(5) 
	float3 modelPos : TEXCOORD6;
	#ifdef UNITY_PASS_FORWARDBASE
		#ifdef VERTEXLIGHT_ON
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






#ifdef IS_OUTLINE_SHADER
	#define USE_GEOMETRY_STAGE
#endif


#ifdef _MESH_DEFORMATION_ON
	UNITY_DECLARE_DEPTH_TEXTURE(_CameraDepthTexture);
#endif






#ifdef USE_GEOMETRY_STAGE
FragmentInput vertReal(in GeometryInput v) 
#else
FragmentInput vertReal(in VertexInput v)
#endif
{
	FragmentInput o = (FragmentInput)0;
	o.uv0.xy = v.texcoord0;
	o.color = v.color;
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
		#ifdef VERTEXLIGHT_ON
			// Approximated illumination from non-important point lights
			o.vertexLightsReal.rgb = Shade4PointLights (
				unity_4LightPosX0, unity_4LightPosY0, unity_4LightPosZ0,
				unity_LightColor[0].rgb, unity_LightColor[1].rgb, unity_LightColor[2].rgb, unity_LightColor[3].rgb,
				unity_4LightAtten0, o.worldPos, o.normal);
			o.vertexLightsAverage.rgb = AverageShade4PointLights (
				unity_4LightPosX0, unity_4LightPosY0, unity_4LightPosZ0,
				unity_LightColor[0].rgb, unity_LightColor[1].rgb, unity_LightColor[2].rgb, unity_LightColor[3].rgb,
				unity_4LightAtten0, objectWorldPos);
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
	tristream.RestartStrip();
	{
		for (int i = 2; i >= 0; i--)
		{
			/*
			o.clipPos = UnityObjectToClipPos(v.vertex);
			o.clipPos /= o.clipPos.w;
			float4 extrudedClipPos = UnityObjectToClipPos(v.vertex + float4(v.normal * 0.001, 0));
			extrudedClipPos /= extrudedClipPos.w;
			o.clipSpaceNormal = float4(normalize(extrudedClipPos.xy - o.clipPos.xy), 0.01 * (o.clipPos.z - extrudedClipPos.z), 0);
			o.clipSpaceNormal.xy *= _OutlineSize * 2 / _ScreenParams.xy;

			*/
			float outlineWorldWidth = 0;


			float4 worldPos = mul(UNITY_MATRIX_M, float4(v[i].vertex.xyz, 1.0));

			float3 worldNormal = normalize(UnityObjectToWorldNormal(v[i].normal));
			outlineWorldWidth = distance(worldPos.xyz / worldPos.w, getCameraPosition()) / max(_ScreenParams.x, _ScreenParams.y) * 2;

			outlineWorldWidth = min(outlineWorldWidth, 0.05);

			//float d = distance(worldPos.xyz / worldPos.w, getCameraPosition());
			//d = (d - _ProjectionParams.y) / (_ProjectionParams.z - _ProjectionParams.y);
			//d = length(mul(UNITY_MATRIX_V, float3(d, 0, 0)));
			/*float3 worldVectorOnePixel = float3(rcp(_ScreenParams.x), rcp(_ScreenParams.y), d);
			worldVectorOnePixel = mul(UNITY_MATRIX_I_V, worldVectorOnePixel);
			float onePixelWorldLength = length(worldVectorOnePixel);
			worldPos.xyz += worldNormal * onePixelWorldLength;*/
			
			
			worldPos.xyz += worldNormal * outlineWorldWidth;

			FragmentInput o = (FragmentInput)0;
			o.color = float4(0, 0, 0, 5);
			o.pos = mul(UNITY_MATRIX_VP, worldPos);

			tristream.Append(o);
		}
	}
#endif
}
















int _Raymarcher_Type;
float _Raymarcher_Scale;
#include "RayMarcher.cginc"


sampler2D _MainTex; float4 _MainTex_ST;
fixed4 _Color;
float _Glossiness; // name from Unity's standard

sampler2D _EmissionMap; float4 _EmissionMap_ST;
fixed4 _EmissionColor;

#ifdef USE_NORMAL_MAP
	sampler2D _BumpMap; float4 _BumpMap_ST;
	float _BumpScale;
#endif

float _Shadow; // name from Cubed's
float3 _ShadowColor;
float _BakedLightingFlatness;
int _UseFakeLight;

float3 _RampColorAdjustment;
sampler2D _Ramp; // name from Xiexe's
float _ShadingRampStretch;

int _MatcapType;
float3 _MatcapColorAdjustment;
int _MatcapAnchor;
sampler2D _Matcap;

int _UseColorOverTime;
sampler2D _ColorOverTime_Ramp;
float _ColorOverTime_Speed;

int _UseDitheredTransparency;



// DEBUG
int _DebugInt1;
int _DebugInt2;


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
float4 frag(FragmentInput i) : SV_Target 
{
#endif

	#ifdef IS_OUTLINE_SHADER
	if (i.color.a > 4.5)
	{
		// this is outline fragment
		return float4(0, 0, 0, 1);
	}
	#endif


	float4 mainTexture = tex2D(_MainTex,TRANSFORM_TEX(i.uv0, _MainTex));

	#ifdef IS_TRANSPARENT_SHADER
	// because people expect color alpha to work only on transparent shaders
	mainTexture *= _Color;
	#else
	mainTexture.rgb *= _Color.rgb;
	#endif

	UNITY_BRANCH
	if (_UseColorOverTime != 0)
	{
		float u = _Time.x * _ColorOverTime_Speed;
		float4 adjustColor = tex2Dlod(_ColorOverTime_Ramp, float4(u, u, 0, 0));
		#ifdef IS_TRANSPARENT_SHADER
			mainTexture *= adjustColor;
		#else
			mainTexture.rgb *= adjustColor.rgb;
		#endif
	}

	UNITY_BRANCH
	if (_Raymarcher_Type != 0)
	{
		float raymarchedScreenDepth;
		raymarch(i.worldPos.xyz, mainTexture.rgb, raymarchedScreenDepth);
		#ifdef OUTPUT_DEPTH
			float realDepthWeight = i.color.r;
			fragOut.depth = lerp(raymarchedScreenDepth, i.pos.z, realDepthWeight);
		#endif
	}

	// cutout support, discard current pixel if alpha is less than 0.05
	clip(mainTexture.a - 0.05);

	if (_UseDitheredTransparency != 0)
	{
		clip(mainTexture.a - triangularPDFNoiseDithering(i.pos.xy));
	}

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
	float3 lightDir = normalize(UnityWorldSpaceLightDir(i.worldPos.xyz));

	// shadows, spot/point light distance calculations, light cookies
	UNITY_LIGHT_ATTENUATION(unityLightAttenuation, i, i.worldPos.xyz);
	float3 lightAttenuation; // assigned later

	fixed3 specularLightColor = _LightColor0.rgb;
	fixed3 diffuseLightColor = _LightColor0.rgb;

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
		diffuseLightRGB += lightProbes;

		// vertex lights
		#ifdef VERTEXLIGHT_ON
			float3 vertexLights = lerp(i.vertexLightsReal.rgb, i.vertexLightsAverage.rgb, _BakedLightingFlatness);
			diffuseLightRGB += vertexLights;
		#endif
		
		// BAD: we cant tell where is complete darkness
		// issue: if we are in complete dark we dont want to artifiaclly lighten up shadowed parts
		// bool isInCompleteDark = unityLightAttenuation < 0.05 && grayness(diffuseLightRGB) < 0.01;

		unityLightAttenuation = lerp(1, unityLightAttenuation, _Shadow);
		lightAttenuation = lerp(_ShadowColor, 1, unityLightAttenuation);

		#ifdef VERTEXLIGHT_ON
			float3 averageLightColor = (averageLightProbes + i.vertexLightsAverage) * 0.7f;
		#else
			float3 averageLightColor = averageLightProbes;
		#endif

		UNITY_BRANCH
		if (!any(specularLightColor))
		{
			specularLightColor = averageLightColor;
		}

		UNITY_BRANCH
		if (_UseFakeLight)
		{
			UNITY_BRANCH
			if (!any(diffuseLightColor))
			{
				//diffuseLightRGB *= 0.5f; // BAD: In older versions I didnt dim it, better way would be to normalize all spherical harmonics so none is too bright
				diffuseLightColor = averageLightColor;
			}
		}

		UNITY_BRANCH
		if (!any(lightDir))
		{
			lightDir = getLightDirectionFromSphericalHarmonics();
		}

		// apply ramp to baked indirect diffuse
		// BAD: this washes out colors
		/*UNITY_BRANCH
		if (any(lightDir))
		{
			float rampNdotL = dot(normal, lightDir) * 0.5 + 0.5;
			rampNdotL = lerp(rampNdotL, 1, 0.5);
			float3 shadowRamp = tex2D(_Ramp, float2(rampNdotL, rampNdotL)).rgb;
			float g = grayness(diffuseLightRGB); // maintain same darkness
			diffuseLightRGB += shadowRamp;
			diffuseLightRGB *= g / grayness(diffuseLightRGB);
		}*/

	#else
		
		// all spot lights, all point lights, cookie directional lights

		// don't adjust shadows at all for additional lights
		lightAttenuation = unityLightAttenuation;

	#endif

	float3 finalRGB = 0;

	float3 halfDir = normalize(lightDir + viewDir);

	float NdotL = dot(normal, lightDir);
	float NdotV = dot(normal, viewDir);
	float NdotH = dot(normal, halfDir);
	
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
			// specular light does not enter surface, it is reflected off surface so it does not get any surface color
			finalRGB += lightAttenuation * specularLightColor * specularReflection;
		}

		// diffuse
		UNITY_BRANCH
		if (any(diffuseLightColor))
		{
			#ifdef UNITY_PASS_FORWARDBASE
			#else
				// issue: sometimes delta pass light is too bright and there is no unlit color to compensate it with
				// lets make sure its not too bright
				float g = grayness(diffuseLightColor);
				UNITY_BRANCH
				if (g > 1) diffuseLightColor /= g;
			#endif

			float rampNdotL = NdotL * 0.5 + 0.5; // remap -1..1 to 0..1
			rampNdotL = lerp(_ShadingRampStretch, 1, rampNdotL); // remap 0..1 to _ShadingRampStretch..1
			float3 shadowRamp = tex2D(_Ramp, float2(rampNdotL, rampNdotL)).rgb * _RampColorAdjustment;
			//shadowRamp = max(0, NdotL + 0.1); // DEBUG, phong
			diffuseLightRGB += 
				shadowRamp *
				diffuseLightColor *
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

		if (_MatcapType == 1)
		{
			// Add to final color
			finalRGB += matcap;
		}
		else
		{
			// Multiply final color
			finalRGB *= matcap;
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
			float emissiveWeight = grayness(emissive.rgb) - grayness(finalRGB);
			// BAD: emissiveWeight = smoothstep(-1, 1, emissiveWeight); causes darker color on not emissive pixel 
			emissiveWeight = smoothstep(0, 1, emissiveWeight);
			finalRGB = lerp(finalRGB, emissive.rgb, emissive);
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
	half alpha = tex2D(_MainTex, i.tex).a * _Color.a;
	clip(alpha - 0.05);
	#if defined(IS_TRANSPARENT_SHADER)
		UNITY_BRANCH
		if (_UseDitheredTransparency != 0)
		{
			clip(alpha - triangularPDFNoiseDithering(vpos.xy));
		}
	#endif

	SHADOW_CASTER_FRAGMENT(i)
}
