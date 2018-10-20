// by Neitri, free of charge, free to redistribute
// downloaded from https://github.com/netri/Neitri-Unity-Shaders

// Some ideas are from:
// Cubed's https://github.com/cubedparadox/Cubeds-Unity-Shaders
// Xiexe's https://vrcat.club/threads/xiexes-toon-shader-v1-2-2-updated-6-20-2018-xstoon-stylized-reflections-update.1878/

//#define UNITY_SHOULD_SAMPLE_SH 1

#include "UnityCG.cginc"
#include "AutoLight.cginc"
#include "Lighting.cginc"
//#include "UnityPBSLighting.cginc"
//#include "UnityStandardBRDF.cginc"

//#define USE_TANGENT_BITANGENT

struct VertexInput {
    float4 vertex : POSITION;
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
	#if defined(UNITY_PASS_FORWARDBASE)
		#if defined(LIGHTMAP_ON) || defined(UNITY_SHOULD_SAMPLE_SH)
			float4 vertexLightsReal : TEXCOORD7;
			float4 vertexLightsAverage : TEXCOORD8;
		#endif
	#endif
	#if defined(USE_TANGENT_BITANGENT)
		float3 tangentDir : TEXCOORD9;
		float3 bitangentDir : TEXCOORD10;
	#endif
};


// custom vertex light shading that uses shading ramp
// based off Shade4PointLights from "\Unity\builtin_shaders-5.6.5f1\CGIncludes\UnityCG.cginc"
float3 CustomShade4PointLights (
    float4 lightPosX, float4 lightPosY, float4 lightPosZ,
    float3 lightColor0, float3 lightColor1, float3 lightColor2, float3 lightColor3,
    float4 lightAttenSq,
    float3 pos, float3 normal)
{
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

	// NdotL
	float4 ndotl = 0;
	ndotl += toLightX * normal.x;
	ndotl += toLightY * normal.y;
	ndotl += toLightZ * normal.z;
	// correct NdotL
	float4 corr = rsqrt(lengthSq);
	ndotl = max(float4(0, 0, 0, 0), ndotl * corr);
	// attenuation
	float4 atten = 1.0 / (1.0 + lengthSq * lightAttenSq);
	float4 diff = ndotl * atten;
	// final color
	float3 col = 0;
	col += lightColor0 * diff.x;
	col += lightColor1 * diff.y;
	col += lightColor2 * diff.z;
	col += lightColor3 * diff.w;
	return col;
}

