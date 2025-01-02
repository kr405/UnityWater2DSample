Shader "Custom/Water2D"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _Threshold ("Threshold", Float) = 0
    }
    SubShader
    {
        Tags { "RenderType"="Transparent" "Queue"="Transparent" }
        Blend SrcAlpha OneMinusSrcAlpha

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct Attrubutes
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
                float4 color : COLOR;
            };

            struct Varyings
            {
                float2 uv : TEXCOORD0;
                float4 positionHCS : SV_POSITION;
                float4 color : COLOR;
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

            CBUFFER_START(UnityPerMaterial)
            float4 _MainTex_ST;
            float4 _MainTex_TexelSize;
            float _Threshold;
            CBUFFER_END

            float2 random2(float2 input)
            {
                input = float2(dot(input, float2(127.1, 311.7)), dot(input, float2(269.5, 183.3)));
                return frac(sin(input) * 43758.543123);
            }

            float cellularNoise(float2 input, int scale)
            {
                input = input * scale;
                float min_dist = 1;

                for (int i = -1; i <= 1; i++)
                {
                    for (int j = -1; j <= 1; j++)
                    {
                        float2 n = float2(i, j);
                        float2 p = random2(floor(input) + n);
                        p = sin(p * 10 + _Time.y) * 0.5 + 0.5;
                        float dist = distance(frac(input), n + p);
                        min_dist = min(min_dist, dist);
                    }
                }
                return min_dist;
            }

            float caustics(float2 input)
            {
                float noise = abs(cellularNoise(input, _CausticsScale));
                return pow(noise, _CausticsIntensity);
            }

            Varyings vert (Attrubutes IN)
            {
                Varyings OUT;
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.uv = TRANSFORM_TEX(IN.uv, _MainTex);
                OUT.color = IN.color;
                return OUT;
            }

            half4 frag (Varyings IN) : SV_Target
            {
                // �g�̗ʁA�����A�傫��������.
                float waveFactor = (IN.positionHCS.y + _Time.y * _WaveSpeed) * _WaveAmount;
                float waveScale = _CameraSortingLayerTexture_TexelSize.x * _WaveScale;

                // _CameraSortingLayerTexture��uv���W�����߂�.
                float2 uv = IN.positionHCS.xy / _ScaledScreenParams.xy;
                // �c�����ɔg�ł悤��u�l��ϊ�.
                uv.x += cos(waveFactor) * waveScale;
                //���ʂ���̐F�����˂����悤��v�l��ϊ�.
                uv.y += (1 - IN.uv.y) * _Scale.y * 2;

                // ���ʂ̐F�����肷��.
                half4 mirrorColor = SAMPLE_TEXTURE2D(_CameraSortingLayerTexture, sampler_CameraSortingLayerTexture, uv);
                half4 baseColor = mirrorColor * IN.color;

                // �R�[�X�e�B�N�X�̋��������߂�.
                // �F���������邽�߁Ar�l��g�l��uv�����炵�ĐF���ƂɌv�Z.
                float r = caustics(IN.uv + _MainTex_TexelSize.xy * _Aberration);
                float g = caustics(IN.uv);
                float b = caustics(IN.uv - _MainTex_TexelSize.xy * _Aberration);

                // ���ʂ̐F�ƃR�[�X�e�B�N�X�̐F����`�⊮���ďo��.
                return lerp(baseColor, _CausticsColor, half4(r, g, b, IN.color.a));
            }

            ENDHLSL
        }
    }
}
