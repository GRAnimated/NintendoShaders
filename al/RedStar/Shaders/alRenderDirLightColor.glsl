/**
 * @file	alRenderDirLightColor.glsl
 * @author	Matsuda Hirokazu  (C)Nintendo
 *
 * @brief	ディレクショナルライトの色をテクスチャにレンダリング
 */

#if defined( AGL_TARGET_GX2 )
#extension GL_EXT_Cafe : enable // 明示的な場所指定には必要。無いと GPU ハング。
#endif

#include "alMathUtil.glsl"
#include "alDefineVarying.glsl"

uniform vec4	uLightColor;

DECLARE_VARYING(float,	vMixRate);

//------------------------------------------------------------------------------
// 頂点シェーダ
//------------------------------------------------------------------------------
#if defined(AGL_VERTEX_SHADER)

layout (location=0) in vec3 aPosition;	// @@ id="_p0" hint="position0"

void main()
{
	vec2 sign_pos = sign(aPosition.xy); // 画面を覆う -1 〜 1 の範囲のスクリーン座標になる
	gl_Position.xy = sign_pos;
	gl_Position.z = 0.0;
	gl_Position.w = 1.0;

	// 2 ピクセルへのレンダリングで vMixRate は 0 と 1 になって欲しい
	// フラグメントシェーダで 0 〜 1 になるために2を掛ける
	getVarying(vMixRate) = gl_Position.x * 2.0;
}

//------------------------------------------------------------------------------
// フラグメントシェーダ
//------------------------------------------------------------------------------
#elif defined(AGL_FRAGMENT_SHADER)

// 出力変数
layout(location = 0)	out vec4 oColor;


void main()
{
	float rate = clamp01(getVarying(vMixRate));
	const vec3 lit_inscatter = vec3(0.0);

	// 0.5 よりも rate が小さければ太陽の光を除いた空の色だけにする
	vec3 lit_color = lit_inscatter + uLightColor.rgb * step(0.5, rate);
	oColor = vec4(lit_color, 1.0);
}

#endif // AGL_FRAGMENT_SHADER

