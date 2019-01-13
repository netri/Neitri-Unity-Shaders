// by Neitri, free of charge, free to redistribute
// downloaded from https://github.com/netri/Neitri-Unity-Shaders

// Shader created with Shader Forge v1.38 
// Shader Forge (c) Neat Corporation / Joachim Holmer - http://www.acegikmo.com/shaderforge/
// Note: Manually altering this data may prevent you from opening it in Shader Forge
/*SF_DATA;ver:1.38;sub:START;pass:START;ps:flbk:,iptp:0,cusa:False,bamd:0,cgin:,lico:1,lgpr:1,limd:0,spmd:1,trmd:0,grmd:0,uamb:True,mssp:True,bkdf:False,hqlp:False,rprd:False,enco:False,rmgx:True,imps:True,rpth:0,vtps:0,hqsc:True,nrmq:1,nrsp:0,vomd:0,spxs:False,tesm:0,olmd:1,culm:2,bsrc:0,bdst:1,dpts:2,wrdp:False,dith:0,atcv:False,rfrpo:False,rfrpn:NeitriCensor,coma:15,ufog:False,aust:False,igpj:True,qofs:-100,qpre:4,rntp:5,fgom:False,fgoc:False,fgod:False,fgor:False,fgmd:0,fgcr:0.5,fgcg:0.5,fgcb:0.5,fgca:1,fgde:0.01,fgrn:0,fgrf:300,stcl:False,atwp:False,stva:128,stmr:255,stmw:255,stcp:6,stps:0,stfa:0,stfz:0,ofsf:0,ofsu:0,f2p0:False,fnsp:False,fnfb:False,fsmp:False;n:type:ShaderForge.SFN_Final,id:3138,x:32719,y:32712,varname:node_3138,prsc:2|emission-3143-RGB;n:type:ShaderForge.SFN_SceneColor,id:3143,x:32518,y:32779,varname:node_3143,prsc:2|UVIN-576-OUT;n:type:ShaderForge.SFN_ScreenPos,id:5444,x:31752,y:32551,varname:node_5444,prsc:2,sctp:2;n:type:ShaderForge.SFN_Posterize,id:8764,x:32123,y:32725,varname:node_8764,prsc:2|IN-5444-U,STPS-735-OUT;n:type:ShaderForge.SFN_ViewPosition,id:2152,x:31201,y:32883,varname:node_2152,prsc:2;n:type:ShaderForge.SFN_Distance,id:8153,x:31367,y:32909,varname:node_8153,prsc:2|A-2152-XYZ,B-3960-XYZ;n:type:ShaderForge.SFN_Divide,id:9139,x:31540,y:32920,varname:node_9139,prsc:2|A-8153-OUT,B-3452-OUT;n:type:ShaderForge.SFN_ValueProperty,id:3452,x:31367,y:33177,ptovrint:False,ptlb:Cell Size,ptin:_CellSize,varname:node_3452,prsc:2,glob:False,taghide:False,taghdr:False,tagprd:False,tagnsco:False,tagnrm:False,v1:0.015;n:type:ShaderForge.SFN_ObjectPosition,id:3960,x:31186,y:33022,varname:node_3960,prsc:2;n:type:ShaderForge.SFN_Trunc,id:735,x:31712,y:32889,varname:node_735,prsc:2|IN-9139-OUT;n:type:ShaderForge.SFN_ScreenParameters,id:4105,x:31689,y:33229,varname:node_4105,prsc:2;n:type:ShaderForge.SFN_Divide,id:7669,x:31968,y:33221,varname:node_7669,prsc:2|A-4105-PXH,B-4105-PXW;n:type:ShaderForge.SFN_Posterize,id:4691,x:32123,y:32842,varname:node_4691,prsc:2|IN-5444-V,STPS-9184-OUT;n:type:ShaderForge.SFN_Multiply,id:9184,x:31928,y:33025,varname:node_9184,prsc:2|A-735-OUT,B-8300-OUT;n:type:ShaderForge.SFN_Append,id:576,x:32317,y:32779,varname:node_576,prsc:2|A-8764-OUT,B-4691-OUT;n:type:ShaderForge.SFN_Code,id:5833,x:31748,y:33513,varname:node_5833,prsc:2,code:IwBpAGYAIABVAE4ASQBUAFkAXwBTAEkATgBHAEwARQBfAFAAQQBTAFMAXwBTAFQARQBSAEUATwAKAHIAZQB0AHUAcgBuACAAMgAuADAAOwAKACMAZQBsAHMAZQAKAHIAZQB0AHUAcgBuACAAMQAuADAAOwAKACMAZQBuAGQAaQBmAAoA,output:0,fname:IsStereo,width:425,height:331;n:type:ShaderForge.SFN_Divide,id:8300,x:32203,y:33190,varname:node_8300,prsc:2|A-7669-OUT,B-5833-OUT;n:type:ShaderForge.SFN_Add,id:1478,x:30751,y:33753,varname:node_1478,prsc:2|A-692-OUT;n:type:ShaderForge.SFN_ValueProperty,id:6771,x:30390,y:33662,ptovrint:False,ptlb:normal_1_speed_copy,ptin:_normal_1_speed_copy,varname:_normal_1_speed_copy,prsc:2,glob:False,taghide:False,taghdr:False,tagprd:False,tagnsco:False,tagnrm:False,v1:10;n:type:ShaderForge.SFN_Multiply,id:692,x:30572,y:33662,varname:node_692,prsc:2|A-6771-OUT;proporder:3452;pass:END;sub:END;*/