float3 AverageShade4PointLights (
    float4 lightPosX, float4 lightPosY, float4 lightPosZ,
    float3 lightColor0, float3 lightColor1, float3 lightColor2, float3 lightColor3,
    float4 lightAttenSq,
    float3 pos)
{
	//return (lightColor0 + lightColor1 + lightColor2 + lightColor3) * 0.25; // BAD: does not take into account distance to lights

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


VertexOutput vert (VertexInput v) 
{
    VertexOutput o = (VertexOutput)0;
    o.uv0.xy = v.texcoord0;
	o.color = v.color;
	o.normal = UnityObjectToWorldNormal(v.normal);
	#if defined(USE_NORMAL_MAP)
		o.tangentDir = normalize( mul( unity_ObjectToWorld, float4( v.tangent.xyz, 0.0 ) ).xyz );
		o.bitangentDir = normalize(cross(o.normal, o.tangentDir) * v.tangent.w);
	#endif
    o.posWorld = mul(unity_ObjectToWorld, v.vertex);

	float3 posModel = mul(unity_ObjectToWorld, float4(0, 0, 0, 1));

	// Vertex lights are just a cheap way to calculate 4 spot light without shadows at once
	// we are finalRGB additional lights in seperate delta forward passes, so no need for vertex lights

	#if defined(UNITY_PASS_FORWARDBASE)
		#ifdef VERTEXLIGHT_ON
			// Approximated illumination from non-important point lights
			o.vertexLightsReal.rgb = CustomShade4PointLights (
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
    o.pos = UnityObjectToClipPos( v.vertex );
    UNITY_TRANSFER_FOG(o,o.pos); // transfer fog coords
    TRANSFER_VERTEX_TO_FRAGMENT(o) // transfer shadow coords
    return o;
}

#if defined(_RAYMARCHER_TYPE_SPHERES) || defined(_RAYMARCHER_TYPE_HEARTS)
	#define OUTPUT_DEPTH
	#define ENABLE_RAYMARCHER
	#if defined(_RAYMARCHER_TYPE_SPHERES)
		#define RAYMARCHER_DISTANCE_FIELD_FUNCTION distanceMap_spheres
	#endif	
	#if defined(_RAYMARCHER_TYPE_HEARTS)
		#define RAYMARCHER_DISTANCE_FIELD_FUNCTION distanceMap_hearts
	#endif
	float _Raymarcher_Scale;
	#include "RayMarcher.cginc"
#endif	




sampler2D _MainTex; float4 _MainTex_ST;
fixed4 _Color;

sampler2D _EmissionMap; float4 _EmissionMap_ST;
fixed4 _EmissionColor;



#if defined(USE_NORMAL_MAP)
	#define USE_TANGENT_BITANGENT
	sampler2D _NormalMap; float4 _NormalMap_ST;
#endif

float _Shadow;
float _Smoothness;

float _IndirectLightingFlatness;

//sampler2D _ShadingRamp;

#if defined(_COLOR_OVER_TIME_ON)
	sampler2D _ColorOverTime_Ramp;
	float _ColorOverTime_Speed;
#endif


float grayness(float3 color)
{
	const float3 greyScale = float3(0.3, 0.59, 0.11);
	return dot(color, greyScale);
}


// from: https://www.shadertoy.com/view/MslGR8
// note: valve edition
//       from http://alex.vlachos.com/graphics/Alex_Vlachos_Advanced_VR_Rendering_GDC2015.pdf
// note: input in pixels (ie not normalized uv)
float3 ScreenSpaceDither( float2 vScreenPos )
{
	// Iestyn's RGB dither (7 asm instructions) from Portal 2 X360, slightly modified for VR
	float3 vDither = dot( float2( 171.0, 231.0 ), vScreenPos.xy + _Time.z ).xxx;
	vDither.rgb = frac( vDither.rgb / float3( 103.0, 71.0, 97.0 ) ) - float3( 0.5, 0.5, 0.5 );
	return vDither.rgb;
}

// remaps dot according to shading ramp
float remapDot(float dot)
{
	dot = dot * 0.5 + 0.5; // remap -1 .. 1 to 0 .. 1
	//return tex2Dlod(_ShadingRamp, float4(dot, 0.5f, 0, 0)).r;
	return dot;
}

float maxDot(float3 a, float3 b)
{
	return max(0, dot(a, b));
}



// normal distribution function
// Trowbridge-Reitz GGX normal distribution function
float DistributionGGX(float NdotH, float a)
{
    float a2     = a*a;
    float NdotH2 = NdotH*NdotH;
	float nom    = a2;
    float denom  = (NdotH2 * (a2 - 1.0) + 1.0);
    denom        = UNITY_PI * denom * denom;
    return nom / denom;
}

float GeometrySchlickGGX(float NdotV, float k)
{
    float denom = NdotV * (1.0 - k) + k;
    return NdotV / denom;
}  
// geometry function
// microfacet shadowing
float GeometrySmith(float NdotV, float NdotL, float k)
{
    float ggx1 = GeometrySchlickGGX(NdotV, k);
    float ggx2 = GeometrySchlickGGX(NdotL, k);
	
    return ggx1 * ggx2;
}

// fresnel equation
float3 fresnelSchlick(float NdotV, float3 F0)
{
    return F0 + (1.0 - F0) * pow(1.0 - NdotV, 5.0);
}

// based on https://learnopengl.com/PBR/Theory
float3 pbrSpecular(float N, float L, float V, float H, float3 surfaceColor, float smoothness, float metalness)
{
	float a = smoothness;

	float NdotV = max(dot(N, V), 0.0);
    float NdotL = max(dot(N, L), 0.0);
	float NdotH = max(dot(N, H), 0.0);

	float kDirect = a + 1; kDirect = (kDirect * kDirect) / 8.0f;
	float kIBL = (a * a) / 2.0f;

	float3 F0 = 0.04;
	surfaceColor = 1;
	F0 = lerp(F0, surfaceColor, metalness);

	float result = DistributionGGX(NdotH, a) * GeometrySmith(NdotV, NdotL, kIBL) * fresnelSchlick(NdotV, F0);
	result /= 4 * NdotV;

	return result;
}





#if defined(OUTPUT_DEPTH)
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

	float4 mainTexture = tex2D(_MainTex,TRANSFORM_TEX(i.uv0, _MainTex)) * _Color;
	clip(mainTexture.a - 0.05); // discard current pixel if alpha is less than 0.05

	#if defined(_COLOR_OVER_TIME_ON)
		float3 adjustColor = tex2Dlod(_ColorOverTime_Ramp, float4(_Time.x * _ColorOverTime_Speed, _Time.x * _ColorOverTime_Speed, 0, 0)).rgb;
		mainTexture.rgb *= adjustColor;
	#endif

	#if defined(ENABLE_RAYMARCHER)
		float raymarchedScreenDepth;
		raymarch(i.posWorld.xyz, mainTexture.rgb, raymarchedScreenDepth);
		float realDepthWeight = i.color.r;
		fragOut.depth = lerp(raymarchedScreenDepth, i.pos.z, realDepthWeight);
	#endif

#if defined(UNITY_SINGLE_PASS_STEREO)
	float3 worldSpaceCameraPos = (unity_StereoWorldSpaceCameraPos[0].xyz + unity_StereoWorldSpaceCameraPos[1].xyz) / 2.0;
#else
	float3 worldSpaceCameraPos = _WorldSpaceCameraPos.xyz;
#endif


	float3 normal = i.normal;
	
	// slightly dither normal to hide obvious normal interpolation
	normal = normalize(normal + ScreenSpaceDither(i.pos.xy) / 50.0);
	
	// direction from pixel towards camera
	float3 viewDir = normalize(worldSpaceCameraPos - i.posWorld.xyz);

	// direction from pixel towards light
	float3 lightDir = UnityWorldSpaceLightDir(i.posWorld.xyz);

	// bounced direction from camera towards pixel
	float3 reflectedviewDir = reflect(-viewDir, normal);

#if defined(USE_NORMAL_MAP)
	float3x3 tangentTransform = float3x3( i.tangentDir, i.bitangentDir, normal);
    float3 normalLocal = UnpackNormal(tex2D(_NormalMap,TRANSFORM_TEX(i.uv0, _NormalMap)));
    normal = normalize(mul( normalLocal, tangentTransform )); // perturbed normals
#endif



	// shadows, spot/point light distance calculations, light cookies
	UNITY_LIGHT_ATTENUATION(unityLightAttenuation, i, i.posWorld.xyz);

	fixed3 lightColor = _LightColor0.rgb;


	// prevent bloom if light color is over saturated
	//fixed lightColorMax = max(lightColor.x, max(lightColor.y, lightColor.z));
	//if(lightColorMax > 1) lightColor /= lightColorMax;


	float3 diffuseRGB = 0;

	#if defined(UNITY_PASS_FORWARDBASE)
		// non cookie directional light, or no lights at all (just ambient, light probes and vertex lights)
		
		//allSphericalHarmonics = LinearToGammaSpace (allSphericalHarmonics);

		// TODO: proxy volume support, see: ShadeSHPerPixel

		// ambient color, skybox, light probes are baked in spherical harmonics
		half3 averageLightProbes = ShadeSH9(half4(0, 0, 0, 1));

		half3 realLightProbes = ShadeSH9(half4(normal, 1));

		if (!any(lightDir))
		{
			// dominant light direction approximation from spherical harmonics

			// Xiexe's
			//half3 reverseShadeSH9Light = ShadeSH9(float4(-normal,1));
			//half3 noAmbientShadeSH9Light = (realLightProbes - reverseShadeSH9Light)/2;
			//lightDir = -normalize(noAmbientShadeSH9Light * 0.5 + 0.533);

			// Neitri's
			lightDir = normalize(unity_SHAr.xyz + unity_SHAg.xyz + unity_SHAb.xyz);
		}
	

		half3 lightProbes = lerp(realLightProbes, averageLightProbes, _IndirectLightingFlatness);

		float3 vertexLights = lerp(i.vertexLightsReal.rgb, i.vertexLightsAverage.rgb, _IndirectLightingFlatness);
		
	
		diffuseRGB += vertexLights + lightProbes;

		// normally unlit color is black, but we want to show some color there to be closer to Cubed's toon
		// so we we averge all ambient like sources that are used
		float3 unlit = averageLightProbes + lightColor + i.vertexLightsAverage;
		// then adjust the grayness so it's equal to (lightColor grayness - _Shadow)
		float unlitTargetGrayness = lerp(grayness(lightColor), 0, _Shadow);
		unlit *= unlitTargetGrayness / max(0.001, grayness(unlit));


		if (!any(lightColor))
		{
			lightColor = (averageLightProbes + i.vertexLightsAverage) * 0.7f;
		}

		//DEBUG
		//return fixed4(realLightProbes*mainTexture.rgb, 1); // Unity legacy diffuse

	#else
		
		// all spot lights, all point lights, cookie directional lights
		
	#endif

	fixed3 finalRGB = diffuseRGB * mainTexture.rgb;
	
	lightDir = normalize(lightDir);

	// specular
	UNITY_BRANCH
	if (_Smoothness > 0)
	{
		float3 halfDir = normalize(lightDir + viewDir);

		//float specular = (8.0 + _Smoothness*100) / ( 8.0 * UNITY_PI ) * pow(max(dot(normal, halfDir), 0.0), _Smoothness*100);
		float specular = DistributionGGX(maxDot(normal, halfDir), (1 - _Smoothness));
		specular = specular * _Smoothness;
		specular = specular * _Smoothness / (4 * maxDot(normal, viewDir) + 0.1);
		//specular = saturate(specular);
		//float3 specular = pbrSpecular(normal, lightDir, viewDir, halfDir, mainTexture.rgb, _Smoothness, 0);

		//float3 specularColor = (UNITY_SAMPLE_TEXCUBE_LOD(unity_SpecCube0, reflectedviewDir, (1 - _Smoothness) * 6));		
		//if (!any(specularColor)) specularColor = lightColor;

		finalRGB += lightColor * specular * unityLightAttenuation;
	}

	// diffuse
	UNITY_BRANCH
	if (any(lightDir) && any(lightColor)) 
	{
		float diffuse = dot(normal, lightDir);

		#if defined(_SHADER_TYPE_SKIN)
		// makes dot ramp more smooth
		diffuse = diffuse * 0.5 + 0.5; // remap -1 .. 1 to 0 .. 1
		#endif

		diffuse = max(0, diffuse);
		float3 diffuseColor = 0;

		// in add pass, we don't want to artificially lighten unlit color, because we might end up with color over (1,1,1) if there are multiple lights, doing this in base pass is enough
		#if defined(UNITY_PASS_FORWARDBASE)
			diffuseColor = lerp(unlit, lightColor, diffuse);
			diffuseColor = diffuseColor * unityLightAttenuation * mainTexture.rgb;
		#else
			// issue: sometimes delta pass light is too bright and there is no unlit color to compensate it with
			// lets make sure its not too bright
			diffuseColor = lightColor * unityLightAttenuation;
			float g = grayness(diffuseColor);
			if (g > 1) diffuseColor *= 1 / g;
			diffuseColor = diffuseColor * diffuse * mainTexture.rgb;
		#endif

		finalRGB += diffuseColor;
		
	}

	
	#if defined(_SHADER_TYPE_SKIN)
	// view based shading, adds MMD like feel
	finalRGB *= lerp(1, dot(viewDir, normal), 0.3);
	#endif

	
	#if defined(UNITY_PASS_FORWARDBASE)
	#else
	#endif
	// can use following defines DIRECTIONAL || POINT || SPOT || DIRECTIONAL_COOKIE || POINT_COOKIE || SPOT_COOKIE


	// DEBUG
	#if defined(UNITY_PASS_FORWARDBASE)
	#else
	#endif
	//finalRGB = ScreenSpaceDither(i.pos.xy)*10;
	//diffuseRGB = lightColor * lightWeight;
	//diffuseRGB = lightWeight;
	//diffuseRGB = unlit;
	//diffuseRGB = unityLightAttenuation;
	//diffuseRGB = abs(diffuseRGB);


	// prevent bloom, final failsafe
	//finalRGB = saturate(finalRGB);

	#if defined(UNITY_PASS_FORWARDBASE)
		fixed4 emissive = tex2D(_EmissionMap,TRANSFORM_TEX(i.uv0.xy, _EmissionMap)) * _EmissionColor;
		finalRGB += emissive.rgb * emissive.a;
	#else
	#endif

	fixed4 finalRGBA = fixed4(finalRGB, mainTexture.a);
	
	#if defined(UNITY_PASS_FORWARDBASE)
		UNITY_APPLY_FOG(i.fogCoord, finalRGBA);
	#else
		UNITY_APPLY_FOG_COLOR(i.fogCoord, finalRGBA, half4(0,0,0,0)); // fog towards black in additive pass
	#endif

	// DEBUG
	#if defined(UNITY_PASS_FORWARDBASE)
		//discard;
	#else
		//discard;
	#endif

	#if defined(OUTPUT_DEPTH)
	fragOut.color = finalRGBA;
	return fragOut;
	#else
    return finalRGBA;
	#endif

}