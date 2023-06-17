/**
 * @file	alFluidSimulateWave.glsl
 * @author	Tatsuya Kurihara  (C)Nintendo
 *
 * @brief	流体シミュレート波を描く(波動方程式の近似)
 */
#if defined( AGL_TARGET_GX2 )
#extension GL_EXT_Cafe : enable // 明示的な場所指定には必要。無いと GPU ハング。
#endif
precision highp float;

#include "alMathUtil.glsl"
#include "alDeclareUniformBlockBinding.glsl"

uniform sampler2D uPrevTex;

#define REPEAT_TYPE			(0) // @@ id="cRepeatType" choice="0,1" default="0"
#define REPEAT_TYPE_DISABLE	(0)
#define REPEAT_TYPE_ENABLE	(1)

//------------------------------------------------------------------------------
// 頂点シェーダ
//------------------------------------------------------------------------------
#if defined(AGL_VERTEX_SHADER)

layout (location = 0) in vec3 aPosition;	// @@ id="_p0" hint="position0"
layout (location = 1) in vec2 aTexCoord;
out vec2 vTexCrd;

void main()
{
	gl_Position.xy = 2.0 * aPosition.xy;
	gl_Position.z  = 0.0;
	gl_Position.w  = 1.0;

	vTexCrd = aTexCoord;
#if defined( AGL_TARGET_GL )
	vTexCrd.y = 1.0 - vTexCrd.y;
#endif
}

//------------------------------------------------------------------------------
// フラグメントシェーダ
//------------------------------------------------------------------------------
#elif defined(AGL_FRAGMENT_SHADER)

BINDING_UBO_OTHER_FIRST uniform FluidSimulateWave
{
	vec4 uData;
	vec4 uData2;
};

#define TEXEL_SIZE_X	uData.x
#define TEXEL_SIZE_Y	uData.y
#define TEXEL_SLIDE		uData.zw
#define COEF1			uData2.x
#define COEF2			uData2.y
#define COEF3			uData2.z
#define DAMP			uData2.w

in  vec2	vTexCrd;
out	vec4	oColor;

#define FadeThreshold 0.1

void main()
{
	vec2 tex_crd = vTexCrd + TEXEL_SLIDE;
	// 上下左右の前回値を取る
	vec2  tex0 = texture(uPrevTex, tex_crd).rg;
	float tex1 = texture(uPrevTex, tex_crd + vec2(+TEXEL_SIZE_X, 0.0)).r;
	float tex2 = texture(uPrevTex, tex_crd + vec2(-TEXEL_SIZE_X, 0.0)).r;
	float tex3 = texture(uPrevTex, tex_crd + vec2(0.0, +TEXEL_SIZE_Y)).r;
	float tex4 = texture(uPrevTex, tex_crd + vec2(0.0, -TEXEL_SIZE_Y)).r;
	float current_height = tex0.r;
	float prev_height    = tex0.g;

	// 次の高さを求める。3Dグラフィックス数学12.25式
	float height = COEF1 * current_height + COEF2 * prev_height + COEF3 * (tex1 + tex2 + tex3 + tex4);

	// 0へと減衰させる（dampが1以外の場合エネルギー保存はされない）
	height = height * DAMP;

// 端付近でフェードアウトさせる
#if REPEAT_TYPE == REPEAT_TYPE_ENABLE
	float rate = (FadeThreshold - clamp01(max(abs(tex_crd.x - 0.5), abs(tex_crd.y - 0.5)) - (0.5 - FadeThreshold))) * (1.0/FadeThreshold);
	height *= rate;
	current_height *= rate;
#endif

	// 次のをrに、現在のをgにいれる。
	oColor = vec4(height, current_height, vTexCrd.x, 1.0);
}
#endif // defined(AGL_FRAGMENT_SHADER)