Shader "Neitri/Censor" {
    Properties {
        _CellSize ("Cell Size", Float ) = 0.015
    }
    SubShader {
        Tags {
            "IgnoreProjector"="True"
            "Queue"="Overlay-100"
            "RenderType"="Overlay"
        }
        GrabPass{ "NeitriCensor" }
        Pass {
            Name "FORWARD"
            Tags {
                "LightMode"="ForwardBase"
            }
            Cull Off
            ZWrite Off
            
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #define UNITY_PASS_FORWARDBASE
            #include "UnityCG.cginc"
            #pragma multi_compile_fwdbase
            #pragma only_renderers d3d9 d3d11 glcore gles 
            #pragma target 3.0
            uniform sampler2D NeitriCensor;
            uniform float _CellSize;
            float IsStereo(){
            #if UNITY_SINGLE_PASS_STEREO
            return 2.0;
            #else
            return 1.0;
            #endif
            
            }
            
            struct VertexInput {
                float4 vertex : POSITION;
            };
            struct VertexOutput {
                float4 pos : SV_POSITION;
                float4 projPos : TEXCOORD0;
            };
            VertexOutput vert (VertexInput v) {
                VertexOutput o = (VertexOutput)0;
                float4 objPos = mul ( unity_ObjectToWorld, float4(0,0,0,1) );
                o.pos = UnityObjectToClipPos( v.vertex );
                o.projPos = ComputeScreenPos (o.pos);
                COMPUTE_EYEDEPTH(o.projPos.z);
                return o;
            }
            float4 frag(VertexOutput i, float facing : VFACE) : COLOR {
                float isFrontFace = ( facing >= 0 ? 1 : 0 );
                float faceSign = ( facing >= 0 ? 1 : -1 );
                float4 objPos = mul ( unity_ObjectToWorld, float4(0,0,0,1) );
                float2 sceneUVs = (i.projPos.xy / i.projPos.w);
                float4 sceneColor = tex2D(NeitriCensor, sceneUVs);
////// Lighting:
////// Emissive:
                float node_735 = trunc((distance(_WorldSpaceCameraPos,objPos.rgb)/_CellSize));
                float node_9184 = (node_735*((_ScreenParams.g/_ScreenParams.r)/IsStereo()));
                float3 emissive = tex2D( NeitriCensor, float2(floor(sceneUVs.r * node_735) / (node_735 - 1),floor(sceneUVs.g * node_9184) / (node_9184 - 1))).rgb;
                float3 finalColor = emissive;
                return fixed4(finalColor,1);
            }
            ENDCG
        }
        UsePass "VertexLit/SHADOWCASTER"
    }
}
