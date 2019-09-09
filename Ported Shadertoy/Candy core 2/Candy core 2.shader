// converted and modified by Neitri, based on shader from https://www.shadertoy.com/view/4sVXDz

Shader "Neitri/Ported Shadertoy/Candy core 2"
{

	Properties
	{
	}

	SubShader
	{
		Tags
		{ 
			"RenderType" = "Opaque" 
			"Queue" = "Geometry" 
		}

		Pass
		{
			Name "FORWARD"
			Tags { "LightMode" = "ForwardBase" }
			ZWrite On
			Cull Off

			CGPROGRAM
			#pragma only_renderers d3d11 glcore gles
			#pragma target 4.0
			#pragma multi_compile_fwdadd_fullshadows
			#pragma multi_compile_fog
			#pragma vertex vert
			#pragma fragment frag

			#include "UnityCG.cginc"
			#include "Lighting.cginc"

			struct VertexInput {
				float4 vertex : POSITION;
				float2 uv:TEXCOORD0;
				float4 tangent : TANGENT;
				float3 normal : NORMAL;
			};


			struct VertexOutput {
				float4 pos : SV_POSITION;
				float2 uv: TEXCOORD0;
				float4 worldPos : TEXCOORD1;
			};



			#define MAX_TRACE_DISTANCE 20.0          // max trace distance
			#define INTERSECTION_PRECISION 0.01        // precision of the intersection
			#define NUM_OF_TRACE_STEPS 20 // originally: 100
			
			#define PI 3.14159265359

			#define TIME _Time.y
			//#define TIME 0

			float vmax(float3 v) {
				return max(max(v.x, v.y), v.z);
			}

			float fPlane(float3 p, float3 n, float distanceFromOrigin) {
				return dot(p, n) + distanceFromOrigin;
			}

			// Box: correct distance to corners
			float fBox(float3 p, float3 b) {
				float3 d = abs(p) - b;
				return length(max(d, float3(0, 0, 0))) + vmax(min(d, float3(0, 0, 0)));
			}

			// Rotate around a coordinate axis (i.e. in a plane perpendicular to that axis) by angle <a>.
			// Read like this: R(p.xz, a) rotates "x towards z".
			// This is fast if <a> is a compile-time constant and slower (but still practical) if not.
			void pR(inout float2 p, float a) {
				p = cos(a)*p + sin(a)*float2(p.y, -p.x);
			}

			// Reflect space at a plane
			float pReflect(inout float3 p, float3 planeNormal, float offset) {
				float t = dot(p, planeNormal) + offset;
				if (t < 0.) {
					p = p - (2.*t)*planeNormal;
				}
				return sign(t);
			}


			// The "Round" variant uses a quarter-circle to join the two objects smoothly:
			float fOpUnionRound(float a, float b, float r) {
				float m = min(a, b);
				if ((a < r) && (b < r)) {
					return min(m, r - sqrt((r - a)*(r - a) + (r - b)*(r - b)));
				}
				else {
					return m;
				}
			}

			float fOpIntersectionRound(float a, float b, float r) {
				float m = max(a, b);
				if ((-a < r) && (-b < r)) {
					return max(m, -(r - sqrt((r + a)*(r + a) + (r + b)*(r + b))));
				}
				else {
					return m;
				}
			}

			float fOpDifferenceRound(float a, float b, float r) {
				return fOpIntersectionRound(a, -b, r);
			}


			// polyhedron from by Knighty https://www.shadertoy.com/view/XlX3zB


			float3 nc, pab, pbc, pca;
			void initIcosahedron() {//setup folding planes and vertex
				int Type = 5;
				float cospin = cos(PI / float(Type)), scospin = sqrt(0.75 - cospin * cospin);
				nc = float3(-0.5, -cospin, scospin);//3rd folding plane. The two others are xz and yz planes
				pab = float3(0., 0., 1.);
				pbc = float3(scospin, 0., 0.5);//No normalization in order to have 'barycentric' coordinates work evenly
				pca = float3(0., scospin, cospin);
				pbc = normalize(pbc);	pca = normalize(pca);//for slightly better DE. In reality it's not necesary to apply normalization :) 
			}

			// Barycentric to Cartesian 
			float3 bToC(float3 A, float3 B, float3 C, float3 barycentric) {
				return barycentric.x * A + barycentric.y * B + barycentric.z * C;
			}

			float3 pModIcosahedron(inout float3 p, int subdivisions) {
				p = abs(p);
				pReflect(p, nc, 0.);
				p.xy = abs(p.xy);
				pReflect(p, nc, 0.);
				p.xy = abs(p.xy);
				pReflect(p, nc, 0.);

				if (subdivisions > 0) {

					float3 A = pbc;
					float3 C = reflect(A, normalize(cross(pab, pca)));
					float3 B = reflect(C, normalize(cross(pbc, pca)));

					float3 n;

					// Fold in corner A 

					float3 p1 = bToC(A, B, C, float3(.5, .0, .5));
					float3 p2 = bToC(A, B, C, float3(.5, .5, .0));
					n = normalize(cross(p1, p2));
					pReflect(p, n, 0.);

					if (subdivisions > 1) {

						// Get corners of triangle created by fold

						A = reflect(A, n);
						B = p1;
						C = p2;

						// Fold in corner A

						p1 = bToC(A, B, C, float3(.5, .0, .5));
						p2 = bToC(A, B, C, float3(.5, .5, .0));
						n = normalize(cross(p1, p2));
						pReflect(p, n, 0.);


						// Fold in corner B

						p2 = bToC(A, B, C, float3(.0, .5, .5));
						p1 = bToC(A, B, C, float3(.5, .5, .0));
						n = normalize(cross(p1, p2));
						pReflect(p, n, 0.);
					}
				}

				return p;
			}

			float3 pRoll(inout float3 p) {
				//return p;
				float s = 5.;
				float d = 0.01;
				float a = sin(TIME * s) * d;
				float b = cos(TIME * s) * d;
				pR(p.xy, a);
				pR(p.xz, a + b);
				pR(p.yz, b);
				return p;
			}

			float3 lerp(float3 a, float3 b, float s) {
				return a + (b - a) * s;
			}

			float face(float3 p) {
				// Align face with the xy plane
				float3 rn = normalize(lerp(pca, float3(0, 0, 1), 0.5));
				p = reflect(p, rn);
				return min(
					fPlane(p, float3(0, 0, -1), -1.4),
					length(p + float3(0, 0, 1.4)) - 0.02
				);
			}

			float3 planeNormal(float3 p) {
				// Align face with the xy plane
				float3 rn = normalize(lerp(pca, float3(0, 0, 1), 0.5));
				return reflect(p, rn);
			}
			float3 pSpin(float3 p) {
				pR(p.xz, TIME / 2.);
				pR(p.yz, TIME / 4. + 10.);
				pR(p.xy, TIME);
				return p;
			}

			float spinningBox(float3 p) {
				p = pSpin(p);
				return fBox(p, float3(1., 1., 1.));
			}

			// float inner(float3 p) {
			//     //float t = 1.;
			//     int i = int(mod(t/4., 2.));
			// 	pModIcosahedron(p, i+1);
			//     p = planeNormal(p);
			//     p.z += 1.;
			//     //p.z += sin(t*PI/2. + .2) * 0.5;
			//     //pR(p.xy, t*1.5);
			//     //pR(p.zy, t/2.);

			//     pR(p.zy, PI*t/4.);
			//     pR(p.zy, PI*.5);

			//     //return fBox(p, float3(9.,.05,(float(i)/3.)+.1));
			//     return fBox(p, float3(9., .05, .2));
			// }

			float inner(float3 p) {
				// float t = 0.;
				pModIcosahedron(p, 2);
				p = planeNormal(p);
				p.z += 2.;
				pR(p.zy, PI*TIME / 4.);
				pR(p.zy, PI*.5);
				return fBox(p, float3(9., .1, .1));
			}

			float other(float3 p) {
				//pR(p.xz, t*.3);
				//pR(p.zy, t*.3);
				pModIcosahedron(p, 1);
				p = planeNormal(p);
				p += float3(0., 0., 2.);
				pR(p.xz, TIME*1.5 * 1.);
				pR(p.zy, TIME / 2. + 2.);
				return fBox(p, float3(.5, .1, .2));
			}

			float exampleModelC(float3 p) {
				pR(p.xy, 2.832);

				// pR(p.xz, t/3.);

				// pR(p.yz, t*PI/2.);
				// pR(p.xy, t*PI/4.);
				//pModIcosahedron(p, 2);
				//pR(p.xy, t/8.);
				// pR(p.yz, t/16.);
				//pModIcosahedron(p, 1);
				//p = planeNormal(p);
				float b = inner(p);
				float a = other(p);
				return b;
				return fOpDifferenceRound(a, b, 0.3);
			}

			float exampleModel(float3 p) {
				//pRoll(p);
				return exampleModelC(p);
			}

			// The MINIMIZED version of https://www.shadertoy.com/view/Xl2XWt


			// checks to see which intersection is closer
			// and makes the y of the float2 be the proper id
			float2 opU(float2 d1, float2 d2) {

				return (d1.x<d2.x) ? d1 : d2;

			}


			//--------------------------------
			// Modelling 
			//--------------------------------
			float2 map(float3 p) {

				//return float2(length(p) - 0.5, 1.); // DEBUG

				float2 res = float2(exampleModel(p), 1.);
				// float2 res2 = float2(core(p) ,2.); 
				return res;
				// return opU(res, res2);
			}



			float2 calcIntersection(in float3 rayOrigin, in float3 rayDirection, out float3 resultPos) {

				float h = 0;
				float t = 0;
				float res = -1.0;
				float id = -1.;
				resultPos = rayOrigin;

				for (int i = 0; i < NUM_OF_TRACE_STEPS; i++) {
					float2 m = map(resultPos + rayDirection * INTERSECTION_PRECISION);
					if (m.x < 0)
					{
						m = map(resultPos);
						t += m.x;
						id = m.y;
						break;
					}

					resultPos += rayDirection * (m.x + INTERSECTION_PRECISION);
					t += m.x + INTERSECTION_PRECISION;
					id = m.y;
					if (t > MAX_TRACE_DISTANCE)
					{
						break;
					}
				}

				if (t < MAX_TRACE_DISTANCE) res = t;
				if (t > MAX_TRACE_DISTANCE) id = -1.0;

				return float2(res, id);

			}



			// Calculates the normal by taking a very small distance,
			// remapping the function, and getting normal for that
			float3 calcNormal(in float3 pos) {

				float3 eps = float3(0.001, 0.0, 0.0);
				float3 nor = float3(
					map(pos + eps.xyy).x - map(pos - eps.xyy).x,
					map(pos + eps.yxy).x - map(pos - eps.yxy).x,
					map(pos + eps.yyx).x - map(pos - eps.yyx).x);
				return normalize(nor);
			}




			float4 render(float2 res, float3 ro, float3 rd, float3 worldPos) {


				float4 color = float4(0, 0, 0, 0); // background color

				if (res.y == 2.) {
					return float4(0.987, 0.257, 1.000, 1);
				}

				if (res.y > -.5) {
					color.a = 1;
					
					float3 pos = ro + rd * res.x;
					float3 norm = calcNormal(pos);
					float3 fromCamera = normalize(worldPos - _WorldSpaceCameraPos);
					float3 light = 0;
					
					// use first directional light
					/*if (length(_WorldSpaceLightPos0) > 0) 
					{
						float3 lightDirection = normalize(lerp(_WorldSpaceLightPos0.xyz, _WorldSpaceLightPos0.xyz - worldPos.xyz, _WorldSpaceLightPos0.w));
						light = max(0, dot(norm, lightDirection)) * _LightColor0.rgb;
					}*/

					// use light probes
					//light += ShadeSH9(half4(norm, 1));

					// use reflection probe
					light += DecodeHDR(UNITY_SAMPLE_TEXCUBE_LOD(unity_SpecCube0, reflect(fromCamera, norm), 2), unity_SpecCube0_HDR);

					float3 candy = norm * 0.5 + 0.5;
					
					float d = max(0, -dot(norm, normalize(pos)));
					color.rgb = lerp(light, candy, d);

					// DEBUG
					//color.xyz = light;
				}

				return color;
			}






			VertexOutput vert (VertexInput v)
			{
				VertexOutput o;
				o.pos = UnityObjectToClipPos (v.vertex);
				o.uv = v.uv;
				o.worldPos = mul(UNITY_MATRIX_M, v.vertex);
				return o;
			}

			struct fragOut
			{
				fixed4 color : SV_Target;
				float depth : SV_Depth;
			};

			fragOut frag(VertexOutput i)
			{
				initIcosahedron();

				float transformScale = length(mul(UNITY_MATRIX_M, float4(1, 0, 0, 0)));
				float scaleOffset = 4.3 / transformScale;
				float3 positionOffset = mul(UNITY_MATRIX_M, float4(0, 0, 0, 1)).xyz;

				float3 adjustedWorldPos = (i.worldPos - positionOffset) * scaleOffset;
				float3 adjustedCameraPos = (_WorldSpaceCameraPos - positionOffset) * scaleOffset;

				float3 rayOrigin = adjustedWorldPos;
				float3 rayDirection = normalize(rayOrigin - adjustedCameraPos);
				if (distance(_WorldSpaceCameraPos, positionOffset) < transformScale)
				{
					rayOrigin = adjustedCameraPos;
					rayDirection = normalize(adjustedWorldPos - rayOrigin);
				}

				float3 resultPos;
				float2 res = calcIntersection(rayOrigin, rayDirection, resultPos);
		    

				fragOut o;

				float3 realPos = resultPos / scaleOffset + positionOffset;
				float4 clipPos = mul(UNITY_MATRIX_VP, float4(realPos, 1.0));
				o.depth = clipPos.z / clipPos.w;

				o.color = render( res.xy , rayOrigin, rayDirection, realPos);
				clip(o.color.a-0.01);
				o.color = saturate(o.color); // prevent bloom
				
				return o;
			}

			ENDCG
		}
		


	}

	FallBack "Standard"
}


