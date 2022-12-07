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
            // #pragma multi_compile_fog

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                // UNITY_FOG_COORDS(1)
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

                // UNITY_TRANSFER_FOG(o,o.vertex);
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
                float rowIndex = _RowCount - 1 - floor(index / _ColumnCount);
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
                // UNITY_APPLY_FOG(i.fogCoord, col);
                return col;
            }
            ENDCG
        }
    }

    FallBack "Transparent/VertexLit"
}

