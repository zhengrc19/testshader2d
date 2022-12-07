# Unity Shader学习笔记

Ray Zheng  2022.12.05



# Shader是什么

Shader原意负责3D渲染过程中确定具体的光照、阴影和颜色；现代不仅是负责“shadow”，也作为一种渲染过程中的特效和后处理工具来使用；下图[1]为Unity大致的渲染过程。

![shader theory](https://www.alanzucconi.com/wp-content/uploads/2015/06/shader-theory.png)



3D模型由多节点Vertices连接组成的三角面片构成。同时还附加额外信息，包括颜色color、法线normal、以及在纹理当中的坐标UV data。同时3D模型必须有一个材料Material，Material则包含着一个Shader，这个Shader在3D模型的渲染过程当中可以对节点的位置和颜色都产生最后一步的确定和影响。

一个Shader又包含一些属性，这些属性的值由Material改变和确定，也可以在Unity界面当中快速改变。不同的Material完全可以使用同一个Shader但是对其属性赋不同的值。



# Shader管道

如下图[2]，3D物体在shader中，先经过vertex函数，对节点的位置进行处理，然后输出的节点位置信息再输入到fragment函数中，确定像素具体的颜色信息。其中，函数执行过成中受到property属性值的影响。

![pipeline](https://raw.githubusercontent.com/zhengrc19/testshader2d/master/Unity%20Shader%E5%AD%A6%E4%B9%A0%E7%AC%94%E8%AE%B0.assets/%E6%88%AA%E5%B1%8F2022-12-07%2001.25.56.png)





# Shader实践

遵循[Unity Shader: 一个简单的(规则化)序列帧动画(基础显示)](https://www.jianshu.com/p/6946971c22f8)教程，将以下代码存储为shader文件。

```csharp
// 规则化序列帧播放,每帧大小应该一致
// @author Danny_Yan
Shader "Test/SimpleMovieClip"
{
    Properties
    {
        _MainTex ("Image Sequence", 2D) = "white" { }// 序列帧图片
        _RowCount ("行", Float) = 1 // 行数
        _ColumnCount ("列", Float) = 1 // 列数
        _FrameRate ("帧率", Range(1, 100)) = 30 
    }
    SubShader
    {
        //一般序列帧动画的纹理会带有Alpha通道，因此要按透明效果渲染，需要设置标签，关闭深度写入，使用并设置混合
        Tags { "RenderType"="Transparent" "Queue"="Transparent" "IgnoreProjector"="True"}

        Pass
        {
            Tags { "LightMode"="ForwardBase" }
            ZWrite off
            Blend SrcAlpha OneMinusSrcAlpha

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // make fog work
            #pragma multi_compile_fog

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                UNITY_FOG_COORDS(1)
                float4 vertex : SV_POSITION;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;

            sampler2D _InfoTex;
            float4 _InfoTex_ST;

            fixed4 _Color;
            float _RowCount;
            float _ColumnCount;
            float _FrameRate;

            float _Total;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                // 是用原始uv,不进行平铺和偏移
                // o.uv = v.uv.xy;// * _MainTex_ST.xy + _MainTex_ST.zw;

                UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                // 将时间取整(变成以秒为单位)相当于1秒1帧,放大到_FrameRate后,相当于得到帧index,通过index去计算行列索引.
                // 必须将纹理的wrap mode设置为Repeat(或类似的设定),因为当time>_ColumnCount*2时,row会大于_RowCount
                // uvoff中计算的y值会大于1,需要通过纹理的Repeat机制来重复显示.
                // 或者在外部维护一个index变量,并传进来,这样可以在外层将这个index进行重置为0
                float index = floor(_Time.y * _FrameRate); 
                // 取整得到行索引(播放顺序设计为从左到右,先行后列)
                float rowIndex = floor(index / _ColumnCount);
                // 余数为列索引 
                float columnIndex = fmod(index, _ColumnCount); // index - rowIndex * _ColumnCount;
                
                half2 iuv = i.uv.xy; // /_MainTex_ST.xy;
                // 使用中的行列值作为分割计算的元值(总比值). 相当于一个窗口,通过该窗口的上下左右定位得到每帧图片的uv
                half2 rawSplit = half2(_ColumnCount, _RowCount);
                // 当前uv通过rawSplit分割后,得到当前uv在总uv中的占比. 相当于(窗口的)固定大小
                iuv /= rawSplit;
                // 通过当前计算出的行列值与总比值的比例,得到uv的起始偏移量. 相当于(窗口的)起始位置, row是从上到下,取反后转换为uv的从下到上
                half2 uvoff = half2(columnIndex, -rowIndex)/rawSplit;
                iuv += uvoff;
                
                // iuv*=-1;
                fixed4 col = tex2D(_MainTex, iuv);
                
                // apply fog
                UNITY_APPLY_FOG(i.fogCoord, col);
                return col;
            }
            ENDCG
        }
    }

    FallBack "Transparent/VertexLit"
}
```

运行上述代码后，得到序列动画“5 6 7 8 9 0 1 2 3 4”，成功创建序列帧播放器。

然而，为了得到“0 1 2 3 4 5 6 7 8 9”的正常效果，尝试对代码进行修改。阅读代码后，发现第77行

```csharp
float rowIndex = floor(index / _ColumnCount);
```

该行为决定播放哪一行的代码，将其修改为

```csharp
float rowIndex = _RowCount - 1 - floor(index / _ColumnCount);
```

即可播放“0 1 2 3 4 5 6 7 8 9”。



# 实践过程遇到的问题

- 电脑跑不动unity

  解决：借了一台同学的电脑来跑

- 不知如何创建shader。网上教程无论文字还是视频都假设已经创建成功，重点在shader代码讲解

  解决：找到了Unity官方的视频教程[2]，里面演示如何创建shader

* 创建shader后，不知如何作用在物体上。首先创建了UI Image，并创建模板shader文件代替为上述代码，但是没有效果。同时，在image属性当中尝试找到指定shader但是像下图一样，文字为灰，

  ![cannot change shader](https://raw.githubusercontent.com/zhengrc19/testshader2d/master/Unity%20Shader%E5%AD%A6%E4%B9%A0%E7%AC%94%E8%AE%B0.assets/image-20221207144611885.png)

  固定了material和shader，不让修改。

  解决：需要先建立一个material，material使用shader，然后将image的material设为新建material。



# 参考资料

[1] Alan Zucconi. *A gentle introduction to shaders in Unity3D.* https://www.alanzucconi.com/2015/06/10/a-gentle-introduction-to-shaders-in-unity3d/

[2] Unity. *Writing Your First Shader in Unity.* https://www.youtube.com/watch?v=Tr9PLpj7Kzc&list=PLX2vGYjWbI0RS_lkb68ApE2YPcZMC4Ohz

[3] Danny_Yan. *Unity Shader: 一个简单的(规则化)序列帧动画(基础显示)*. https://www.jianshu.com/p/6946971c22f8
