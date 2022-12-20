# Unity Shader学习笔记：渐变调色

Ray Zheng  2022.12.20


# 渐变原理
![](https://raw.githubusercontent.com/zhengrc19/testshader2d/gradient/readme_imgs/gradient-example.png)

如图所示，渐变就是在两个颜色之间的平滑过渡。

一个简单的实现思路为，在两个颜色的RGB值之间进行线性插值，即可得到中间的渐变颜色曲线。

颜色间线性插值可以使用Shader自带的`lerp`函数。


# Shader实践

参考[Unity官方Shader文档](https://docs.unity3d.com/Manual/SL-ShadingLanguage.html)，以及[这个回答](https://answers.unity.com/questions/913898/horizontally-gradient-on-image-ui-element.html)，我写出以下代码：

```csharp
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
```

得到效果如图，并且可以使用色盘调整上下两端的颜色。

![](https://raw.githubusercontent.com/zhengrc19/testshader2d/gradient/readme_imgs/gradient-finished.png)