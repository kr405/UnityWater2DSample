Shader "Custom/Water2D"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
    }
    SubShader
    {
        Tags { "RenderType"="Transparent" "Queue"="Transparent" "LightMode"="Universal2D" }
        Blend SrcAlpha OneMinusSrcAlpha
        ZTest Less

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma hull hull
            #pragma domain domain
            #pragma geometry geom
            #pragma fragment frag
            #pragma require tessellation tessHW
            #pragma require geometry

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
                half4 color : COLOR;
            };

            # define NUM_CONTROL_POINTS 3
            struct HSConstOutput
            {
                float tessFactor[NUM_CONTROL_POINTS] : SV_TessFactor;
                float insideTessFactor : SV_InsideTessFactor;
            };

            struct Varyings
            {
                float2 uv : TEXCOORD0;
                float4 positionHCS : SV_POSITION;
                half4 color : COLOR;
            };

            TEXTURE2D(_MainTex);
            TEXTURE2D(_CameraSortingLayerTexture);
            SAMPLER(sampler_CameraSortingLayerTexture);

            float4 _CameraSortingLayerTexture_TexelSize;
            float4 _Scale;
            float _WaveAmount;
            float _WaveScale;
            float _WaveSpeed;
            half4 _CausticsColor;
            float _CausticsScale;
            float _CausticsIntensity;
            float _Aberration;
            int _Smoothness;
            float _RippleAmount;
            float _RippleHeight;

            CBUFFER_START(UnityPerMaterial)
            float4 _MainTex_ST;
            float4 _MainTex_TexelSize;
            CBUFFER_END

            float2 random2(float2 co)
            {
                co = float2(dot(co, float2(127.1, 311.7)), dot(co, float2(269.5, 183.3)));
                return frac(sin(co) * 43758.543123);
            }

            float cellularNoise(float2 co, int scale)
            {
                co = co * scale;
                float min_dist = 1;

                for (int i = -1; i <= 1; i++)
                {
                    for (int j = -1; j <= 1; j++)
                    {
                        float2 n = float2(i, j);
                        float2 p = random2(floor(co) + n);
                        p = sin(p * 10 + _Time.y) * 0.5 + 0.5;
                        float dist = distance(frac(co), n + p);
                        min_dist = min(min_dist, dist);
                    }
                }
                return min_dist;
            }

            float caustics(float2 co)
            {
                float noise = cellularNoise(co, _CausticsScale);
                return pow(abs(noise), _CausticsIntensity);
            }

            Attributes vert (Attributes IN)
            {
                Attributes OUT = IN;
                OUT.uv = TRANSFORM_TEX(IN.uv, _MainTex);
                return OUT;
            }
            
            [domain("tri")]
            [partitioning("integer")]
            [outputtopology("triangle_cw")]
            [patchconstantfunc("hullConst")]
            [outputcontrolpoints(NUM_CONTROL_POINTS)]
            Attributes hull(InputPatch<Attributes, NUM_CONTROL_POINTS> IN, uint id : SV_OutputControlPointID)
            {
                Attributes OUT;
                OUT.positionOS = IN[id].positionOS;
                OUT.uv = IN[id].uv;
                OUT.color = IN[id].color;
                return OUT;
            }

            HSConstOutput hullConst(InputPatch<Attributes, NUM_CONTROL_POINTS> IN)
            {
                HSConstOutput OUT;
                OUT.tessFactor[0] = OUT.tessFactor[2] = OUT.insideTessFactor = 1;
                OUT.tessFactor[1] = _Smoothness;
                return OUT;
            }

            [domain("tri")]
            Attributes domain(HSConstOutput IN, const OutputPatch<Attributes, NUM_CONTROL_POINTS> patch, float3 location : SV_DomainLocation)
            {
                Attributes OUT;
                OUT.positionOS =
                    patch[0].positionOS * location.x +
                    patch[1].positionOS * location.y +
                    patch[2].positionOS * location.z;
                OUT.uv =
                    patch[0].uv * location.x +
                    patch[1].uv * location.y +
                    patch[2].uv * location.z;
                OUT.color = 
                    patch[0].color * location.x +
                    patch[1].color * location.y +
                    patch[2].color * location.z;
                return OUT;
            }

            [maxvertexcount(3)]
            void geom(triangle Attributes IN[3], inout TriangleStream<Varyings> outStream)
            {
                for (int i = 0; i < 3; i++)
                {
                    Varyings OUT;

                    float4 positionOS = IN[i].positionOS;
                    float2 uv = IN[i].uv;
                    positionOS.y += step(1, uv.y) * cos((uv.x + _Time.x) * _RippleAmount) * _CameraSortingLayerTexture_TexelSize.x * _RippleHeight;

                    OUT.positionHCS = TransformObjectToHClip(positionOS.xyz);
                    OUT.uv = uv;
                    OUT.color = IN[i].color;
                    outStream.Append(OUT);
                }
            }

            half4 frag (Varyings IN) : SV_Target
            {
                // 波の量、速さ、大きさを決定.
                float waveFactor = (IN.positionHCS.y + _Time.y * _WaveSpeed) * _WaveAmount;
                float waveScale = _CameraSortingLayerTexture_TexelSize.x * _WaveScale;

                // _CameraSortingLayerTextureのuv座標を求める.
                float2 uv = IN.positionHCS.xy / _ScaledScreenParams.xy;
                uv.x += cos(waveFactor) * waveScale;
                uv.y += (1 - IN.uv.y) * _Scale.y * 2;

                // 水面の色を決定する.
                half4 mirrorColor = SAMPLE_TEXTURE2D(_CameraSortingLayerTexture, sampler_CameraSortingLayerTexture, uv);
                half4 baseColor = mirrorColor * IN.color;

                // コースティクスの強さを求める.
                float r = caustics(IN.uv + _MainTex_TexelSize.xy * _Aberration);
                float g = caustics(IN.uv);
                float b = caustics(IN.uv - _MainTex_TexelSize.xy * _Aberration);

                // 水面の色とコースティクスの色を線形補完して出力.
                return lerp(baseColor, _CausticsColor, half4(r, g, b, IN.color.a));
            }

            ENDHLSL
        }
    }
}
