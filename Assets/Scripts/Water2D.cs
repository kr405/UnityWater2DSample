using UnityEngine;

namespace Shader2DSample
{
    public class Water2D : MonoBehaviour
    {
        [SerializeField] Camera _camera;
        [SerializeField, Range(0.0f, 1.0f)] float _waveAmount;
        [SerializeField, Range(0.0f, 10.0f)] float _waveScale;
        [SerializeField, Range(0.0f, 30.0f)] float _waveSpeed;
        [SerializeField] Color _causticsColor;
        [SerializeField, Range(0.0f, 10.0f)] float _causticsScale;
        [SerializeField, Range(0.0f, 10.0f)] float _causticsIntensity;
        [SerializeField, Range(-10.0f, 10.0f)] float _aberration;
        [SerializeField, Range(1.0f, 100.0f)] int _smoothness;
        [SerializeField, Range(0.0f, 100.0f)] float _rippleAmount;
        [SerializeField, Range(0.0f, 100.0f)] float _rippleHeight;

        readonly string _shaderName = "Custom/Water2D";
        readonly int _scaleId = Shader.PropertyToID("_Scale");
        readonly int _waveAmountId = Shader.PropertyToID("_WaveAmount");
        readonly int _waveScaleId = Shader.PropertyToID("_WaveScale");
        readonly int _waveSpeedId = Shader.PropertyToID("_WaveSpeed");
        readonly int _causticsColorId = Shader.PropertyToID("_CausticsColor");
        readonly int _causticsScaleId = Shader.PropertyToID("_CausticsScale");
        readonly int _causticsIntensityId = Shader.PropertyToID("_CausticsIntensity");
        readonly int _aberrationId = Shader.PropertyToID("_Aberration");
        readonly int _smoothnessId = Shader.PropertyToID("_Smoothness");
        readonly int _rippleAmountId = Shader.PropertyToID("_RippleAmount");
        readonly int _rippleHeightId = Shader.PropertyToID("_RippleHeight");

        Shader _shader;
        Material _material;
        float _units;

        void Awake()
        {
            _shader = Shader.Find(_shaderName);
            _material = new Material(_shader);

            var spriteRenderer = GetComponent<SpriteRenderer>();
            var sprite = spriteRenderer.sprite;
            spriteRenderer.material = _material;
            _units = sprite.textureRect.height / sprite.pixelsPerUnit;
        }

        void Update()
        {
            _material.SetVector(_scaleId, Scale());
            _material.SetFloat(_waveAmountId, _waveAmount);
            _material.SetFloat(_waveScaleId, _waveScale);
            _material.SetFloat(_waveSpeedId, _waveSpeed);
            _material.SetColor(_causticsColorId, _causticsColor);
            _material.SetFloat(_causticsScaleId, _causticsScale);
            _material.SetFloat(_causticsIntensityId, _causticsIntensity);
            _material.SetFloat(_aberrationId, _aberration);
            _material.SetInt(_smoothnessId, _smoothness);
            _material.SetFloat(_rippleAmountId, _rippleAmount);
            _material.SetFloat(_rippleHeightId, _rippleHeight);
        }

        Vector3 Scale()
        {
            float ratio = _units / (_camera.orthographicSize * 2.0f);
            return transform.localScale * ratio;
        }
    }
}    