Shader "Test/GradientShader" {
    Properties {
        _MainTex ("Sprite Texture", 2D) = "white" {}
        _Color ("Lower Color", Color) = (1,1,1,1)
        _Color2 ("Upper Color", Color) = (1,1,1,1)
    }

    SubShader {
    
        Pass {
            CGPROGRAM
            #pragma vertex vert  
            #pragma fragment frag
            #include "UnityCG.cginc"
    
            fixed4 _Color;
            fixed4 _Color2;
    
            struct v2f {
                float4 pos : SV_POSITION;
                fixed4 col : COLOR;
            };
    
            v2f vert (
                float4 vertex : POSITION, // vertex position input
                float2 uv : TEXCOORD0 // first texture coordinate input
            ) {
                v2f o;
                o.pos = UnityObjectToClipPos(vertex);
                o.col = lerp(_Color, _Color2, uv.y);
                return o;
            }
    
            float4 frag (v2f i) : COLOR {
                return i.col;
            }
            ENDCG
        }
    }
}