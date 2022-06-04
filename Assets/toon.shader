Shader "Custom/toon"
{
    Properties
    {
        _MainTex ("Albedo (RGB)", 2D) = "white" {}
        _LineCol ("Line Color", Color) = (0, 0, 0, 1) // 1st Pass 의 색깔을 인터페이스로 조절하기 위해 만든 프로퍼티
        _LineWidth ("Line Width", Range(0, 0.0001)) = 0.00003 // 1st Pass 의 두께를 인터페이스로 조절하기 위해 만든 프로퍼티
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }

        // 유니티 셰이더는 렌더링 속도를 높이기 위해 뒷면을 그리지 않는 백페이스 컬링이 자동설정 되어있음. 
        // -> 즉, 아래와 같이 CGPROGRAM ~ ENDCG 바깥쪽에 cull back 키워드가 생략되어 있다는 것이지!
        // cull back

        // 이제 면을 뒤집어주기 위해 앞면을 추려내고, 뒷면만 그려주는 cull front (프론트 페이스 컬링)을 적용함. 
        // 앞면을 제거하는 이유는 뒷면만 보이게 해서 두번째 패스로 그린 오브젝트가 사이즈가 더 작아도 투과되서 보이게 끔 하려는 것. p.382 참고
        // 참고로 cull 은 '추려내다, 따다' 의 의미를 지님.
         cull front

        // 1st Pass
        /*
            첫 번째 패스는 세 가지 조건을 충족해야 함.

            1. 노말 방향으로 버텍스 위치데이터를 확장시키고,
            2. 프론트페이스 컬링(cull front) 로 앞면을 제거하고 뒷면만 렌더링해서 면을 뒤집어주고,
            3. 모든 픽셀을 검정색으로 출력해버려야 함.
        */
        CGPROGRAM

        // 버텍스 셰이더 함수는 'vert' 라는 이름으로 사용한다는 것을 #pragma 에게 알려줌.
        // 버텍스를 노말방향으로 확장하면, 그림자가 여전히 작은 상태의 모델링을 따라 연산되서 이상하게 나옴. -> noshadow 를 추가해 아예 그림자를 꺼버림.
        // 뒤집어진 첫번째 패스를 검게 만들기 위해 커스텀라이팅인 Nolight를 적용하고, (그냥 검게 칠하는게 전부인데 lambert 라이팅을 쓰기에는 오히려 과함.) 
        // 환경광을 꺼주기 위해 noambient 를 적용함.
        #pragma surface surf Nolight vertex:vert noshadow noambient

        float4 _LineCol;
        float _LineWidth;

        // 위에서 명시한 이름대로 버텍스 셰이더 함수를 만듦.
        // 이때, appdata_full 이라는 구조체를 인자로 받는데, 
        // 여기에는 버텍스에 저장된 위치, 탄젠트, 노말, uv, 색상 등의 데이터가 포함되어 있음. 
        // 여기서 버텍스 데이터들을 가져와서 사용하면 됨. (구조체에 대한 자세한 설명은 p.393 ~ 394 참고)
        void vert(inout appdata_full v) {
            /*
                기본적으로 버텍스 셰이더는 리턴타입이 void 라서 비워놓아도 아무런 문제가 안됨.

                원래 버텍스 셰이더의 기본 기능은 WebGL, GLSL 공부하면서도 봤었지만,
                '변환행렬을 곱해서 좌표를 변환해주는 것' 이 가장 기본적인 기능임.

                오브젝트 좌표 -> 월드 좌표 -> 눈 좌표(카메라 좌표) -> 프로젝션 좌표
                요 순서로 좌표계를 계속 변환하기 위해 모델행렬, 뷰행렬, 투영행렬 등을 사용했었지.

                근데 유니티의 버텍스 셰이더는 이런 좌표변환 과정을 알아서 변환해 줌.
                그래서 appdata 구조체로부터 필요한 버텍스 데이터만 받아와서
                필요한 것들만 가져다 쓰면 되기 때문에 일반적인 버텍스 셰이더보다는 사용이 편리함.
            */
            // 테스트삼아 버텍스의 y좌표값에 0.001 만큼을 더해서 y축 방향으로 버텍스들만 살짝 올려봄. (실제 오브젝트의 위치가 바뀐건 아님. 유니티 Inspector를 보면, Transform -> Position 의 Y는 계속 0으로 고정되어 있음.)
            // 버텍스의 y좌표값에 1을 더해주고 있는데, 내가 사용한 모델은 원본 스케일이 너무 작아서 버텍스를 1만큼 더해주면 너무 위로 올라가버려서 화면에서 찾기 힘들어짐... -> 책에서 사용하는 예제보다 단위를 훨씬 줄여서 계산해줘야 함...
            // v.vertex.y += 0.001;
            
            // 이제 원래 의도대로, 버텍스들을 노말방향으로 확장시킬것임.
            // 또, 모든 노말벡터는 길이가 1로 정규화되어 있다보니, 위에서 y좌표값 더해준 것처럼 1을 바로 더해주면 너무 사이즈가 커져서 공처럼 됨.
            // 그래서 노말벡터의 좌표값들도 0.00003 같은 적당한 값으로 스칼라곱을 해서 단위를 줄여줘야 책의 예제랑 비슷하게 나옴...
            // v.vertex.xyz += v.normal.xyz * 0.00003;
            // v.vertex.xyz += v.normal.xyz * _LineWidth; // 인터페이스로 받아온 값만큼을 스칼라곱해서 노멀방향으로 확장하는 길이를 조절함.
            v.vertex.xyz += v.normal.xyz * _LineWidth * sin(_Time.y); // 이런 식으로 _Time 내장변수를 이용해서 외곽선의 색깔이나 두께를 조절할 수 있도록 함.
        }

        struct Input
        {
            // 텍스쳐를 받아서 사용하지 않을거기 때문에 uv 버텍스 데이터는 필요가 없음.
            // 근데 Input 구조체에 아무것도 안넣으면 에러가 나다보니 아무 쓸모없는 버텍스 컬러를 그냥 넣어둔거임.
            float4 color:COLOR; 
        };

        void surf (Input IN, inout SurfaceOutput o)
        {
            // 1st 패스는 아예 검게 만드는 거라서 o.Albedo 나 o.Alpha 같은 걸 지정할 필요도 없음.
            // 커스텀 라이팅 함수에서 float4(0, 0, 0, 1) 즉, 검정색만 리턴해주는 게 가장 가벼운 라이팅 구조를 만드는 방법임.
        }

        float4 LightingNolight (SurfaceOutput s, float3 lightDir, float atten) {
            // return float4(0, 0, 0, 1); // 아무런 계산도 하지 말고, 모든 픽셀에 대해 검정색을 리턴해 줌.
            // return _LineCol; // 인터페이스로 받아온 색상값을 출력함.
            float4 final = _LineCol;
            final.r += sin(_Time.y);
            return final; // 이런 식으로 _Time 내장변수를 이용해서 외곽선의 색깔이나 두께를 조절할 수 있도록 함.
        }
        ENDCG

        // 첫 번째 패스에서 선언해줬던 cull front 때문에 
        // 두 번째 패스에도 영향을 줘서 두 번째 패스도 면이 뒤집혀져서 렌더링됨.
        // 따라서, 이럴 경우 두 번째 패스를 시작하기 전 (즉, 두 번째 패스의 CGPROGRAM 키워드 앞에서) cull back 을 다시 선언함으로써,
        // 프론트페이스 컬링 설정을 다시 백페이스 컬링으로 되돌려놓은 것. -> 이러면 두번째 패스는 정상적으로 앞면만 렌더링될거임.
        cull back

        // 2nd Pass (한 셰이더에서 한 오브젝트를 2번 그리는 방법은 간단함. CGPROGRAM ~ ENDCG 까지의 코드를 복붙하면 됨.)
        CGPROGRAM
        #pragma surface surf Lambert

        sampler2D _MainTex;

        struct Input
        {
            float2 uv_MainTex;
        };

        void surf (Input IN, inout SurfaceOutput o)
        {
            fixed4 c = tex2D (_MainTex, IN.uv_MainTex);
            o.Albedo = c.rgb;
            o.Alpha = c.a;
        }
        ENDCG
    }
    FallBack "Diffuse"
}

/*
    유니티 셰이더의 버텍스 셰이더

    유니티 쉐이더에서는 기본적으로
    버텍스 셰이더가 보이지 않는 곳에서
    알아서 돌아가고 있으며,

    지금까지 우리가 작성해 온 셰이더는
    프래그먼트 셰이더만 작성해온 것임.

    따라서, 숨어있던 버텍스 셰이더를 꺼내서 
    가동시킴으로써, 오브젝트의 버텍스들을
    변형하고 확장할 수 있음.
*/