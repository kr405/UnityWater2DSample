using UnityEngine;

namespace Shader2DSample
{
    public class PlayerController : MonoBehaviour
    {
        [SerializeField] float _speed;

        Animator _animator;

        void Awake()
        {
            _animator = GetComponent<Animator>();
        }

        void Update()
        {
            var input = Input.GetAxis("Horizontal");

            if (input != 0)
            {
                if (Input.GetKey(KeyCode.LeftShift))
                {
                    input *= 2;
                }

                var move = input * _speed * Vector3.right;
                Turn(move);
                Move(move);
            }

            _animator.SetFloat("HorizontalSpeed", Mathf.Abs(input));
        }

        /// <summary>
        /// �����]������.
        /// </summary>
        /// <param name="move">�ړ��������.</param>
        void Turn(Vector3 move)
        {
            var scale = transform.localScale;
            scale.x = Mathf.Sign(move.x) * Mathf.Abs(scale.x);
            transform.localScale = scale;
        }

        /// <summary>
        /// �ړ�����.
        /// </summary>
        /// <param name="move">�ړ��������.</param>
        void Move(Vector3 move)
        {
            transform.Translate(move * Time.deltaTime);
        }
    }
}