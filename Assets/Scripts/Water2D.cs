using System.Collections.Generic;
using Unity.VisualScripting;
using UnityEngine;

namespace Shader2DSample
{
    public class Water2D : MonoBehaviour
    {
        [SerializeField] Camera _camera;
        
        [SerializeField, Range(0.0f, 1.0f)] float _waveAmount;
        [SerializeField, Range(0.0f, 1.0f)] float _waveScale;
        [SerializeField, Range(0.0f, 10.0f)] float _waveSpeed;

        [SerializeField] Color _causticsColor;
        [SerializeField, Range(0, 10)] int _causticsScale;
        [SerializeField, Range(0.0f, 1.0f)] float _causticsIntensity;
        [SerializeField, Range(-10.0f, 10.0f)] float _aberration;
        
        [SerializeField, Range(0.0f, 100.0f)] float _rippleAmount;
        [SerializeField, Range(0.0f, 10.0f)] float _rippleScale;
        [SerializeField, Range(0.0f, 10.0f)] float _rippleSpeed;
                
        readonly string _shaderName = "Custom/Water2D";
        readonly int _textureScaleId = Shader.PropertyToID("_TextureScale");
        readonly int _waveAmountId = Shader.PropertyToID("_WaveAmount");
        readonly int _waveScaleId = Shader.PropertyToID("_WaveScale");
        readonly int _waveSpeedId = Shader.PropertyToID("_WaveSpeed");
        readonly int _causticsColorId = Shader.PropertyToID("_CausticsColor");
        readonly int _causticsScaleId = Shader.PropertyToID("_CausticsScale");
        readonly int _causticsIntensityId = Shader.PropertyToID("_CausticsIntensity");
        readonly int _aberrationId = Shader.PropertyToID("_Aberration");
        readonly int _rippleAmountId = Shader.PropertyToID("_RippleAmount");
        readonly int _rippleScaleId = Shader.PropertyToID("_RippleScale");
        readonly int _rippleSpeedId = Shader.PropertyToID("_RippleSpeed");
        readonly int _contactPointsId = Shader.PropertyToID("_ContactPoints");
        readonly int _numContactPoints = Shader.PropertyToID("_NumPoints");
        readonly int _maxPointCount = 20;

        Material _material;
        float _units;
        List<int> _contactedObjects = new List<int>();
        List<Vector4> _contactPoints = new List<Vector4>();

        void Awake()
        {
            // 水面のマテリアルを作成
            var shader = Shader.Find(_shaderName);
            _material = new Material(shader);

            // 作成したマテリアルを適用
            var spriteRenderer = GetComponent<SpriteRenderer>();
            spriteRenderer.material = _material;

            // テクスチャの縦幅が占めるユニット数を計算
            var sprite = spriteRenderer.sprite;
            _units = sprite.textureRect.height / sprite.pixelsPerUnit;

            // シェーダー側の衝突位置の配列を初期化
            _material.SetVectorArray(_contactPointsId, new Vector4[_maxPointCount]);
        }

        void Update()
        {
            _material.SetFloat(_textureScaleId, TextureScale());
            _material.SetFloat(_waveAmountId, _waveAmount);
            _material.SetFloat(_waveScaleId, _waveScale);
            _material.SetFloat(_waveSpeedId, _waveSpeed);
            _material.SetColor(_causticsColorId, _causticsColor);
            _material.SetInt(_causticsScaleId, _causticsScale);
            _material.SetFloat(_causticsIntensityId, _causticsIntensity);
            _material.SetFloat(_aberrationId, _aberration);
            _material.SetFloat(_rippleAmountId, _rippleAmount);
            _material.SetFloat(_rippleScaleId, _rippleScale);
            _material.SetFloat(_rippleSpeedId, _rippleSpeed);
        }

        /// <summary>
        /// スクリーンの縦幅に対するテクスチャの縦幅の割合を取得する.
        /// </summary>
        /// <returns>テクスチャの縦幅のスケール.</returns>
        float TextureScale()
        {
            float ratio = _units / (_camera.orthographicSize * 2.0f);
            return transform.localScale.y * ratio;
        }

        /// <summary>
        /// オブジェクトの接触をシェーダーに反映する.
        /// </summary>
        /// <param name="collision">接触しているコライダー.</param>
        void AddContactPoint(Collider2D collision)
        {
            // 接触しているオブジェクトの座標をスクリーン座標に変換.
            var contactPoint = _camera.WorldToScreenPoint(collision.transform.position);

            int id = collision.GetInstanceID();
            int index = _contactedObjects.IndexOf(id);
            if (index >= 0)
            {
                // リストにidがあれば_contactPointsの中の対応する座標を更新.
                _contactPoints[index] = contactPoint;
            }
            else if (_contactPoints.Count < _maxPointCount)
            {
                // リストにidがなければ値を追加する.
                _contactedObjects.Add(id);
                _contactPoints.Add(contactPoint);
            }
            else
            {
                return;
            }
            UpdateContactPoints();
        }

        /// <summary>
        /// オブジェクトの離脱をシェーダーに反映する.
        /// </summary>
        /// <param name="collision"></param>
        void RemoveContactPoint(Collider2D collision)
        {
            int id = collision.GetInstanceID();
            int index = _contactedObjects.IndexOf(id);
            if (index >= 0)
            {
                // リストから除いてシェーダーの配列を更新する.
                _contactedObjects.RemoveAt(index);
                _contactPoints.RemoveAt(index);
                UpdateContactPoints();
            }
        }
        
        /// <summary>
        /// シェーダーの接触位置の配列を更新する.
        /// </summary>
        void UpdateContactPoints()
        {
            _material.SetVectorArray(_contactPointsId, _contactPoints);
            _material.SetInt(_numContactPoints, _contactPoints.Count);
        }

        void OnTriggerStay2D(Collider2D collision)
        {
            AddContactPoint(collision);
        }

        void OnTriggerExit2D(Collider2D collision)
        {
            RemoveContactPoint(collision);
        }        
    }
}    