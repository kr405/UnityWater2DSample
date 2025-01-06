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

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
                half4 color : COLOR;
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
            float _TextureScale;
            float _WaveAmount;
            float _WaveScale;
            float _WaveSpeed;
            half4 _CausticsColor;
            int _CausticsScale;
            float _CausticsIntensity;
            float _Aberration;
            float _RippleAmount;
            float _RippleScale;
            float _RippleSpeed;
            #define MAX_POINT_COUNT 20
            float4 _ContactPoints[MAX_POINT_COUNT];
            int _NumPoints;

            CBUFFER_START(UnityPerMaterial)
            float4 _MainTex_ST;
            float4 _MainTex_TexelSize;
            CBUFFER_END

            // 0~1のランダムな2次元座標を返す.
            float2 random2(float2 co)
            {
                co = float2(dot(co, float2(127.1, 311.7)), dot(co, float2(269.5, 183.3)));
                return frac(sin(co) * 43758.5453);
            }

            // セルラーノイズを計算する.
            float cellularNoise(float2 co, int scale)
            {
                co = co * scale;
                float minDist = 1;

                for (int i = -1; i <= 1; i++)
                {
                    for (int j = -1; j <= 1; j++)
                    {
                        float2 n = float2(i, j);
                        float2 p = random2(floor(co) + n);
                        p = sin(p * 6.2831 + _Time.y) * 0.5 + 0.5;
                        float dist = distance(frac(co), n + p);
                        minDist = min(minDist, dist);
                    }
                }
                return minDist;
            }

            // コースティクスを計算する.
            float caustics(float2 co)
            {
                float noise = cellularNoise(co, _CausticsScale);
                return pow(abs(noise), 1 / (0.05 + _CausticsIntensity)) * (1 - step(_CausticsIntensity, 0));
            }

            Varyings vert (Attributes IN)
            {
                Varyings OUT;
                OUT.uv = TRANSFORM_TEX(IN.uv, _MainTex);
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.color = IN.color;
                return OUT;
            }
            
            half4 frag (Varyings IN) : SV_Target
            {
                // 接触している最も近いオブジェクトまでの距離を取得する.
                float minDist = length(_ScaledScreenParams.xy);
                for (int i = 0; i < _NumPoints; i++)
                {
                    float dist = distance(IN.positionHCS.xy, _ContactPoints[i].xy);
                    minDist = min(minDist, dist);
                }

                // 波紋の量、速さ、大きさを決定.
                float rippleFactor = IN.uv.x * _RippleAmount + _Time.y * _RippleSpeed;
                float rippleScale = _RippleScale / (50 + minDist);

                // uv座標を波状に変形.v座標値が閾値を上回ったら描画しない.
                IN.uv.y += (cos(rippleFactor) * 0.5 + 0.5) * rippleScale;
                clip(-step(1, IN.uv.y));

                // 揺れの量、速さ、大きさを決定.
                float waveFactor = IN.positionHCS.y * _WaveAmount + _Time.y * _WaveSpeed;
                float waveScale = _WaveScale * 0.005;

                // _CameraSortingLayerTextureのuv座標を求める.
                float2 uv = IN.positionHCS.xy / _ScaledScreenParams.xy;
                uv.x += cos(waveFactor) * waveScale;
                uv.y += (1 - IN.uv.y) * _TextureScale * 2;

                // 水面の色を決定する.
                half4 reflection = SAMPLE_TEXTURE2D(_CameraSortingLayerTexture, sampler_CameraSortingLayerTexture, uv);
                half4 baseColor = reflection * IN.color;

                // コースティクスの強さを求める.
                float r = caustics(IN.uv + _MainTex_TexelSize.xy * _Aberration);
                float g = caustics(IN.uv);
                float b = caustics(IN.uv - _MainTex_TexelSize.xy * _Aberration);

                // 水面の色とコースティクスの色を線形補完して出力.
                return lerp(baseColor, _CausticsColor, half4(r, g, b, g));
            }

            ENDHLSL
        }
    }
}
